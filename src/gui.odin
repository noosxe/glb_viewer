package glb_viewer

import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

Color_Background :: rl.Color{26, 27, 38, 255}
Color_Foreground :: rl.Color{192, 202, 245, 255}

Gui_Alignment :: enum {
	Start,
	Center,
	End,
}

Gui_Sizing :: enum {
	Contain,
	Stretch,
}

Gui_Flow :: enum {
	Vertical,
	Horizontal,
}

Gui_Border :: struct {
	color: rl.Color,
	width: f32,
}

Gui_Component_Layout :: struct {
	width:   union {
		f32,
		Gui_Sizing,
	},
	height:  union {
		f32,
		Gui_Sizing,
	},
	v_align: Gui_Alignment,
	h_align: Gui_Alignment,
	flow:    Gui_Flow,
	padding: [4]f32,
	margin:  [4]f32,
	border:  [4]Gui_Border,
}

gui_calculate_layout :: proc(
	component: ^Gui_Component,
	rect: rl.Rectangle,
) -> (
	size: rl.Vector2,
) {
	layout := component.layout
	padding := layout.padding

	content_rect := rl.Rectangle {
		x      = rect.x + padding[3],
		y      = rect.y + padding[0],
		width  = rect.width - padding[1] - padding[3],
		height = rect.height - padding[0] - padding[2],
	}

	switch layout.flow {
	case .Horizontal:
		width_contain: bool
		switch w in layout.width {
		case Gui_Sizing:
			if w == .Stretch {
				size.x = rect.width
			} else {
				width_contain = true
			}
		case f32:
			size.x = w
		}

		height_contain: bool
		switch h in layout.height {
		case Gui_Sizing:
			if h == .Stretch {
				size.y = rect.height
			} else {
				height_contain = true
			}
		case f32:
			size.y = h
		}

		content_width: f32
		for &child in component.children {
			sz := gui_calculate_layout(
				child,
				rl.Rectangle {
					x = content_rect.x + content_width,
					y = content_rect.y,
					width = content_rect.width - content_width,
					height = content_rect.height,
				},
			)

			content_width += sz.x

			if height_contain {
				size.y = math.max(size.y, sz.y) + padding[0] + padding[2]
			}
		}

		if width_contain {
			size.x = content_width
		}
	case .Vertical:
		width_contain: bool
		switch w in layout.width {
		case Gui_Sizing:
			if w == .Stretch {
				size.x = rect.width
			} else {
				width_contain = true
			}
		case f32:
			size.x = w
		}

		height_contain: bool
		switch h in layout.height {
		case Gui_Sizing:
			if h == .Stretch {
				size.y = rect.height
			} else {
				height_contain = true
			}
		case f32:
			size.y = h
		}

		content_height: f32
		for &child in component.children {
			sz := gui_calculate_layout(
				child,
				rl.Rectangle {
					x = content_rect.x,
					y = content_rect.y + content_height,
					width = content_rect.width,
					height = content_rect.height - content_height,
				},
			)

			if width_contain {
				size.x = math.max(size.x, sz.x) + padding[1] + padding[3]
			}

			content_height += sz.y
		}

		if height_contain {
			size.y = content_height
		}
	}

	component.rect = rl.Rectangle {
		x      = rect.x,
		y      = rect.y,
		width  = size.x,
		height = size.y,
	}

	return
}

//------------------------------------------------------------------------------
// Root Gui
//------------------------------------------------------------------------------

Gui_State :: struct {
	children: [dynamic]^Gui_Component,
}

gui_init :: proc(allocator := context.allocator) -> ^Gui_State {
	return new(Gui_State, allocator)
}

gui_destroy :: proc(state: ^Gui_State, allocator := context.allocator) {
	for &child in state.children {
		gui_component_delete(child, allocator)
	}

	delete(state.children)
	free(state, allocator)
}

