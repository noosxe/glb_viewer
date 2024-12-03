package glb_viewer

import "core:fmt"
import "core:log"
import "core:math/linalg"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"

import gltf_rl "gltf/adapters/raylib"
import rl "vendor:raylib"

import "ext:back"


App_State :: struct {
	preview: Preview_State,
	gui:     ^Gui_State,
}

Preview_State :: struct {
	camera: rl.Camera3D,
	model:  ^rl.Model,
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
	defer vmem.arena_destroy(&loader_arena)
	arena_allocator := vmem.arena_allocator(&loader_arena)

	rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "GLB Viewer")
	defer rl.CloseWindow()
	rl.SetTargetFPS(144)
	rl.SetMouseCursor(rl.MouseCursor.ARROW)

	app_state.preview.camera = rl.Camera3D {
		position   = rl.Vector3{3, 3, 3},
		target     = rl.Vector3{0, 0, 0},
		up         = rl.Vector3{0, 1, 0},
		fovy       = 70,
		projection = .PERSPECTIVE,
	}

	app_state.gui = gui_init(arena_allocator)
	defer {
		gui_destroy(app_state.gui, arena_allocator)
		app_state.gui = nil
	}

	{
		toolbar := gui_toolbar_make(allocator = arena_allocator)
		open_file := gui_icon_button_make(
			.ICON_FILE_OPEN,
			onclick = b_click,
			allocator = arena_allocator,
		)

		append(&toolbar.children, open_file)
		append(&app_state.gui.children, toolbar)

		dialog := gui_dialog_make("Open File", allocator = arena_allocator)
		dialog.layout.width = 400
		dialog.layout.height = 300
		append(&app_state.gui.children, dialog)
	}

	// model := gltf_rl.load_model(path, arena_allocator)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(Color_Background)

		draw_preview(&app_state.preview)
		gui_draw(app_state.gui, arena_allocator)

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

}

draw_preview :: proc(state: ^Preview_State) {
	rl.UpdateCamera(&state.camera, rl.CameraMode.ORBITAL)
	rl.BeginMode3D(state.camera)
	rl.DrawGrid(20, 1)

	if state.model != nil {
		rl.DrawModel(state.model^, {0, 0, 0}, 1, rl.WHITE)
	}

	rl.EndMode3D()
}

b_click :: proc() {
	fmt.println("click")
}
