package gltf

import "core:encoding/json"
import "core:fmt"
import "core:log"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"
import stbi "vendor:stb/image"

VALID_MAGIC :: 0x46546C67

CHUNK_JSON :: 0x4E4F534A
CHUNK_BIN :: 0x004E4942

glTF_Error :: enum {
	None,
	Invalid_Magic,
	Unknown_First_Chunk,
	Access_Error,
	Out_of_Bounds,
	File_Not_Found,
}

Error :: union #shared_nil {
	os.Error,
	json.Unmarshal_Error,
	glTF_Error,
}

Header :: struct {
	magic:   u32,
	version: u32,
	length:  u32,
}

ChunkHeader :: struct {
	chunkLength: u32,
	chunkType:   u32,
}

Glb_Container :: struct {
	file:             os.Handle,
	asset_path:       string,
	bin_chunk_offset: i64,
	gltf:             ^glTF_Document,
	gltf_arena:       vmem.Arena,
}

glb_load :: proc(path: string, allocator := context.allocator) -> (container: ^Glb_Container, err: Error) {
	asset_path, ok := filepath.abs(path, allocator) // TODO: handle the allocation
	if !ok {
		err = .File_Not_Found
		return
	}

	container = new(Glb_Container, allocator)
	container.asset_path = asset_path
	file := os.open(asset_path) or_return
	container.file = file

	read_counter: u32
	header := Header{}
	{
		read := os.read_ptr(file, &header, size_of(Header)) or_return
		read_counter += u32(read)

		if header.magic != VALID_MAGIC {
			log.debug("invalid magic")
			return container, .Invalid_Magic
		}

		log.debug("glTF magic valid")
		log.debugf("container format version: %d", header.version)
		log.debugf("total length: %d bytes", header.length)
	}

	log.debug("reading chunk")

	{
		os.seek(file, i64(read_counter), os.SEEK_SET)

		chunkHeader := ChunkHeader{}
		read := os.read_ptr(file, &chunkHeader, size_of(ChunkHeader)) or_return
		read_counter += u32(read)

		log.debugf("chunk data length: %d bytes", chunkHeader.chunkLength)
		log.debugf("chunk type: %X", chunkHeader.chunkType)

		os.seek(file, i64(read_counter), os.SEEK_SET)

		switch chunkHeader.chunkType {
		case CHUNK_JSON:
			log.debug("this is a JSON chunk, trying to read")

			data := make([]byte, chunkHeader.chunkLength)
			defer delete(data)
			read, err := os.read_at_least(file, data, int(chunkHeader.chunkLength))
			if err != nil {
				log.debug("fail", err)
			}
			read_counter += u32(read)
			data = data[:read]

			log.debug("JSON chunk read")
			log.debug("parsing JSON chunk")

			gltf_arena: vmem.Arena
			arena_allocator := vmem.arena_allocator(&gltf_arena)
			container.gltf = new(glTF_Document, allocator)
			json.unmarshal(data, container.gltf, allocator = arena_allocator) or_return
			container.gltf_arena = gltf_arena
		case:
			log.debug("this is an unknown chunk")
			return container, .Unknown_First_Chunk
		}
	}

	log.debug("reading binary chunk")

	{
		os.seek(file, i64(read_counter), os.SEEK_SET)

		chunkHeader := ChunkHeader{}
		read := os.read_ptr(file, &chunkHeader, size_of(ChunkHeader)) or_return
		read_counter += u32(read)

		log.debugf("chunk data length: %d bytes", chunkHeader.chunkLength)
		log.debugf("chunk type: %X", chunkHeader.chunkType)

		os.seek(file, i64(read_counter), os.SEEK_SET)

		switch chunkHeader.chunkType {
		case CHUNK_BIN:
			log.debug("this is a BIN chunk")

			container.bin_chunk_offset = i64(read_counter)

			return container, nil
		case:
			log.debug("this is an unknown chunk")
			return container, .Unknown_First_Chunk
		}
	}
}

glb_destroy :: proc(container: ^Glb_Container, allocator := context.allocator) {
	vmem.arena_destroy(&container.gltf_arena)
	os.close(container.file)
	free(container.gltf, allocator)
	free(container, allocator)
}

get_nodes :: proc(container: ^Glb_Container) -> (nodes: []glTF_Node) {
	switch ns in container.gltf.nodes {
	case []glTF_Node:
		#assert(type_of(ns) == []glTF_Node)
		nodes = ns
	}

	return
}

