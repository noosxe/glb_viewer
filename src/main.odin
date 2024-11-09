package glb_viewer

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"

import gltf_rl "gltf/adapters/raylib"
import rl "vendor:raylib"

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


	loader_arena: vmem.Arena
	arena_allocator := vmem.arena_allocator(&loader_arena)

	rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "GLB Viewer")
	rl.SetTargetFPS(144)
	rl.SetMouseCursor(rl.MouseCursor.ARROW)

	camera := rl.Camera3D {
		position   = rl.Vector3{3, 3, 3},
		target     = rl.Vector3{0, 0, 0},
		up         = rl.Vector3{0, 1, 0},
		fovy       = 70,
		projection = .PERSPECTIVE,
	}

	model := gltf_rl.load_model(path, arena_allocator)

	for !rl.WindowShouldClose() {
		rl.UpdateCamera(&camera, rl.CameraMode.ORBITAL)

		rl.BeginDrawing()
		rl.BeginMode3D(camera)
		rl.ClearBackground(rl.BLUE)
		rl.DrawGrid(20, 1)

		rl.DrawModel(model, {0, 0, 0}, 1, rl.WHITE)

		rl.EndMode3D()
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()

	vmem.arena_destroy(&loader_arena)
}
