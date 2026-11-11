# SJRPG 식생 출처

사용자 소유 프로젝트의 자체 제작 형상과 생성형 재질입니다. 외부 모델 다운로드가 아닙니다. 줄기·잎의 두 표면과 원본 LOD를 보존하고 alpha-scissor로 잎 사이 실제 빈틈을 표시합니다. 기존 소품의 단일 표면·3200삼각형 계약과 구분하여 식생은 최대4358삼각형·두 표면으로 제한합니다. 120m 셀·최대12개 묶음, 나무 표시240m(정글190m)·관목100m, 그림자는 생략합니다.

## assets/art/preview3d/town-trees.json

```json
{
  "generator": "tools/preview3d/prepare_trees.py",
  "generator_sha256": "31676f9ea3c855c17df9cd71d1afb91d4ae04d182e597dce5bede946a0bebe39",
  "geometry_license": "Original geometry authored for this project under the repository license; no external model downloaded",
  "source_material_provenance": "assets/source/preview3d/trees/generation.json",
  "camera": {
    "projection": "orthographic",
    "azimuth_deg": 45,
    "elevation_deg": 35.2643896828,
    "ground_axes_deg": [
      -30,
      30
    ]
  },
  "variants": [
    {
      "path": "assets/art/preview3d/town-oak-0.glb",
      "sha256": "762e1a1ae051dd66a05ac88cfa78586bba86b9bddda65dfcd88714f57113ead4",
      "bytes": 188064,
      "branches": 62,
      "leaf_sprays": 311,
      "triangles": 4358,
      "vertices": 4047,
      "leaf_material": "LeafSprays",
      "native_root": [
        0,
        0,
        0
      ],
      "native_up": "+Y",
      "crown_kind": "staggered asymmetric broadleaf tiers with real branches, curved alpha-card sprays in varying fixed 3D orientations",
      "billboard": false
    },
    {
      "path": "assets/art/preview3d/town-oak-1.glb",
      "sha256": "163faf1cdb15c0fee6d6e81be9ffa12f06e0796ac24f08e0b1da86ea8f2663e4",
      "bytes": 187812,
      "branches": 62,
      "leaf_sprays": 311,
      "triangles": 4358,
      "vertices": 4047,
      "leaf_material": "LeafSprays",
      "native_root": [
        0,
        0,
        0
      ],
      "native_up": "+Y",
      "crown_kind": "staggered asymmetric broadleaf tiers with real branches, curved alpha-card sprays in varying fixed 3D orientations",
      "billboard": false
    }
  ],
  "limitations": [
    "Alpha-cutout leaf sprays have finite surface thickness and require double-sided alpha-scissor material in Godot; they are not camera-facing billboards",
    "Generated bark/leaf albedo supplies surface variation; no claim of PBR scan",
    "Runtime portrait/landscape, two-axis orbit and shadow appearance remain to be inspected in Godot/browser by root"
  ],
  "packaging": {
    "embedded_images": false,
    "export_image_format": "NONE",
    "export_texcoords": true,
    "material_binding": "Ortho3DTrees assigns shared bark.webp and tree-leaves.webp by preserved Bark/LeafSprays material names; both primitives retain TEXCOORD_0"
  }
}

```

## assets/source/preview3d/trees/generation.json

```json
{
  "prompt": "Create ONE production foliage texture for a native 3D tree in Guardians of Nature. The attached USER GAME REFERENCE is the authoritative restrained realistic forest fantasy style; the attached existing TREE FAMILY REFERENCE fixes muted olive/sage deciduous leaf colour and fine leaf texture. This is a MATERIAL ALPHA CARD, not a whole tree or scene. Show one naturally asymmetric, gently spreading twig spray carrying 24\u201345 individually readable small broad oval oak/hornbeam-like leaves, a few branch forks, clustered in separated groups with irregular transparent holes; no dense solid disk. Leaves have readable veins, slight natural bends and low-contrast surface detail, with subtle cool green shadow and a few restrained yellow-green tips. Neutral even diffuse illumination, no directional sunlight painted in, no black interior shadow plate, no background, no ground or cast shadow. Keep the twig mostly hidden behind leaves. The spray fills about 80 percent of a square canvas with transparent padding on all sides; leaf silhouettes and genuine transparent gaps remain clean and crisp with no white/black halo. Three-dimensional realism when placed on small branch planes under actual lighting, no cartoon, no low-poly depiction, no excessive saturated lime, no autumn red, no flowers, no fruit, no text, no UI. Flat frontal view of the twig spray, appropriate reusable albedo without scene perspective. ONE coherent isolated spray, not a sheet of many assets. TRANSPARENT BACKGROUND.",
  "tool": "image_gen.imagegen",
  "transparent_background": true,
  "references": [
    {
      "path": "assets/source/style/approved-game-reference.jpg",
      "sha256": "c81286d93319f3aa34c2e60ff16ad7347585be4e5a9d0e7a03866451dd4bf40a"
    },
    {
      "path": "assets/source/remake/trees-v2.png",
      "sha256": "8b906334b11c7051b7ede2788b8ee1a459d9ed44db2f4c9dcfed292236e47927"
    }
  ],
  "generated_original": "/workspace/generated_images/exec-9ae17bec-67d1-485f-b318-b0dcf1a17078.png",
  "preserved_source": {
    "path": "assets/source/preview3d/trees/leaves-generated.png",
    "sha256": "3b20c751f90d2c4669d8d8b20da7210952057307028c6c50cece85ab444bcca7"
  },
  "runtime_leaf": {
    "path": "assets/art/preview3d/tree-leaves.webp",
    "sha256": "7368d8e4b3123fb2b2efb4778ad1843bd5d4409a438fb60874b1cc47017dbdbb",
    "operation": "RGBA downsample only, WebP quality 92; no repaint/colour transform",
    "size": [
      1024,
      1024
    ]
  },
  "bark": {
    "source": "assets/source/preview3d/village-materials.png",
    "provenance": "assets/art/preview3d/materials.json",
    "operation": "Use the same generated bark material as the native village family; no independent bark repaint",
    "path": "assets/art/preview3d/bark.webp",
    "sha256": "ca8532c220bb6dcb78a2b14a8dc4a78439885e0ee4f061ff92dee58007af7736"
  }
}

```