get_mesh :: proc(container: ^Glb_Container, id: glTF_Id) -> (mesh: glTF_Mesh, err: Error) {
	switch meshes in container.gltf.meshes {
	case []glTF_Mesh:
		#assert(type_of(meshes) == []glTF_Mesh)

		if len(meshes) < id {
			err = .Out_of_Bounds
			return
		}

		mesh = meshes[id]
		return
	}

	err = .Access_Error

	return
}

Binary_Buffer :: struct {
	handle:      os.Handle,
	byte_offset: i64,
}

get_buffer :: proc(container: ^Glb_Container, buf_id: glTF_Id) -> (buff: Binary_Buffer, err: Error) {
	switch buffers in container.gltf.buffers {
	case []glTF_Buffer:
		#assert(type_of(buffers) == []glTF_Buffer)
		buffer := buffers[buf_id]

		assert(buffer.uri == nil, "external binaries not implemented")
		buff.handle = container.file
		buff.byte_offset = container.bin_chunk_offset
		return
	}

	return
}

Binary_Buffer_View :: struct {
	handle:      os.Handle,
	byte_offset: i64,
	byte_length: i64,
	byte_stride: union {
		int,
	},
}

get_buffer_view :: proc(container: ^Glb_Container, view_id: glTF_Id) -> (b_view: Binary_Buffer_View, err: Error) {
	switch buffer_views in container.gltf.bufferViews {
	case []glTF_Buffer_View:
		buffer_view := buffer_views[view_id]

		buff := get_buffer(container, buffer_view.buffer) or_return
		b_view.handle = buff.handle
		b_view.byte_offset = buff.byte_offset + (buffer_view.byteOffset != nil ? i64(buffer_view.byteOffset.(int)) : 0)
		b_view.byte_length = i64(buffer_view.byteLength)
		b_view.byte_stride = buffer_view.byteStride
	}

	return
}

get_accessor :: proc(container: ^Glb_Container, accessor_id: glTF_Id) -> (accessor: glTF_Accessor, err: Error) {
	switch accessors in container.gltf.accessors {
	case []glTF_Accessor:
		#assert(type_of(accessors) == []glTF_Accessor)

		if len(accessors) < accessor_id {
			err = .Out_of_Bounds
			return
		}

		accessor = accessors[accessor_id]
		return
	}

	err = .Access_Error

	return
}

read_buffer :: proc(buffer_view: Binary_Buffer_View, target: rawptr, length: int) -> (read: int, err: Error) {
	os.seek(buffer_view.handle, buffer_view.byte_offset, os.SEEK_SET) or_return
	return os.read_ptr(buffer_view.handle, target, length)
}

Image :: struct {
	data:     [^]byte,
	width:    i32,
	height:   i32,
	mipmaps:  i32,
	channels: i32,
}

get_texture_image :: proc(container: ^Glb_Container, id: glTF_Id) -> (img: Image, err: Error) {
	switch images in container.gltf.images {
	case []glTF_Image:
		#assert(type_of(images) == []glTF_Image)

		if len(images) < id {
			err = .Out_of_Bounds
			return
		}

		image := images[id]

		if image.bufferView != nil {
			log.debug("image has a bufferView")

			v := get_buffer_view(container, image.bufferView.(glTF_Id)) or_return
			tmp_buf := make([]u8, v.byte_length)
			read_buffer(v, raw_data(tmp_buf), int(v.byte_length)) or_return

			img.data = stbi.load_from_memory(
				raw_data(tmp_buf),
				i32(v.byte_length),
				&img.width,
				&img.height,
				&img.channels,
				0,
			)
			img.mipmaps = 1
			return
		}

		if image.uri != nil {
			log.debug("image has a uri")

			uri := image.uri.(string)

			if strings.starts_with(uri, "data:") {
				return
			}

			image_path: string

			if filepath.is_abs(uri) {
				image_path = uri
			} else {
				asset_dir := filepath.dir(container.asset_path, allocator = context.temp_allocator)
				image_path = filepath.join({asset_dir, uri}, allocator = context.temp_allocator)
			}

			img.data = stbi.load(
				strings.clone_to_cstring(image_path, allocator = context.temp_allocator),
				&img.width,
				&img.height,
				&img.channels,
				0,
			)
			img.mipmaps = 1
			return
		}
	}

	return
}
