package gltf_rl

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:os"

import gltf "../../"
import rl "vendor:raylib"

Loader_Error :: enum {
	No_Meshes,
	Unsupported_Indices_Type,
}

Error :: union {
	Loader_Error,
	gltf.Error,
}

load_model :: proc(path: string, allocator := context.allocator) -> rl.Model {
	container, err := gltf.glb_load(path, allocator)
	if err != nil {
		fmt.eprintf("error opening glb file: ", err)
		os.exit(1)
	}
	defer gltf.glb_destroy(container, allocator)

	model := rl.Model{}
	load_err := _load_model_from_container(container, &model, allocator)
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

@(private)
_load_model_from_container :: proc(
	container: ^gltf.Glb_Container,
	model: ^rl.Model,
	allocator := context.allocator,
) -> Error {
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

		materialContainer := make([]rl.Material, model.materialCount, allocator)
		model.materials = raw_data(materialContainer)
		model.materials[0] = rl.LoadMaterialDefault()

		matIdx := 1
		for mat in materials {
			materialContainer[matIdx] = rl.LoadMaterialDefault()
			load_material(container, mat, &materialContainer[matIdx])
			matIdx += 1
		}
	} else {
		materialContainer := make([]rl.Material, 1, allocator)
		model.materials = raw_data(materialContainer)
		model.materials[0] = rl.LoadMaterialDefault()
	}

	// load meshes
	meshContainer := make([]rl.Mesh, meshCount, allocator)
	model.meshes = raw_data(meshContainer)

	meshIdx := 0
	for node in nodes {
		if node.mesh == nil {
			continue
		}

		mesh := gltf.get_mesh(container, node.mesh.(gltf.glTF_Id)) or_return
		for primitive in mesh.primitives {
			load_mesh(container, node, primitive, &meshContainer[meshIdx], allocator = allocator) or_return

			meshIdx += 1
		}
	}

	model.meshMaterial = raw_data(make([]i32, model.meshCount, allocator))

	for i in 0 ..< model.meshCount {
		model.meshMaterial[i] = 1
	}

	return nil
}