## assets/source/preview3d/wild-vegetation/meshes.json

```json
{
	"billboards": false,
	"generator": "scripts/native_wild_vegetation.gd",
	"generator_sha256": "5483f5004af0620e83f2ded934f82677cc1fc19292b7b7c589a8007cb2a58ca1",
	"original_geometry": true,
	"variants": [
		{
			"authoring": {
				"billboard": false,
				"branches": 49,
				"kind": 0,
				"root": "(0.0, 0.0, 0.0)",
				"sprays": 193
			},
			"bounds": "[P: (-2.403, 0.0, -2.157965), S: (4.792865, 5.88, 4.305486)]",
			"path": "assets/art/preview3d/dark-fir.res",
			"sha256": "565af6dc0056759f26875746c70d1864786405779ee3d990d9f131d9d077d7ba",
			"surfaces": 2,
			"triangles": 3320
		},
		{
			"authoring": {
				"billboard": false,
				"branches": 49,
				"kind": 1,
				"root": "(0.0, 0.0, 0.0)",
				"sprays": 193
			},
			"bounds": "[P: (-2.54325, 0.0, -2.283348), S: (5.072723, 5.04, 4.556665)]",
			"path": "assets/art/preview3d/black-pine.res",
			"sha256": "1d8213c43c6cfc617c28f6bb775b2cdef601eb9deba9177aadd14206e27a0831",
			"surfaces": 2,
			"triangles": 3320
		},
		{
			"authoring": {
				"billboard": false,
				"branches": 41,
				"kind": 2,
				"root": "(0.0, 0.0, 0.0)",
				"sprays": 161
			},
			"bounds": "[P: (-1.417215, 0.0, -1.497983), S: (3.000137, 6.51, 3.069256)]",
			"path": "assets/art/preview3d/spire-cypress.res",
			"sha256": "7590ff60d402ad992163fb4b492cdd6e3ad6e6fd9faa329f0ef3ea8694b8758a",
			"surfaces": 2,
			"triangles": 2776
		},
		{
			"authoring": {
				"billboard": false,
				"branches": 19,
				"kind": 3,
				"root": "(0.0, 0.0, 0.0)",
				"sprays": 73
			},
			"bounds": "[P: (-1.000501, 0.0, -0.879353), S: (1.994284, 0.9975, 1.768913)]",
			"path": "assets/art/preview3d/juniper.res",
			"sha256": "24de665bbc5057c6734ef02663fff991bc8a2c687c36b7ba8a5dea5978fad080",
			"surfaces": 2,
			"triangles": 1280
		},
		{
			"authoring": {
				"billboard": false,
				"branches": 91,
				"kind": 4,
				"root": "(0.0, 0.0, 0.0)",
				"sprays": 37
			},
			"bounds": "[P: (-0.829138, 0.0, -0.750796), S: (1.686421, 0.9975, 1.49039)]",
			"path": "assets/art/preview3d/thorn-bramble.res",
			"sha256": "90f5212076ed5e634ef47a82c201af105d449c0800b74dc84237ee2498480bc7",
			"surfaces": 2,
			"triangles": 2432
		}
	]
}

```

## assets/source/preview3d/wild-vegetation/needles.json

```json
{
  "제작": "고정된 3D 곡면 가지에 쓰는 바늘잎. 카메라 빌보드가 아니다. 원본 수식에서 생성한 프로젝트 소유 알베도이며 법선/거칠기 맵이 아니다.",
  "reference": "assets/source/style/approved-game-reference.jpg",
  "reference_sha256": "c81286d93319f3aa34c2e60ff16ad7347585be4e5a9d0e7a03866451dd4bf40a",
  "seed": 76451,
  "generator": "tools/preview3d/make_needles.py",
  "generator_sha256": "801cf67201c3f1ac7a95da2f92ac6f812fae1c669be7909c10b7108e407286c8",
  "source": "assets/source/preview3d/wild-vegetation/needles.png",
  "source_sha256": "313980c749beeccaa32bd5e4c1c98cae4e75bc75aeca4d18fb2f87d6d6f33f27",
  "runtime": "assets/art/preview3d/needle-sprays.webp",
  "sha256": "fb8b7f2603dacd040fa9d2261c80baaef456b04bd7f14f85adfc8fcc15157db5",
  "size": [
    512,
    512
  ]
}

```
