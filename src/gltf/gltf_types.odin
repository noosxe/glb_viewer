package gltf

glTF_Id :: int

// extensions - any object?
// extras - anything, maybe key-value pairs?
glTF_Property :: struct {}

glTF_Child_Of_Root_Property :: struct {
	using _: glTF_Property,
	name:    Maybe(string),
}

glTF_Accessor_Component_Type :: enum int {
	BYTE           = 5120,
	UNSIGNED_BYTE  = 5121,
	SHORT          = 5122,
	UNSIGNED_SHORT = 5123,
	UNSIGNED_INT   = 5125,
	FLOAT          = 5126,
}

glTF_Indices_Component_Type :: enum int {
	UNSIGNED_BYTE  = 5121,
	UNSIGNED_SHORT = 5123,
	UNSIGNED_INT   = 5125,
}

glTF_Accessor_Sparse_Indices :: struct {
	using _:       glTF_Property,
	bufferView:    glTF_Id,
	byteOffset:    Maybe(int),
	componentType: glTF_Indices_Component_Type,
}

glTF_Accessor_Sparse_Values :: struct {
	using _:    glTF_Property,
	bufferView: glTF_Id,
	byteOffset: Maybe(int),
}

glTF_Accessor_Sparse :: struct {
	using _: glTF_Property,
	count:   int,
	indices: glTF_Accessor_Sparse_Indices,
	values:  glTF_Accessor_Sparse_Values,
}

ACCESSOR_TYPE_SCALAR :: "SCALAR"
ACCESSOR_TYPE_VEC2 :: "VEC2"
ACCESSOR_TYPE_VEC3 :: "VEC3"
ACCESSOR_TYPE_VEC4 :: "VEC4"
ACCESSOR_TYPE_MAT2 :: "MAT2"
ACCESSOR_TYPE_MAT3 :: "MAT3"
ACCESSOR_TYPE_MAT4 :: "MAT4"

glTF_Accessor :: struct {
	using _:       glTF_Child_Of_Root_Property,
	bufferView:    Maybe(glTF_Id),
	byteOffset:    Maybe(int),
	componentType: glTF_Accessor_Component_Type,
	normalized:    Maybe(bool),
	count:         int,
	type:          string, // SCALAR, VEC2, VEC3, VEC4, MAT2, MAT3, MAT4
	max:           Maybe([]f64),
	min:           Maybe([]f64),
	sparse:        Maybe(glTF_Accessor_Sparse),
}

glTF_Animation_Channel_Target :: struct {
	using _: glTF_Property,
	node:    Maybe(glTF_Id),
	path:    string, // translation, rotation, scale, weights
}

glTF_Animation_Channel :: struct {
	using _: glTF_Property,
	sampler: glTF_Id,
	target:  glTF_Animation_Channel_Target,
}

glTF_Animation_Sampler :: struct {
	using _:       glTF_Property,
	input:         glTF_Id,
	interpolation: Maybe(string), // LINEAR, STEP, CUBICSPLINE
	output:        glTF_Id,
}

glTF_Animation :: struct {
	using _:  glTF_Child_Of_Root_Property,
	channels: []glTF_Animation_Channel,
	samplers: []glTF_Animation_Sampler,
}

glTF_Asset :: struct {
	using _:    glTF_Property,
	copyright:  Maybe(string),
	generator:  Maybe(string),
	version:    string,
	minVersion: Maybe(string),
}

glTF_Buffer :: struct {
	using _:    glTF_Child_Of_Root_Property,
	uri:        Maybe(string),
	byteLength: int,
}

glTF_Bind_Buffer :: enum {
	ARRAY_BUFFER         = 34962,
	ELEMENT_ARRAY_BUFFER = 34963,
}

glTF_Buffer_View :: struct {
	using _:    glTF_Child_Of_Root_Property,
	buffer:     glTF_Id,
	byteOffset: Maybe(int),
	byteLength: int,
	byteStride: Maybe(int),
	target:     Maybe(glTF_Bind_Buffer),
}

glTF_Camera_Orthographic :: struct {
	using _: glTF_Property,
	xmag:    f64,
	ymag:    f64,
	zfar:    f64,
	znear:   f64,
}

glTF_Camera_Perspective :: struct {
	using _:     glTF_Property,
	aspectRatio: Maybe(f64),
	yfov:        f64,
	zfar:        Maybe(f64),
	znear:       f64,
}

GLTF_CAMERA_PERSPECTIVE :: "perspective"
GLTF_CAMERA_ORTHOGRAPHIC :: "orthographic"

glTF_Camera :: struct {
	using _:      glTF_Child_Of_Root_Property,
	orthographic: Maybe(glTF_Camera_Orthographic),
	perspective:  Maybe(glTF_Camera_Perspective),
	type:         string, // perspective, orthographic
}

GLTF_IMAGE_JPEG :: "image/jpeg"
GLTF_IMAGE_PNG :: "image/png"

glTF_Image :: struct {
	using _:    glTF_Child_Of_Root_Property,
	uri:        Maybe(string),
	mimeType:   Maybe(string), // image/jpeg, image/png
	bufferView: Maybe(glTF_Id),
}

glTF_Texture_Info :: struct {
	using _:  glTF_Property,
	index:    glTF_Id,
	texCoord: int, // default: 0
}

glTF_Material_Pbr_Metallic_Roughness :: struct {
	using _:                  glTF_Property,
	baseColorFactor:          Maybe([]f64), // default: [ 1.0, 1.0, 1.0, 1.0 ]
	baseColorTexture:         Maybe(glTF_Texture_Info),
	metallicFactor:           Maybe(f64), // default: 1
	roughnessFactor:          Maybe(f64), // default: 1 ???
	metallicRoughnessTexture: Maybe(glTF_Texture_Info),
}

