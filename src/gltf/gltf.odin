package gltf

import "core:encoding/json"
import "core:fmt"
import "core:log"
import vmem "core:mem/virtual"
import "core:os"

VALID_MAGIC :: 0x46546C67

CHUNK_JSON :: 0x4E4F534A
CHUNK_BIN :: 0x004E4942

glTF_Error :: enum {
	None,
	Invalid_Magic,
	Unknown_First_Chunk,
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
	file:       os.Handle,
	gltf:       ^glTF_Document,
	gltf_arena: vmem.Arena,
}

glb_load :: proc(path: string) -> (container: ^Glb_Container, err: Error) {
	container = new(Glb_Container)
	file := os.open(path) or_return
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
			container.gltf = new(glTF_Document)
			json.unmarshal(data, container.gltf, allocator = arena_allocator) or_return
			container.gltf_arena = gltf_arena

			log.debug("all done")
			return container, nil
		case:
			log.debug("this is an unknown chunk")
			return container, .Unknown_First_Chunk
		}
	}
}

glb_destroy :: proc(container: ^Glb_Container) {
	vmem.arena_destroy(&container.gltf_arena)
	os.close(container.file)
	free(container.gltf)
	free(container)
}
