package glb_viewer

import "core:encoding/json"
import "core:fmt"
import "core:log"
import vmem "core:mem/virtual"
import "core:os"

VALID_MAGIC :: 0x46546C67

CHUNK_JSON :: 0x4E4F534A
CHUNK_BIN :: 0x004E4942

Header :: struct {
	magic:   u32,
	version: u32,
	length:  u32,
}

ChunkHeader :: struct {
	chunkLength: u32,
	chunkType:   u32,
}

main :: proc() {
	context.logger = log.create_console_logger(.Debug)

	path := "./train.glb"

	log.debugf("trying to open file: %s", path)
	file, err := os.open(path)
	if err != nil {
		log.fatalf("failed to open the file %v", err)
		return
	}

	defer os.close(file)
	log.debugf("file open")

	read_counter: u32
	header := Header{}
	{
		read, err := os.read_ptr(file, &header, size_of(Header))
		if err != nil {
			log.fatal("fail", err)
		}
		read_counter += u32(read)

		if header.magic != VALID_MAGIC {
			log.fatal("invalid magic")
		}

		log.debug("glTF magic valid")
		log.debugf("container format version: %d", header.version)
		log.debugf("total length: %d bytes", header.length)
	}

	for read_counter < header.length {
		log.debug("reading chunk")

		os.seek(file, i64(read_counter), os.SEEK_SET)

		chunkHeader := ChunkHeader{}
		read, err := os.read_ptr(file, &chunkHeader, size_of(ChunkHeader))
		if err != nil {
			log.fatal("fail", err)
		}
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
				log.fatal("fail", err)
			}
			read_counter += u32(read)
			data = data[:read]

			log.debug("JSON chunk read")
			log.debug("parsing JSON chunk")

			gltf := glTF{}

			uerr := json.unmarshal(data, &gltf)
			if uerr != nil {
				log.fatal("failed to unmarshall", uerr)
			}

			fmt.println(gltf)

		// json_data, json_err := json.parse(data)
		// if json_err != .None {
		// 	log.fatal("failed to parse JSON", json_err)
		// }
		// defer json.destroy_value(json_data)

		// root := json_data.(json.Object)
		// fmt.println(root)
		case CHUNK_BIN:
			log.debug("this is a binary chunk")
			read_counter += chunkHeader.chunkLength
		case:
			log.debug("this is an unknown chunk")
			read_counter += chunkHeader.chunkLength
		}
	}

	log.debug("all done")
}
