package glb_viewer

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"

import "gltf"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	logger := log.create_console_logger(.Debug)
	defer log.destroy_console_logger(logger)
	context.logger = logger

	if len(os.args) == 1 {
		fmt.println("no file specified")
		return
	}

	path := os.args[1]

	if !os.is_file_path(path) {
		fmt.eprintf("error: file not found: %s\n", path)
		return
	}

	container, err := gltf.glb_load(path)
	if err != nil {
		fmt.eprintf("error opening glb file: ", err)
		os.exit(1)
	}
	defer gltf.glb_destroy(container)

	fmt.println(container.gltf^)
}