gui_draw :: proc(state: ^Gui_State, allocator := context.allocator) {
	w := rl.GetRenderWidth()
	h := rl.GetRenderHeight()

	for &child in state.children {
		gui_calculate_layout(
			child,
			rl.Rectangle{x = 0, y = 0, width = f32(w), height = f32(h)},
		)
	}

	for &child in state.children {
		gui_component_draw(child)
	}
	/*
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
	*/
}

//------------------------------------------------------------------------------
// Base Component
//------------------------------------------------------------------------------

Gui_Component :: struct {
	instance: Gui_Component_Types,
	layout:   Gui_Component_Layout,
	children: [dynamic]^Gui_Component,

	// Runtime
	rect:     rl.Rectangle,
}

Gui_Component_Types :: union {
	Gui_Container,
	Gui_Vertical_Layout,
	Gui_Horizontal_Layout,
	Gui_Toolbar,
	Gui_Icon_Button,
	Gui_Dialog,
}

// Draws any Gui_Component instance.
gui_component_draw :: proc(component: ^Gui_Component) {
	instance := component.instance
	rect := component.rect

	switch &c in instance {
	case Gui_Container:
		gui_container_draw(&c, rect)
	case Gui_Vertical_Layout:
		gui_vertical_layout_draw(&c, rect)
	case Gui_Horizontal_Layout:
		gui_horizontal_layout_draw(&c, rect)
	case Gui_Toolbar:
		gui_toolbar_draw(&c, rect)
	case Gui_Icon_Button:
		gui_icon_button_draw(&c, rect)
	case Gui_Dialog:
		gui_dialog_draw(&c, rect)
	}

	for &child in component.children {
		gui_component_draw(child)
	}
}

gui_component_delete :: proc(
	component: ^Gui_Component,
	allocator := context.allocator,
) {
	for &child in component.children {
		gui_component_delete(child, allocator)
	}

	delete(component.children)
	free(component, allocator)
}

//------------------------------------------------------------------------------
// Container
//------------------------------------------------------------------------------

Gui_Container :: struct {
	using base: ^Gui_Component,
}

gui_container_init :: proc(
	allocator := context.allocator,
) -> (
	r: ^Gui_Component,
) {
	r = new(Gui_Component, allocator)
	r.instance = Gui_Container {
		base = r,
	}
	return
}

gui_container_draw :: proc(instance: ^Gui_Container, rect: rl.Rectangle) {
}

//------------------------------------------------------------------------------
// Vertical Layout
//------------------------------------------------------------------------------

Gui_Vertical_Layout :: struct {
	using base: ^Gui_Component,
}

gui_vertical_layout_make :: proc(
	layout := Gui_Component_Layout{},
	allocator := context.allocator,
) -> (
	r: ^Gui_Component,
) {
	layout := layout
	layout.flow = .Vertical

	r = new(Gui_Component, allocator)
	r.instance = Gui_Vertical_Layout {
		base = r,
	}
	return
}

gui_vertical_layout_draw :: proc(
	instance: ^Gui_Vertical_Layout,
	rect: rl.Rectangle,
) {
}

//------------------------------------------------------------------------------
// Horizontal Layout
//------------------------------------------------------------------------------

Gui_Horizontal_Layout :: struct {
	using base: ^Gui_Component,
}

gui_horizontal_layout_make :: proc(
	layout := Gui_Component_Layout{},
	allocator := context.allocator,
) -> (
	r: ^Gui_Component,
) {
	layout := layout
	layout.flow = .Horizontal

	r = new(Gui_Component, allocator)
	r.instance = Gui_Horizontal_Layout {
		base = r,
	}
	return
}

gui_horizontal_layout_draw :: proc(
	instance: ^Gui_Horizontal_Layout,
	rect: rl.Rectangle,
) {
}

//------------------------------------------------------------------------------
// Toolbar
//------------------------------------------------------------------------------

Gui_Toolbar :: struct {
	using base: ^Gui_Component,
}

