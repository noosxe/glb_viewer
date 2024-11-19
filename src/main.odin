package glb_viewer

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"

import gltf_rl "gltf/adapters/raylib"
import rl "vendor:raylib"

import "ext:back"

App_State :: struct {
	preview: Preview,
	gui:     Gui_State,
}

Gui_State :: struct {
	file_chooser: ^Gui_File_Chooser,
}

Preview :: struct {
	model: ^rl.Model,
}

main :: proc() {
	when ODIN_DEBUG {
		track: back.Tracking_Allocator
		back.tracking_allocator_init(&track, context.allocator)
		defer back.tracking_allocator_destroy(&track)

		context.allocator = back.tracking_allocator(&track)
		defer back.tracking_allocator_print_results(&track)

		context.assertion_failure_proc = back.assertion_failure_proc

		back.register_segfault_handler()
	}

	logger := log.create_console_logger(.Debug)
	defer log.destroy_console_logger(logger)
	context.logger = logger

	// if len(os.args) == 1 {
	// 	fmt.println("no file specified")
	// 	return
	// }

	// path := os.args[1]
	// if !os.is_file_path(path) {
	// 	fmt.eprintf("error: file not found: %s\n", path)
	// 	return
	// }

	app_state := App_State{}

	loader_arena: vmem.Arena
	arena_allocator := vmem.arena_allocator(&loader_arena)

	rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "GLB Viewer")
	defer rl.CloseWindow()
	rl.SetTargetFPS(144)
	rl.SetMouseCursor(rl.MouseCursor.ARROW)

	camera := rl.Camera3D {
		position   = rl.Vector3{3, 3, 3},
		target     = rl.Vector3{0, 0, 0},
		up         = rl.Vector3{0, 1, 0},
		fovy       = 70,
		projection = .PERSPECTIVE,
	}

	// model := gltf_rl.load_model(path, arena_allocator)

	for !rl.WindowShouldClose() {
		rl.UpdateCamera(&camera, rl.CameraMode.ORBITAL)

		rl.BeginDrawing()
		rl.BeginMode3D(camera)
		rl.ClearBackground(rl.BLUE)
		rl.DrawGrid(20, 1)

		if app_state.preview.model != nil {
			rl.DrawModel(app_state.preview.model^, {0, 0, 0}, 1, rl.WHITE)
		}

		rl.EndMode3D()

		draw_gui(&app_state, arena_allocator)

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	vmem.arena_destroy(&loader_arena)
}

draw_gui :: proc(state: ^App_State, allocator := context.allocator) {
	w := rl.GetRenderWidth()

	rl.GuiPanel(rl.Rectangle{0, 0, f32(w), 50}, nil)

	if rl.GuiButton(rl.Rectangle{10, 10, 30, 30}, "#5#") {
		cwd := os.get_current_directory(context.temp_allocator)
		state.gui.file_chooser = file_chooser_init(cwd, allocator)
		log.debug("created a file chooser dialog")
	}

	if state.gui.file_chooser != nil {
		if !file_chooser_draw(state.gui.file_chooser, allocator) {
			file_chooser_destroy(state.gui.file_chooser, allocator)
			state.gui.file_chooser = nil
		}
	}
}
