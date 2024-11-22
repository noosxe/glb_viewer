package glb_viewer

import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

file_chooser_width :: 500
file_chooser_height :: 400

Gui_State :: struct {
	file_chooser: ^Gui_File_Chooser,
}

Gui_File_Chooser :: struct {
	dir:          string,
	entries:      []os.File_Info,
	items:        []cstring,
	scroll_index: i32,
	active:       i32,
	focus:        i32,
	dialog_rect:  rl.Rectangle,
}

//----------------------------------------------------------------------------------
// Generic Component
//----------------------------------------------------------------------------------

Gui_Component_Type :: enum {
	Vertical_Layout,
	Horizontal_Layout,
}

Gui_Component_Base :: struct {
	type:      Gui_Component_Type,
	draw_proc: proc(instance: ^Gui_Component, rect: rl.Rectangle),
	instance:  Gui_Component,
}

Gui_Component :: union {
	Gui_Vertical_Layout,
	Gui_Horizontal_Layout,
}

//----------------------------------------------------------------------------------
// Vertical Layout
//----------------------------------------------------------------------------------

Gui_Vertical_Layout :: struct {
	using _:  Gui_Component_Base,
	children: [dynamic]^Gui_Component,
}

gui_vertical_layout_init :: proc(allocator := context.allocator) -> ^Gui_Vertical_Layout {
	r := new(Gui_Vertical_Layout, allocator)
	r.type = .Vertical_Layout
	r.draw_proc = gui_vertical_layout_draw
	r.instance = Gui_Vertical_Layout{}
	return r
}

gui_vertical_layout_draw :: proc(instance: ^Gui_Vertical_Layout, rect: rl.Rectangle) {

}

//----------------------------------------------------------------------------------
// Horizontal Layout
//----------------------------------------------------------------------------------

Gui_Horizontal_Layout :: struct {}

@(private = "file")
Gui_Horizontal_Layout_Component :: Gui_Component(Gui_Horizontal_Layout)
gui_horizontal_layout_init :: proc(allocator := context.allocator) -> ^Gui_Horizontal_Layout_Component {
	r := new(Gui_Horizontal_Layout_Component, allocator)
	r.type = .Horizontal_Layout
	r.draw_proc = gui_horizontal_layout_draw
	r.instance = Gui_Horizontal_Layout{}
	return r
}

gui_horizontal_layout_draw :: proc(instance: ^Gui_Horizontal_Layout, rect: rl.Rectangle) {

}

gui_init :: proc(allocator := context.allocator) -> ^Gui_State {
	h := gui_horizontal_layout_init()
	v := gui_vertical_layout_init()

	fmt.println(v.instance.children)
	append(&v.instance.children, h)
	fmt.println(v.instance.children)

	return new(Gui_State, allocator)
}

gui_destroy :: proc(state: ^Gui_State, allocator := context.allocator) {
	if state.file_chooser != nil {
		file_chooser_destroy(state.file_chooser, allocator)
	}

	free(state, allocator)
}

gui_draw :: proc(state: ^Gui_State, allocator := context.allocator) {
	w := rl.GetRenderWidth()

	rl.GuiPanel(rl.Rectangle{0, 0, f32(w), 50}, nil)

	if rl.GuiButton(rl.Rectangle{10, 10, 30, 30}, "#5#") {
		cwd := os.get_current_directory(context.temp_allocator)
		state.file_chooser = file_chooser_init(cwd, allocator)
		log.debug("created a file chooser dialog")
	}

	if state.file_chooser != nil {
		if !file_chooser_draw(state.file_chooser, allocator) {
			file_chooser_destroy(state.file_chooser, allocator)
			state.file_chooser = nil
		}
	}
}

file_chooser_init :: proc(path: string, allocator := context.allocator) -> ^Gui_File_Chooser {
	chooser := new(Gui_File_Chooser, allocator)
	chooser.dir = path

	fh, err := os.open(path)
	defer os.close(fh)

	if err != nil {
		log.error(err)
	}

	{
		entries, err := os.read_dir(fh, -1, allocator)

		if err != nil {
			log.error(err)
		}

		chooser.entries = entries
		chooser.items = make([]cstring, len(entries), allocator)

		for i := 0; i < len(entries); i += 1 {
			chooser.items[i] = strings.clone_to_cstring(entries[i].name, allocator)
		}
	}

	{
		screen_width := rl.GetRenderWidth()
		screen_height := rl.GetRenderHeight()
		chooser_x := (screen_width - file_chooser_width) / 2
		chooser_y := (screen_height - file_chooser_height) / 2
		chooser.dialog_rect = rl.Rectangle{f32(chooser_x), f32(chooser_y), file_chooser_width, file_chooser_height}
	}

	return chooser
}

file_chooser_destroy :: proc(file_chooser: ^Gui_File_Chooser, allocator := context.allocator) {
	if file_chooser == nil {
		log.warn("calling destroy with nil")
		return
	}

	if file_chooser.entries != nil {
		for fi in file_chooser.entries {
			os.file_info_delete(fi, allocator)
		}

		delete(file_chooser.entries, allocator)
	}

	if file_chooser.items != nil {
		delete(file_chooser.items, allocator)
	}

	free(file_chooser, allocator)
}

file_chooser_draw :: proc(file_chooser: ^Gui_File_Chooser, allocator := context.allocator) -> bool {
	dialog_result := rl.GuiWindowBox(file_chooser.dialog_rect, "#198# Choose a file")

	rl.GuiListViewEx(
		rl.Rectangle {
			file_chooser.dialog_rect.x + 1,
			file_chooser.dialog_rect.y + 24 + 1,
			file_chooser.dialog_rect.width - 2,
			file_chooser.dialog_rect.height - 24 - 2,
		},
		raw_data(file_chooser.items),
		i32(len(file_chooser.items)),
		&file_chooser.scroll_index,
		&file_chooser.active,
		&file_chooser.focus,
	)

	return dialog_result == 0
}
