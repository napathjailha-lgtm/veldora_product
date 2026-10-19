extends RefCounted
## Procedural low-poly art kit for Caldra. Uses built-in meshes only; no external assets required.

static func _material(color: Color, roughness: float = 0.88, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.65
	return mat

static func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scale: Vector3 = Vector3.ONE, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color, 0.88, glow)
	node.position = pos
	node.scale = scale
	parent.add_child(node)
	return node

static func _sphere(parent: Node3D, color: Color, pos: Vector3, scale: Vector3, glow: bool = false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 6
	return _part(parent, mesh, color, pos, scale, glow)

static func _box(parent: Node3D, color: Color, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, mesh, color, pos)

static func _cone(parent: Node3D, color: Color, pos: Vector3, height: float, radius: float, segments: int = 7) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return _part(parent, mesh, color, pos)

static func make_tamer() -> Node3D:
	var root := Node3D.new()
	root.name = "TamerModel"
	# Boots and legs
	_box(root, Color("273449"), Vector3(-0.17, 0.19, 0.0), Vector3(0.19, 0.34, 0.25))
	_box(root, Color("273449"), Vector3(0.17, 0.19, 0.0), Vector3(0.19, 0.34, 0.25))
	_box(root, Color("40516a"), Vector3(-0.17, 0.43, 0.0), Vector3(0.16, 0.28, 0.16))
	_box(root, Color("40516a"), Vector3(0.17, 0.43, 0.0), Vector3(0.16, 0.28, 0.16))
	# Jacket, shoulders and arms
	_box(root, Color("287d85"), Vector3(0.0, 0.88, 0.0), Vector3(0.58, 0.58, 0.32))
	_sphere(root, Color("3a9da0"), Vector3(-0.34, 0.98, 0.0), Vector3(0.18, 0.22, 0.19))
	_sphere(root, Color("3a9da0"), Vector3(0.34, 0.98, 0.0), Vector3(0.18, 0.22, 0.19))
	_box(root, Color("d7a86b"), Vector3(-0.38, 0.72, 0.01), Vector3(0.14, 0.36, 0.15))
	_box(root, Color("d7a86b"), Vector3(0.38, 0.72, 0.01), Vector3(0.14, 0.36, 0.15))
	_box(root, Color("f0c979"), Vector3(0.0, 0.57, 0.18), Vector3(0.42, 0.09, 0.06))
	# Backpack and scarf
	_box(root, Color("8e583c"), Vector3(0.0, 0.86, 0.21), Vector3(0.31, 0.38, 0.17))
	_box(root, Color("f4a84f"), Vector3(0.0, 1.13, -0.01), Vector3(0.48, 0.11, 0.36))
	_box(root, Color("f4a84f"), Vector3(0.2, 1.06, 0.17), Vector3(0.13, 0.28, 0.08))
	# Head, hair and face
	_sphere(root, Color("e8b58b"), Vector3(0.0, 1.39, 0.0), Vector3(0.29, 0.31, 0.27))
	_sphere(root, Color("4c302c"), Vector3(0.0, 1.56, -0.035), Vector3(0.3, 0.19, 0.28))
	_sphere(root, Color("4c302c"), Vector3(-0.2, 1.43, 0.02), Vector3(0.1, 0.19, 0.22))
	_sphere(root, Color("30272b"), Vector3(-0.105, 1.4, 0.235), Vector3(0.035, 0.045, 0.025))
	_sphere(root, Color("30272b"), Vector3(0.105, 1.4, 0.235), Vector3(0.035, 0.045, 0.025))
	_sphere(root, Color("f7d66f"), Vector3(0.0, 1.17, 0.21), Vector3(0.09, 0.09, 0.055), true)
	return root

static func make_monster(element: int, stage: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "WildlingModel"
	var base: Color = Data.ELEMENT_COLOR.get(element, Color("9a8a78"))
	var dark := base.darkened(0.38)
	var light := base.lightened(0.32)
	var belly := Color("f3e4c7")
	# Silhouette and details differ by elemental family.
	match element:
		Data.Element.FIRE:
			_sphere(root, dark, Vector3(0.0, 0.48, 0.0), Vector3(0.49, 0.42, 0.4))
			_sphere(root, base, Vector3(0.0, 0.69, 0.0), Vector3(0.42, 0.39, 0.37))
			_cone(root, light, Vector3(-0.23, 1.05, -0.02), 0.42, 0.2)
			_cone(root, light, Vector3(0.23, 1.05, -0.02), 0.42, 0.2)
			_sphere(root, Color("ffd66b"), Vector3(0.0, 0.49, 0.34), Vector3(0.22, 0.19, 0.07), true)
			_cone(root, Color("ffb84d"), Vector3(0.0, 1.17, -0.04), 0.38, 0.19, 6)
		Data.Element.WATER:
			_sphere(root, base, Vector3(0.0, 0.58, 0.0), Vector3(0.43, 0.55, 0.39))
			_sphere(root, light, Vector3(0.0, 0.88, -0.03), Vector3(0.29, 0.28, 0.28))
			_sphere(root, Color("b9f2ff"), Vector3(-0.33, 0.78, -0.03), Vector3(0.15, 0.23, 0.14))
			_sphere(root, Color("b9f2ff"), Vector3(0.33, 0.78, -0.03), Vector3(0.15, 0.23, 0.14))
			_sphere(root, belly, Vector3(0.0, 0.45, 0.34), Vector3(0.24, 0.27, 0.08))
		Data.Element.WIND:
			_sphere(root, base, Vector3(0.0, 0.58, 0.0), Vector3(0.4, 0.42, 0.35))
			_sphere(root, light, Vector3(0.0, 0.85, 0.0), Vector3(0.32, 0.31, 0.3))
			_cone(root, light, Vector3(-0.32, 0.95, -0.02), 0.48, 0.15)
			_cone(root, light, Vector3(0.32, 0.95, -0.02), 0.48, 0.15)
			_sphere(root, Color("d9fff0"), Vector3(-0.39, 0.48, -0.02), Vector3(0.21, 0.09, 0.13))
			_sphere(root, Color("d9fff0"), Vector3(0.39, 0.48, -0.02), Vector3(0.21, 0.09, 0.13))
		Data.Element.PLANT:
			_sphere(root, dark, Vector3(0.0, 0.48, 0.0), Vector3(0.45, 0.4, 0.38))
			_sphere(root, base, Vector3(0.0, 0.69, 0.0), Vector3(0.39, 0.37, 0.34))
			_sphere(root, Color("8c573d"), Vector3(0.0, 0.4, 0.32), Vector3(0.22, 0.22, 0.08))
			_sphere(root, light, Vector3(-0.34, 0.83, 0.0), Vector3(0.23, 0.12, 0.13))
			_sphere(root, light, Vector3(0.34, 0.83, 0.0), Vector3(0.23, 0.12, 0.13))
			_cone(root, Color("8fe16b"), Vector3(0.0, 1.08, 0.0), 0.42, 0.13)
		Data.Element.EARTH:
			_box(root, dark, Vector3(0.0, 0.49, 0.0), Vector3(0.76, 0.72, 0.65))
			_box(root, base, Vector3(0.0, 0.73, 0.0), Vector3(0.63, 0.58, 0.58))
			_sphere(root, light, Vector3(-0.23, 0.99, 0.0), Vector3(0.17, 0.18, 0.16))
			_sphere(root, light, Vector3(0.23, 0.99, 0.0), Vector3(0.17, 0.18, 0.16))
			_sphere(root, Color("ffd37a"), Vector3(0.0, 0.62, 0.31), Vector3(0.16, 0.17, 0.06), true)
		_:
			_sphere(root, dark, Vector3(0.0, 0.48, 0.0), Vector3(0.45, 0.4, 0.38))
			_sphere(root, base, Vector3(0.0, 0.7, 0.0), Vector3(0.4, 0.38, 0.35))
			_cone(root, light, Vector3(-0.24, 1.02, 0.0), 0.34, 0.16)
			_cone(root, light, Vector3(0.24, 1.02, 0.0), 0.34, 0.16)
	# Shared face, paws and a clear silhouette at the prototype camera distance.
	_sphere(root, Color("fff5d7"), Vector3(-0.13, 0.75, 0.315), Vector3(0.075, 0.095, 0.045))
	_sphere(root, Color("fff5d7"), Vector3(0.13, 0.75, 0.315), Vector3(0.075, 0.095, 0.045))
	_sphere(root, Color("20242b"), Vector3(-0.13, 0.75, 0.356), Vector3(0.035, 0.055, 0.02))
	_sphere(root, Color("20242b"), Vector3(0.13, 0.75, 0.356), Vector3(0.035, 0.055, 0.02))
	for x in [-0.25, 0.25]:
		_sphere(root, dark, Vector3(x, 0.16, 0.05), Vector3(0.16, 0.14, 0.18))
	root.scale = Vector3.ONE * (1.0 + 0.18 * float(stage))
	return root