gui_toolbar_make :: proc(
	layout := Gui_Component_Layout{},
	allocator := context.allocator,
) -> (
	r: ^Gui_Component,
) {
	layout := layout
	layout.flow = .Horizontal
	layout.width = .Stretch
	layout.height = .Contain
	layout.padding = {5, 5, 5, 5}

	r = new(Gui_Component, allocator)
	r.instance = Gui_Toolbar {
		base = r,
	}
	r.layout = layout
	return
}

gui_toolbar_draw :: proc(instance: ^Gui_Toolbar, rect: rl.Rectangle) {
	rl.DrawRectangleRec(rect, Color_Background)
}

//------------------------------------------------------------------------------
// Icon Button
//------------------------------------------------------------------------------

Gui_Icon_Button :: struct {
	using base: ^Gui_Component,
	icon:       cstring,
	onclick:    proc(),
}

noop_icon_button_click :: proc() {}
gui_icon_button_make :: proc(
	icon: cstring,
	size: f32 = 30,
	onclick := noop_icon_button_click,
	layout := Gui_Component_Layout{},
	allocator := context.allocator,
) -> (
	r: ^Gui_Component,
) {
	layout := layout
	layout.width = size
	layout.height = size

	r = new(Gui_Component, allocator)
	r.instance = Gui_Icon_Button {
		base    = r,
		icon    = icon,
		onclick = onclick,
	}
	r.layout = layout
	return
}

gui_icon_button_draw :: proc(instance: ^Gui_Icon_Button, rect: rl.Rectangle) {
	if rl.GuiButton(rect, instance.icon) {
		instance.onclick()
	}
}

//------------------------------------------------------------------------------
// Dialog
//------------------------------------------------------------------------------

Gui_Dialog :: struct {
	using base: ^Gui_Component,
}

gui_dialog_make :: proc(
	layout := Gui_Component_Layout{},
	allocator := context.allocator,
) -> (
	r: ^Gui_Component,
) {
	layout := layout
	layout.flow = .Vertical
	layout.h_align = .Center
	layout.v_align = .Center

	r = new(Gui_Component, allocator)
	r.instance = Gui_Dialog {
		base = r,
	}
	r.layout = layout
	return
}

gui_dialog_draw :: proc(instance: ^Gui_Dialog, rect: rl.Rectangle) {
	rl.DrawRectangleRec(rect, Color_Background)
}

//------------------------------------------------------------------------------
// File Chooser
//------------------------------------------------------------------------------

file_chooser_width :: 500
file_chooser_height :: 400

Gui_File_Chooser :: struct {
	dir:          string,
	entries:      []os.File_Info,
	items:        []cstring,
	scroll_index: i32,
	active:       i32,
	focus:        i32,
	dialog_rect:  rl.Rectangle,
}

file_chooser_init :: proc(
	path: string,
	allocator := context.allocator,
) -> ^Gui_File_Chooser {
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
			chooser.items[i] = strings.clone_to_cstring(
				entries[i].name,
				allocator,
			)
		}
	}

	{
		screen_width := rl.GetRenderWidth()
		screen_height := rl.GetRenderHeight()
		chooser_x := (screen_width - file_chooser_width) / 2
		chooser_y := (screen_height - file_chooser_height) / 2
		chooser.dialog_rect = rl.Rectangle {
			f32(chooser_x),
			f32(chooser_y),
			file_chooser_width,
			file_chooser_height,
		}
	}

	return chooser
}

file_chooser_destroy :: proc(
	file_chooser: ^Gui_File_Chooser,
	allocator := context.allocator,
) {
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

file_chooser_draw :: proc(
	file_chooser: ^Gui_File_Chooser,
	allocator := context.allocator,
) -> bool {
	dialog_result := rl.GuiWindowBox(
		file_chooser.dialog_rect,
		"#198# Choose a file",
	)


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