load_material :: proc(container: ^gltf.Glb_Container, mat: gltf.glTF_Material, material: ^rl.Material) -> Error {
	if (mat.pbrMetallicRoughness != nil) {
		pbr := mat.pbrMetallicRoughness.(gltf.glTF_Material_Pbr_Metallic_Roughness)

		if (pbr.baseColorTexture != nil) {
			b_color_tex := pbr.baseColorTexture.(gltf.glTF_Texture_Info)
			img := gltf.get_texture_image(container, b_color_tex.index) or_return

			if img.data != nil {
				material.maps[rl.MaterialMapIndex.ALBEDO].texture = rl.LoadTextureFromImage(
					rl.Image {
						data = img.data,
						width = img.width,
						height = img.height,
						mipmaps = img.mipmaps,
						format = image_format_from_channels(img.channels),
					},
				)
			}
		}

		switch base_color_factor in pbr.baseColorFactor {
		case []f64:
			#assert(type_of(base_color_factor) == []f64)
			material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color {
				u8(base_color_factor[0]) * 255,
				u8(base_color_factor[1]) * 255,
				u8(base_color_factor[2]) * 255,
				u8(base_color_factor[3]) * 255,
			}
		case:
			material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color{255, 255, 255, 255}
		}

		if (pbr.metallicRoughnessTexture != nil) {
			metr_tex := pbr.metallicRoughnessTexture.(gltf.glTF_Texture_Info)
			img := gltf.get_texture_image(container, metr_tex.index) or_return

			if img.data != nil {
				material.maps[rl.MaterialMapIndex.ROUGHNESS].texture = rl.LoadTextureFromImage(
					rl.Image {
						data = img.data,
						width = img.width,
						height = img.height,
						mipmaps = img.mipmaps,
						format = image_format_from_channels(img.channels),
					},
				)
			}

			switch roughness in pbr.roughnessFactor {
			case f64:
				#assert(type_of(roughness) == f64)
				material.maps[rl.MaterialMapIndex.ROUGHNESS].value = f32(roughness)
			case:
				material.maps[rl.MaterialMapIndex.ROUGHNESS].value = 1
			}

			switch metallness in pbr.metallicFactor {
			case f64:
				#assert(type_of(metallness) == f64)
				material.maps[rl.MaterialMapIndex.METALNESS].value = f32(metallness)
			case:
				material.maps[rl.MaterialMapIndex.METALNESS].value = 1
			}
		}

		if mat.normalTexture != nil {
			normal_texture := mat.normalTexture.(gltf.glTF_Material_Normal_Texture_Info)
			img := gltf.get_texture_image(container, normal_texture.index) or_return

			if img.data != nil {
				material.maps[rl.MaterialMapIndex.NORMAL].texture = rl.LoadTextureFromImage(
					rl.Image {
						data = img.data,
						width = img.width,
						height = img.height,
						mipmaps = img.mipmaps,
						format = image_format_from_channels(img.channels),
					},
				)
			}
		}

		if mat.occlusionTexture != nil {
			occlusion_texture := mat.occlusionTexture.(gltf.glTF_Material_Occlusion_Texture_Info)
			img := gltf.get_texture_image(container, occlusion_texture.index) or_return

			if img.data != nil {
				material.maps[rl.MaterialMapIndex.OCCLUSION].texture = rl.LoadTextureFromImage(
					rl.Image {
						data = img.data,
						width = img.width,
						height = img.height,
						mipmaps = img.mipmaps,
						format = image_format_from_channels(img.channels),
					},
				)
			}
		}

		if mat.emissiveTexture != nil {
			emissive_texture := mat.emissiveTexture.(gltf.glTF_Texture_Info)
			img := gltf.get_texture_image(container, emissive_texture.index) or_return

			if img.data != nil {
				material.maps[rl.MaterialMapIndex.EMISSION].texture = rl.LoadTextureFromImage(
					rl.Image {
						data = img.data,
						width = img.width,
						height = img.height,
						mipmaps = img.mipmaps,
						format = image_format_from_channels(img.channels),
					},
				)
			}

			switch emissive_factor in mat.emissiveFactor {
			case []f64:
				#assert(type_of(emissive_factor) == []f64)
				material.maps[rl.MaterialMapIndex.EMISSION].color = rl.Color {
					u8(emissive_factor[0]) * 255,
					u8(emissive_factor[1]) * 255,
					u8(emissive_factor[2]) * 255,
					255,
				}
			}
		}
	}

	return nil
}

image_format_from_channels :: proc(channels: i32) -> rl.PixelFormat {
	switch channels {
	case 1:
		return .UNCOMPRESSED_GRAYSCALE
	case 2:
		return .UNCOMPRESSED_GRAY_ALPHA
	case 3:
		return .UNCOMPRESSED_R8G8B8
	case 4:
		return .UNCOMPRESSED_R8G8B8A8
	}

	return .UNKNOWN
}

load_mesh :: proc(
	container: ^gltf.Glb_Container,
	node: gltf.glTF_Node,
	primitive: gltf.glTF_Mesh_Primitive,
	mesh: ^rl.Mesh,
	allocator := context.allocator,
) -> Error {
	attributes := primitive.attributes

	for attr, accessor_index in attributes {
		load_attribute(container, accessor_index, attr, mesh, allocator = allocator) or_return
	}

	if primitive.indices != nil {
		load_indices(container, primitive.indices.(gltf.glTF_Id), mesh, allocator = allocator) or_return
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

load_attribute :: proc(
	container: ^gltf.Glb_Container,
	id: gltf.glTF_Id,
	attr: string,
	mesh: ^rl.Mesh,
	allocator := context.allocator,
) -> Error {
	accessor := gltf.get_accessor(container, id) or_return

	if attr == "POSITION" {
		vertices := make([]f32, accessor.count * 3, allocator)
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
		normals := make([]f32, accessor.count * 3, allocator)
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
		tangents := make([]f32, accessor.count * 4, allocator)
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
		texcoords := make([]f32, accessor.count * 2, allocator)
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

load_indices :: proc(
	container: ^gltf.Glb_Container,
	id: gltf.glTF_Id,
	mesh: ^rl.Mesh,
	allocator := context.allocator,
) -> Error {
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
		indices := make([]u16, accessor.count, allocator)
		mesh.indices = raw_data(indices)

		gltf.read_buffer(v, mesh.indices, accessor.count * size_of(u16)) or_return
		return nil
	}

	return .Unsupported_Indices_Type
}
