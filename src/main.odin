package glb_viewer

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"

import "gltf"
import rl "vendor:raylib"

Loader_Error :: enum {
	No_Meshes,
	Unsupported_Indices_Type,
}

Error :: union {
	Loader_Error,
	gltf.Error,
}

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

	rl.InitWindow(1280, 720, "GLB Viewer")
	rl.SetTargetFPS(144)
	rl.SetMouseCursor(rl.MouseCursor.ARROW)

	camera := rl.Camera3D {
		position   = rl.Vector3{10, 10, 10},
		target     = rl.Vector3{0, 0, 0},
		up         = rl.Vector3{0, 1, 0},
		fovy       = 5,
		projection = .ORTHOGRAPHIC,
	}

	model := load_model_from_file(path, arena_allocator)

	for !rl.WindowShouldClose() {
		rl.UpdateCamera(&camera, rl.CameraMode.ORBITAL)

		rl.BeginDrawing()
		rl.BeginMode3D(camera)
		rl.ClearBackground(rl.BLUE)
		rl.DrawGrid(20, 1)

		rl.DrawModelWires(model, {0, 0, 0}, 1, rl.WHITE)

		rl.EndMode3D()
		rl.EndDrawing()
	}

	rl.CloseWindow()

	vmem.arena_destroy(&loader_arena)
}

load_model_from_file :: proc(path: string, allocator: mem.Allocator) -> rl.Model {
	container, err := gltf.glb_load(path)
	if err != nil {
		fmt.eprintf("error opening glb file: ", err)
		os.exit(1)
	}
	defer gltf.glb_destroy(container)

	model := rl.Model{}
	load_err := load_model(container, &model, allocator)
	if load_err != nil {
		log.fatal("error: failed to load model", load_err)
		os.exit(1)
	}

	model.transform = rl.Matrix(1)

	for i in 0 ..< model.meshCount {
		rl.UploadMesh(&model.meshes[i], false)
	}

	return model
}

load_model :: proc(container: ^gltf.Glb_Container, model: ^rl.Model, allocator: mem.Allocator) -> Error {
	context.allocator = allocator

	if container.gltf.meshes == nil {
		return .No_Meshes
	}


	nodes := gltf.get_nodes(container)

	// count meshes
	meshCount := 0
	for node in nodes {
		if node.mesh == nil {
			continue
		}

		mesh := gltf.get_mesh(container, node.mesh.(gltf.glTF_Id)) or_return
		for primitive in mesh.primitives {
			meshCount += 1
		}
	}
	model.meshCount = i32(meshCount)

	// materials
	if container.gltf.materials != nil {
		materials := container.gltf.materials.([]gltf.glTF_Material)
		model.materialCount = i32(len(materials)) + 1

		materialContainer := make([]rl.Material, model.materialCount)
		model.materials = raw_data(materialContainer)
		model.materials[0] = rl.LoadMaterialDefault()

		matIdx := 1
		for mat in materials {
			materialContainer[matIdx] = rl.LoadMaterialDefault()
			// load_material(container, mat, &materialContainer[matIdx])
			matIdx += 1
		}
	} else {
		materialContainer := make([]rl.Material, 1)
		model.materials = raw_data(materialContainer)
		model.materials[0] = rl.LoadMaterialDefault()
	}

	// load meshes
	meshContainer := make([]rl.Mesh, meshCount)
	model.meshes = raw_data(meshContainer)

	meshIdx := 0
	for node in nodes {
		if node.mesh == nil {
			continue
		}

		mesh := gltf.get_mesh(container, node.mesh.(gltf.glTF_Id)) or_return
		for primitive in mesh.primitives {
			load_mesh(container, node, primitive, &meshContainer[meshIdx]) or_return

			meshIdx += 1
		}
	}

	model.meshMaterial = raw_data(make([]i32, model.meshCount))

	for i in 0 ..< model.meshCount {
		model.meshMaterial[0] = 0
	}

	return nil
}

load_material :: proc(container: ^gltf.Glb_Container, mat: gltf.glTF_Material, material: ^rl.Material) -> Error {
	if (mat.pbrMetallicRoughness != nil) {
		pbr := mat.pbrMetallicRoughness.(gltf.glTF_Material_Pbr_Metallic_Roughness)

		if (pbr.baseColorTexture != nil) {
			b_color_tex := pbr.baseColorTexture.(gltf.glTF_Texture_Info)
			gltf.get_texture_image(container, b_color_tex.index)
		}
	}

	return nil
}

