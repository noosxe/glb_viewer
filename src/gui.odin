package glb_viewer

import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

Color_Background :: rl.Color{26, 27, 38, 255}
Color_Background_Lighter :: rl.Color{30, 31, 41, 255}
Color_Foreground :: rl.Color{192, 202, 245, 255}
Color_Border_Active :: rl.Color{122, 162, 247, 255}
Color_Border_Inactive :: rl.Color{41, 46, 66, 255}

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
	color_active:   rl.Color,
	color_inactive: rl.Color,
	width:          f32,
}

Gui_Active_Border :: Gui_Border {
	color_active   = Color_Border_Active,
	color_inactive = Color_Border_Inactive,
	width          = 3,
}

Gui_Inactive_Border :: Gui_Border {
	color_active   = Color_Border_Active,
	color_inactive = Color_Border_Inactive,
	width          = 3,
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
		child_rect := gui_calculate_layout(
			child,
			rl.Rectangle{x = 0, y = 0, width = f32(w), height = f32(h)},
		)
		child.runtime_rect = child_rect
	}

	for &child in state.children {
		gui_component_draw(
			child,
			rl.Rectangle{x = 0, y = 0, width = f32(w), height = f32(h)},
		)
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

gui_calculate_layout :: proc(
	component: ^Gui_Component,
	rect: rl.Rectangle, // total area available for drawing
) -> (
	occupied_rect: rl.Rectangle,
) {
	layout := component.layout
	padding := layout.padding
	border := layout.border

	// free area available for drawing
	content_rect := rl.Rectangle {
		x      = border[3].width + padding[3],
		y      = border[0].width + padding[0],
		width  = rect.width - border[1].width - border[3].width - padding[1] - padding[3],
		height = rect.height - border[0].width - border[0].width - padding[0] - padding[2],
	}

	switch layout.flow {
	case .Horizontal:
		width_contain: bool
		switch w in layout.width {
		case Gui_Sizing:
			if w == .Stretch {
				occupied_rect.width = rect.width
			} else {
				width_contain = true
			}
		case f32:
			occupied_rect.width = w
		}

		height_contain: bool
		switch h in layout.height {
		case Gui_Sizing:
			if h == .Stretch {
				occupied_rect.height = rect.height
			} else {
				height_contain = true
			}
		case f32:
			occupied_rect.height = h
		}

		content_width: f32
		for &child in component.children {
			child_rect := gui_calculate_layout(
				child,
				rl.Rectangle {
					x = content_rect.x + content_width,
					y = content_rect.y,
					width = content_rect.width - content_width,
					height = content_rect.height,
				},
			)
			child.runtime_rect = child_rect

			content_width += child_rect.width

			if height_contain {
				occupied_rect.height =
					math.max(occupied_rect.height, child_rect.height) +
					border[0].width +
					border[2].width +
					padding[0] +
					padding[2]
			}
		}

		if width_contain {
			occupied_rect.width = content_width
		}
	case .Vertical:
		width_contain: bool
		switch w in layout.width {
		case Gui_Sizing:
			if w == .Stretch {
				occupied_rect.width = rect.width
			} else {
				width_contain = true
			}
		case f32:
			occupied_rect.width = w
		}

		height_contain: bool
		switch h in layout.height {
		case Gui_Sizing:
			if h == .Stretch {
				occupied_rect.height = rect.height
			} else {
				height_contain = true
			}
		case f32:
			occupied_rect.height = h
		}

		content_height: f32
		for &child in component.children {
			child_rect := gui_calculate_layout(
				child,
				rl.Rectangle {
					x = content_rect.x,
					y = content_rect.y + content_height,
					width = content_rect.width,
					height = content_rect.height - content_height,
				},
			)
			child.runtime_rect = child_rect

			if width_contain {
				occupied_rect.width =
					math.max(occupied_rect.width, child_rect.width) +
					border[1].width +
					border[3].width +
					padding[1] +
					padding[3]
			}

			content_height += child_rect.height
		}

		if height_contain {
			occupied_rect.height = content_height
		}
	}

	switch layout.h_align {
	case .Start:
		occupied_rect.x = rect.x
	case .Center:
		occupied_rect.x = (rect.width - occupied_rect.width) / 2
	case .End:
		occupied_rect.x = rect.width - occupied_rect.width
	}

	switch layout.v_align {
	case .Start:
		occupied_rect.y = rect.y
	case .Center:
		occupied_rect.y = (rect.height - occupied_rect.height) / 2
	case .End:
		occupied_rect.y = rect.height - occupied_rect.height
	}

	return
}

gui_draw_border :: proc(component: ^Gui_Component, rect: rl.Rectangle) {
	border := component.layout.border
	is_active: bool

	{
		mouse_pos := rl.GetMousePosition()
		is_active = rl.CheckCollisionPointRec(mouse_pos, rect)
	}

	if border[0].width > 0 {
		rl.DrawRectangle(
			i32(rect.x - border[3].width),
			i32(rect.y - border[0].width),
			i32(rect.width + border[3].width + border[1].width),
			i32(border[0].width),
			is_active ? border[0].color_active : border[0].color_inactive,
		)
	}

	if border[1].width > 0 {
		rl.DrawRectangle(
			i32(rect.x + rect.width),
			i32(rect.y - border[0].width),
			i32(border[1].width),
			i32(rect.height + border[0].width + border[2].width),
			is_active ? border[1].color_active : border[1].color_inactive,
		)
	}

	if border[2].width > 0 {
		rl.DrawRectangle(
			i32(rect.x - border[3].width),
			i32(rect.y + rect.height),
			i32(rect.width + border[3].width + border[1].width),
			i32(border[2].width),
			is_active ? border[2].color_active : border[2].color_inactive,
		)
	}

	if border[3].width > 0 {
		rl.DrawRectangle(
			i32(rect.x - border[3].width),
			i32(rect.y - border[0].width),
			i32(border[3].width),
			i32(rect.height + border[0].width + border[2].width),
			is_active ? border[3].color_active : border[3].color_inactive,
		)
	}
}

//------------------------------------------------------------------------------
// Base Component
//------------------------------------------------------------------------------

Gui_Component :: struct {
	instance:     Gui_Component_Types,
	layout:       Gui_Component_Layout,
	children:     [dynamic]^Gui_Component,

	// Runtime
	runtime_rect: rl.Rectangle,
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
gui_component_draw :: proc(
	component: ^Gui_Component,
	parent_rect: rl.Rectangle,
) {
	instance := component.instance
	own_rect := component.runtime_rect
	final_rect := rl.Rectangle {
		x      = parent_rect.x + own_rect.x,
		y      = parent_rect.y + own_rect.y,
		width  = own_rect.width,
		height = own_rect.height,
	}

	switch &c in instance {
	case Gui_Container:
		gui_container_draw(&c, final_rect)
	case Gui_Vertical_Layout:
		gui_vertical_layout_draw(&c, final_rect)
	case Gui_Horizontal_Layout:
		gui_horizontal_layout_draw(&c, final_rect)
	case Gui_Toolbar:
		gui_toolbar_draw(&c, final_rect)
	case Gui_Icon_Button:
		gui_icon_button_draw(&c, final_rect)
	case Gui_Dialog:
		gui_dialog_draw(&c, final_rect)
	}

	for &child in component.children {
		gui_component_draw(child, final_rect)
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
	{
		layout := layout
		layout.flow = .Horizontal
		layout.width = .Stretch
		layout.height = .Contain
		layout.padding = {5, 5, 5, 5}
	}

	r = new(Gui_Component, allocator)
	r.instance = Gui_Toolbar {
		base = r,
	}
	r.layout = layout
	return
}

gui_toolbar_draw :: proc(instance: ^Gui_Toolbar, rect: rl.Rectangle) {
	rl.DrawRectangleRec(rect, Color_Background_Lighter)
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
	layout.border = {
		Gui_Active_Border,
		Gui_Active_Border,
		Gui_Active_Border,
		Gui_Active_Border,
	}

	r = new(Gui_Component, allocator)
	r.instance = Gui_Dialog {
		base = r,
	}
	r.layout = layout
	fmt.println(r.layout)
	return
}

gui_dialog_draw :: proc(instance: ^Gui_Dialog, rect: rl.Rectangle) {
	gui_draw_border(instance.base, rect)

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