glTF_Material_Normal_Texture_Info :: struct {
	using _: glTF_Texture_Info,
	scale:   Maybe(f64), // default: 1 ???
}

glTF_Material_Occlusion_Texture_Info :: struct {
	using _:  glTF_Texture_Info,
	strength: Maybe(f64), // default: 1 ???
}

GLTF_MATERIAL_ALPHA_MODE_OPAQUE :: "OPAQUE"
GLTF_MATERIAL_ALPHA_MODE_MASK :: "MASK"
GLTF_MATERIAL_ALPHA_MODE_BLEND :: "BLEND"

glTF_Material :: struct {
	using _:              glTF_Child_Of_Root_Property,
	pbrMetallicRoughness: Maybe(glTF_Material_Pbr_Metallic_Roughness),
	normalTexture:        Maybe(glTF_Material_Normal_Texture_Info),
	occlusionTexture:     Maybe(glTF_Material_Occlusion_Texture_Info),
	emissiveTexture:      Maybe(glTF_Texture_Info),
	emissiveFactor:       Maybe([]f64), // default: [ 0.0, 0.0, 0.0 ]
	alphaMode:            Maybe(string), // OPAQUE, MASK, BLEND, default: OPAQUE ???
	alphaCutoff:          Maybe(f64), // default: 0.5 ???
	doubleSided:          bool,
}

glTF_Mesh_Primitive_Type :: enum {
	POINTS         = 0,
	LINES          = 1,
	LINE_LOOP      = 2,
	LINE_STRIP     = 3,
	TRIANGLES      = 4,
	TRIANGLE_STRIP = 5,
	TRIANGLE_FAN   = 6,
}

glTF_Mesh_Primitive :: struct {
	using _:    glTF_Property,
	attributes: map[string]int,
	indices:    Maybe(glTF_Id),
	material:   Maybe(glTF_Id),
	mode:       Maybe(glTF_Mesh_Primitive_Type), // default TRIANGLES
	targets:    []map[string]int,
}

glTF_Mesh :: struct {
	using _:    glTF_Child_Of_Root_Property,
	primitives: []glTF_Mesh_Primitive,
	weights:    Maybe([]f64),
}

glTF_Node :: struct {
	using _:               glTF_Child_Of_Root_Property,
	camera:                Maybe(glTF_Id),
	children:              Maybe([]glTF_Id),
	skin:                  Maybe(glTF_Id),
	transformation_matrix: Maybe([]f64) `json:"matrix"`, // [ 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0 ]
	mesh:                  Maybe(glTF_Id),
	rotation:              Maybe([]f64), // [ 0.0, 0.0, 0.0, 1.0 ]
	scale:                 Maybe([]f64), // [ 1.0, 1.0, 1.0 ]
	translation:           Maybe([]f64), // [ 0.0, 0.0, 0.0 ]
	weights:               Maybe([]f64),
}

glTF_Magnification_Filter :: enum {
	NEAREST = 9728,
	LINEAR  = 9729,
}

glTF_Minification_Filter :: enum {
	NEAREST                = 9728,
	LINEAR                 = 9729,
	NEAREST_MIPMAP_NEAREST = 9984,
	LINEAR_MIPMAP_NEAREST  = 9985,
	NEAREST_MIPMAP_LINEAR  = 9986,
	LINEAR_MIPMAP_LINEAR   = 9987,
}

glTF_Texture_Wrapping_Mode :: enum {
	CLAMP_TO_EDGE   = 33071,
	MIRRORED_REPEAT = 33648,
	REPEAT          = 10497,
}

glTF_Sampler :: struct {
	using _:   glTF_Child_Of_Root_Property,
	magFilter: Maybe(glTF_Magnification_Filter),
	minFilter: Maybe(glTF_Minification_Filter),
	wrapS:     Maybe(glTF_Texture_Wrapping_Mode), // default: REPEAT
	wrapT:     Maybe(glTF_Texture_Wrapping_Mode), // default: REPEAT
}

glTF_Scene :: struct {
	using _: glTF_Child_Of_Root_Property,
	nodes:   Maybe([]glTF_Id),
}

glTF_Skin :: struct {
	using _:             glTF_Child_Of_Root_Property,
	inverseBindMatrices: Maybe(glTF_Id),
	skeleton:            Maybe(glTF_Id),
	joints:              []glTF_Id,
}

glTF_Texture :: struct {
	using _: glTF_Child_Of_Root_Property,
	sampler: Maybe(glTF_Id),
	source: Maybe(glTF_Id),
}

glTF_Document :: struct {
	using _:            glTF_Property,
	extensionsUsed:     Maybe([]string),
	extensionsRequired: Maybe([]string),
	accessors:          Maybe([]glTF_Accessor),
	animations:         Maybe([]glTF_Animation),
	asset:              glTF_Asset,
	buffers:            Maybe([]glTF_Buffer),
	bufferViews:        Maybe([]glTF_Buffer_View),
	cameras:            Maybe([]glTF_Camera),
	images:             Maybe([]glTF_Image),
	materials:          Maybe([]glTF_Material),
	meshes:             Maybe([]glTF_Mesh),
	nodes:              Maybe([]glTF_Node),
	samplers:           Maybe([]glTF_Sampler),
	scene:              Maybe(glTF_Id),
	scenes:             Maybe([]glTF_Scene),
	skins:              Maybe([]glTF_Skin),
	textures:           Maybe([]glTF_Texture),
}
