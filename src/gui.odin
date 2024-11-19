package glb_viewer

import "core:os"
import "core:log"

import rl "vendor:raylib"

Gui_File_Chooser :: struct {
	dir:          string,
	entries:      []os.File_Info,
	items:        []cstring,
	scroll_index: i32,
	active:       i32,
	focus:        i32,
	dialog_rect:  rl.Rectangle,
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
		chooser.dialog_rect = rl.Rectangle{100, 100, 400, 300}
	}

	return chooser
}

file_chooser_destroy :: proc(file_chooser: ^Gui_File_Chooser, allocator := context.allocator) {
	for fi in file_chooser.entries {
		os.file_info_delete(fi, allocator)
	}

	delete(file_chooser.entries, allocator)
	delete(file_chooser.items, allocator)

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