load_mesh :: proc(
	container: ^gltf.Glb_Container,
	node: gltf.glTF_Node,
	primitive: gltf.glTF_Mesh_Primitive,
	mesh: ^rl.Mesh,
) -> Error {
	attributes := primitive.attributes

	for attr, accessor_index in attributes {
		load_attribute(container, accessor_index, attr, mesh) or_return
	}

	if primitive.indices != nil {
		load_indices(container, primitive.indices.(gltf.glTF_Id), mesh) or_return
	} else {
		mesh.triangleCount = mesh.vertexCount / 3
	}

	transform := node_transform(node)

	vertices := mesh.vertices
	for i in 0 ..< mesh.vertexCount {
		v4 := linalg.Vector4f32{vertices[3 * i], vertices[3 * i + 1], vertices[3 * i + 2], 1}
		v4 = transform * v4

		vertices[3 * i] = v4.x
		vertices[3 * i + 1] = v4.y
		vertices[3 * i + 2] = v4.z
	}

	return nil
}

node_transform :: proc(node: gltf.glTF_Node) -> matrix[4, 4]f32 {
	rotation := quaternion128(1)
	scale := linalg.Vector3f32{1, 1, 1}
	translation := linalg.Vector3f32{0, 0, 0}

	if node.rotation != nil {
		rot := node.rotation.([]f64)
		rotation = linalg.quaternion_angle_axis_f32(
			f32(rot[3]),
			linalg.Vector3f32{f32(rot[0]), f32(rot[1]), f32(rot[2])},
		)
	}

	if node.scale != nil {
		sc := node.scale.([]f64)
		scale = linalg.Vector3f32{f32(sc[0]), f32(sc[1]), f32(sc[2])}
	}

	if node.translation != nil {
		tr := node.translation.([]f64)
		translation = linalg.Vector3f32{f32(tr[0]), f32(tr[1]), f32(tr[2])}
	}

	scale_mat := linalg.matrix4_scale(scale)
	translation_mat := linalg.matrix4_translate(translation)

	return linalg.Matrix4x4f32(1) * linalg.matrix4_from_quaternion(rotation) * scale_mat * translation_mat
}

load_attribute :: proc(container: ^gltf.Glb_Container, id: gltf.glTF_Id, attr: string, mesh: ^rl.Mesh) -> Error {
	accessor := gltf.get_accessor(container, id) or_return

	if attr == "POSITION" {
		vertices := make([]f32, accessor.count * 3)
		mesh.vertexCount = i32(accessor.count)
		mesh.vertices = raw_data(vertices)

		switch bf in accessor.bufferView {
		case int:
			if accessor.bufferView != nil {
				v, err := gltf.get_buffer_view(container, bf)

				if err == nil {
					gltf.read_buffer(v, mesh.vertices, accessor.count * 3 * size_of(f32)) or_return
				}
			}
		}
	}

	if attr == "NORMAL" {
		normals := make([]f32, accessor.count * 3)
		mesh.normals = raw_data(normals)

		switch bf in accessor.bufferView {
		case int:
			if accessor.bufferView != nil {
				v, err := gltf.get_buffer_view(container, bf)

				if err == nil {
					gltf.read_buffer(v, mesh.normals, accessor.count * 3 * size_of(f32)) or_return
				}
			}
		}
	}

	if attr == "TANGENT" {
		tangents := make([]f32, accessor.count * 4)
		mesh.tangents = raw_data(tangents)

		switch bf in accessor.bufferView {
		case int:
			if accessor.bufferView != nil {
				v, err := gltf.get_buffer_view(container, bf)

				if err == nil {
					gltf.read_buffer(v, mesh.tangents, accessor.count * 4 * size_of(f32)) or_return
				}
			}
		}
	}

	if attr == "TEXCOORD_0" {
		texcoords := make([]f32, accessor.count * 2)
		mesh.texcoords = raw_data(texcoords)

		switch bf in accessor.bufferView {
		case int:
			if accessor.bufferView != nil {
				v, err := gltf.get_buffer_view(container, bf)

				if err == nil {
					gltf.read_buffer(v, mesh.texcoords, accessor.count * 2 * size_of(f32)) or_return
				}
			}
		}
	}

	return nil
}

load_indices :: proc(container: ^gltf.Glb_Container, id: gltf.glTF_Id, mesh: ^rl.Mesh) -> Error {
	accessor := gltf.get_accessor(container, id) or_return

	if accessor.bufferView == nil {
		return nil
	}

	mesh.triangleCount = i32(accessor.count) / 3
	v := gltf.get_buffer_view(container, accessor.bufferView.(gltf.glTF_Id)) or_return

	switch accessor.componentType {
	case .BYTE:
		log.fatal("BYTE indices not implemented")

	case .FLOAT:
		log.fatal("FLOAT indices not implemented")

	case .SHORT:
		log.fatal("SHORT indices not implemented")

	case .UNSIGNED_BYTE:
		log.fatal("UNSIGNED_BYTE indices not implemented")

	case .UNSIGNED_INT:
		log.fatal("UNSIGNED_INT indices not implemented")

	case .UNSIGNED_SHORT:
		indices := make([]u16, accessor.count)
		mesh.indices = raw_data(indices)

		gltf.read_buffer(v, mesh.indices, accessor.count * size_of(u16)) or_return
		return nil
	}

	return .Unsupported_Indices_Type
}
