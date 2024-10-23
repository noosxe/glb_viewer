package glb_viewer

glTF_Id :: int

// extensionsa - any object?
// extras      - anything, maybe key-value pairs?
glTF_Property :: struct {}

glTF_Child_Of_Root_Property :: struct {
	_:    glTF_Property,
	name: union {
		string,
	},
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

// complete
glTF_Accessor_Sparse_Indices :: struct {
	_:             glTF_Property,
	bufferView:    glTF_Id,
	byteOffset:    union {
		int,
	},
	componentType: glTF_Indices_Component_Type,
}

// complete
glTF_Accessor_Sparse_Values :: struct {
	_:          glTF_Property,
	bufferView: glTF_Id,
	byteOffset: union {
		int,
	},
}

// complete
glTF_Accessor_Sparse :: struct {
	_:       glTF_Property,
	count:   int,
	indices: glTF_Accessor_Sparse_Indices,
	values:  glTF_Accessor_Sparse_Values,
}

// complete
glTF_Accessor :: struct {
	_:             glTF_Child_Of_Root_Property,
	bufferView:    union {
		glTF_Id,
	},
	byteOffset:    union {
		int,
	},
	componentType: glTF_Accessor_Component_Type,
	normalized:    union {
		bool,
	},
	count:         int,
	type:          string, // SCALAR, VEC2, VEC3, VEC4, MAT2, MAT3, MAT4
	max:           union {
		[]f64,
	},
	min:           union {
		[]f64,
	},
	sparse:        glTF_Accessor_Sparse,
}

// complete
glTF_Animation_Channel_Target :: struct {
	_:    glTF_Property,
	node: union {
		glTF_Id,
	},
	path: string, // translation, rotation, scale, weights
}

// complete
glTF_Animation_Channel :: struct {
	_:       glTF_Property,
	sampler: glTF_Id,
	target:  glTF_Animation_Channel_Target,
}

// complete
glTF_Animation_Sampler :: struct {
	_:             glTF_Property,
	input:         glTF_Id,
	interpolation: union {
		string, // LINEAR, STEP, CUBICSPLINE
	},
	output:        glTF_Id,
}

// complete
glTF_Animation :: struct {
	_:        glTF_Child_Of_Root_Property,
	channels: []glTF_Animation_Channel,
	samplers: []glTF_Animation_Sampler,
}

// complete
glTF_Asset :: struct {
	_:          glTF_Property,
	copyright:  union {
		string,
	},
	generator:  union {
		string,
	},
	version:    string,
	minVersion: union {
		string,
	},
}

// complete
glTF_Buffer :: struct {
	_:          glTF_Child_Of_Root_Property,
	uri:        union {
		string,
	},
	byteLength: int,
}

glTF_Bind_Buffer :: enum {
	ARRAY_BUFFER         = 34962,
	ELEMENT_ARRAY_BUFFER = 34963,
}

glTF_Buffer_View :: struct {
	_:          glTF_Child_Of_Root_Property,
	buffer:     glTF_Id,
	byteOffset: union {
		int,
	},
	byteLength: int,
	byteStride: union {
		int,
	},
	target:     union {
		glTF_Bind_Buffer,
	},
}

// complete
glTF_Camera_Orthographic :: struct {
	_:     glTF_Property,
	xmag:  f64,
	ymag:  f64,
	zfar:  f64,
	znear: f64,
}

// complete
glTF_Camera_Perspective :: struct {
	_:           glTF_Property,
	aspectRatio: union {
		f64,
	},
	yfov:        f64,
	zfar:        union {
		f64,
	},
	znear:       f64,
}

GLTF_CAMERA_PERSPECTIVE :: "perspective"
GLTF_CAMERA_ORTHOGRAPHIC :: "orthographic"

// complete
glTF_Camera :: struct {
	_:            glTF_Child_Of_Root_Property,
	orthographic: union {
		glTF_Camera_Orthographic,
	},
	perspective:  union {
		glTF_Camera_Perspective,
	},
	type:         string, // perspective, orthographic
}

GLTF_IMAGE_JPEG :: "image/jpeg"
GLTF_IMAGE_PNG :: "image/png"

// complete
glTF_Image :: struct {
	_:          glTF_Child_Of_Root_Property,
	uri:        union {
		string,
	},
	mimeType:   union {
		string, // image/jpeg, image/png
	},
	bufferView: union {
		glTF_Id,
	},
}

// complete
glTF_Texture_Info :: struct {
	_:        glTF_Property,
	index:    glTF_Id,
	texCoord: int, // default: 0
}

// complete
glTF_Material_Pbr_Metallic_Roughness :: struct {
	_:                        glTF_Property,
	baseColorFactor:          union {
		[]f64, // default: [ 1.0, 1.0, 1.0, 1.0 ]
	},
	baseColorTexture:         union {
		glTF_Texture_Info,
	},
	metallicFactor:           f64, // default: 0
	roughnessFactor:          union {
		f64, // default: 1 ???
	},
	metallicRoughnessTexture: union {
		glTF_Texture_Info,
	},
}

// complete
glTF_Material_Normal_Texture_Info :: struct {
	_:     glTF_Texture_Info,
	scale: union {
		f64, // default: 1 ???
	},
}

// complete
glTF_Material_Occlusion_Texture_Info :: struct {
	_:        glTF_Texture_Info,
	strength: union {
		f64, // default: 1 ???
	},
}

GLTF_MATERIAL_ALPHA_MODE_OPAQUE :: "OPAQUE"
GLTF_MATERIAL_ALPHA_MODE_MASK :: "MASK"
GLTF_MATERIAL_ALPHA_MODE_BLEND :: "BLEND"

// complete
glTF_Material :: struct {
	_:                    glTF_Child_Of_Root_Property,
	pbrMetallicRoughness: union {
		glTF_Material_Pbr_Metallic_Roughness,
	},
	normalTexture:        union {
		glTF_Material_Normal_Texture_Info,
	},
	occlusionTexture:     union {
		glTF_Material_Occlusion_Texture_Info,
	},
	emissiveTexture:      union {
		glTF_Texture_Info,
	},
	emissiveFactor:       union {
		[]f64, // default: [ 0.0, 0.0, 0.0 ]
	},
	alphaMode:            union {
		string, // OPAQUE, MASK, BLEND, default: OPAQUE ???
	},
	alphaCutoff:          union {
		f64, // default: 0.5 ???
	},
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

// complete
glTF_Mesh_Primitive :: struct {
	_:          glTF_Property,
	attributes: map[string]int,
	indices:    union {
		glTF_Id,
	},
	material:   union {
		glTF_Id,
	},
	mode:       union {
		glTF_Mesh_Primitive_Type, // default TRIANGLES
	},
	targets:    []map[string]int,
}

// complete
glTF_Mesh :: struct {
	_:          glTF_Child_Of_Root_Property,
	primitives: []glTF_Mesh_Primitive,
	weights:    union {
		[]f64,
	},
}

// complete
glTF_Node :: struct {
	_:                     glTF_Child_Of_Root_Property,
	camera:                union {
		glTF_Id,
	},
	children:              union {
		[]glTF_Id,
	},
	skin:                  union {
		glTF_Id,
	},
	transformation_matrix: union {
		[]f64, // [ 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0 ]
	} `json:"matrix"`,
	mesh:                  union {
		glTF_Id,
	},
	rotation:              union {
		[]f64, // [ 0.0, 0.0, 0.0, 1.0 ]
	},
	scale:                 union {
		[]f64, // [ 1.0, 1.0, 1.0 ]
	},
	translation:           union {
		[]f64, // [ 0.0, 0.0, 0.0 ]
	},
	weights:               union {
		[]f64,
	},
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

// complete
glTF_Sampler :: struct {
	_:         glTF_Child_Of_Root_Property,
	magFilter: union {
		glTF_Magnification_Filter,
	},
	minFilter: union {
		glTF_Minification_Filter,
	},
	wrapS:     union {
		glTF_Texture_Wrapping_Mode, // default: REPEAT
	},
	wrapT:     union {
		glTF_Texture_Wrapping_Mode, // default: REPEAT
	},
}

// complete
glTF_Scene :: struct {
	_:     glTF_Child_Of_Root_Property,
	nodes: union {
		[]glTF_Id,
	},
}

// complete
glTF_Skin :: struct {
	_:                   glTF_Child_Of_Root_Property,
	inverseBindMatrices: union {
		glTF_Id,
	},
	skeleton:            union {
		glTF_Id,
	},
	joints:              []glTF_Id,
}

glTF :: struct {
	_:                  glTF_Property,
	extensionsUsed:     union {
		[]string,
	},
	extensionsRequired: union {
		[]string,
	},
	accessors:          union {
		[]glTF_Accessor,
	},
	animations:         union {
		[]glTF_Animation,
	},
	asset:              glTF_Asset,
	buffers:            union {
		[]glTF_Buffer,
	},
	bufferViews:        union {
		[]glTF_Buffer_View,
	},
	cameras:            union {
		[]glTF_Camera,
	},
	images:             union {
		[]glTF_Image,
	},
	materials:          union {
		[]glTF_Material,
	},
	meshes:             union {
		[]glTF_Mesh,
	},
	nodes:              union {
		[]glTF_Node,
	},
	samplers:           union {
		[]glTF_Sampler,
	},
	scene:              union {
		glTF_Id,
	},
	scenes:             union {
		[]glTF_Scene,
	},
	skins:              union {
		[]glTF_Skin,
	},
	textures:           union {
		[]glTF_Texture_Info,
	},
}
