class_name World
extends Node3D
## Caldra 2.5D world: a warm frontier town, forest paths, low-poly trees and wildlings.

const SAFE_RADIUS := 8.0
const MAX_ENEMIES := 8
const WILD_ELEMENTS := [Data.Element.FIRE, Data.Element.EARTH, Data.Element.PLANT, Data.Element.WIND, Data.Element.WATER]
const Visuals = preload("res://scripts/visuals.gd")

var _players: Node
var _enemies: Node
var _player_spawner: MultiplayerSpawner
var _enemy_spawner: MultiplayerSpawner
var _spawn_t := 2.0

func _ready() -> void:
	Net.world = self
	_build_scenery()
	_players = Node.new()
	_players.name = "Players"
	add_child(_players)
	_enemies = Node.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	_player_spawner = _make_spawner("PlayerSpawner", "../Players", _spawn_player)
	_enemy_spawner = _make_spawner("EnemySpawner", "../Enemies", _spawn_enemy)

func _make_spawner(n: String, path: String, fn: Callable) -> MultiplayerSpawner:
	var s := MultiplayerSpawner.new()
	s.name = n
	s.spawn_path = NodePath(path)
	s.spawn_function = fn
	add_child(s)
	return s

func _spawn_player(data: Variant) -> Node:
	var p := Player.new()
	p.name = str(int(data["peer"]))
	p.position = data["pos"]
	return p

func _spawn_enemy(data: Variant) -> Node:
	var e := Enemy.new()
	e.name = "E%d" % int(data["id"])
	e.position = data["pos"]
	e.element = int(data["el"])
	return e

# Server authoritative spawning.
func add_player(peer: int) -> void:
	_player_spawner.spawn({"peer": peer, "pos": Vector3(randf_range(-3, 3), 1.0, randf_range(-3, 3))})

func remove_player(peer: int) -> void:
	var p := _players.get_node_or_null(str(peer))
	if p:
		p.save_now()
		p.queue_free()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_t = 4.0
	if get_tree().get_nodes_in_group("enemies").size() >= MAX_ENEMIES:
		return
	var a := randf() * TAU
	var r := randf_range(18.0, 34.0)
	_enemy_spawner.spawn({"id": randi() % 1000000, "pos": Vector3(cos(a) * r, 1.0, sin(a) * r), "el": WILD_ELEMENTS[randi() % WILD_ELEMENTS.size()]})

func _mat(c: Color, glow: bool = false, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.8
	return m

func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.scale = scale
	parent.add_child(node)
	return node

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, mesh, material, pos)

func _build_scenery() -> void:
	# The collision floor is also present on a headless server.
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(240, 1, 240)
	collision.shape = floor_shape
	collision.position.y = -0.5
	ground.add_child(collision)
	add_child(ground)
	if DisplayServer.get_name() == "headless":
		return

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5d8b9b")
	sky_mat.sky_horizon_color = Color("f3c99a")
	sky_mat.ground_bottom_color = Color("283b32")
	sky_mat.ground_horizon_color = Color("9e9677")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8e6c5")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("b7c5a8")
	env.fog_density = 0.004
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("ffe0ae")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var grass_mat := _mat(Color("526f4b"))
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(240, 240)
	_add_mesh(ground, ground_mesh, grass_mat, Vector3(0, 0.01, 0))

	_build_paths()
	_build_town()
	_build_forest()
	_build_flora()

func _build_paths() -> void:
	var path_mat := _mat(Color("c4ad83"))
	var edge_mat := _mat(Color("8c785b"))
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var path_root := Node3D.new()
		path_root.rotation.y = angle
		path_root.position = Vector3.ZERO
		add_child(path_root)
		_box(path_root, Vector3(4.8, 0.07, 42.0), Vector3(0, 0.06, 24.0), edge_mat)
		_box(path_root, Vector3(4.1, 0.08, 41.5), Vector3(0, 0.105, 24.0), path_mat)
		# Small inset paving stones make the road read clearly from the isometric camera.
		for i in range(1, 10):
			_box(path_root, Vector3(3.7, 0.025, 0.11), Vector3(0, 0.15, 5.0 + i * 4.0), _mat(Color("d8c49a")))

func _build_town() -> void:
	var paving := _mat(Color("9c927c"))
	var paving_edge := _mat(Color("655f54"))
	var town := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 10.2
	disc.bottom_radius = 10.5
	disc.height = 0.16
	disc.radial_segments = 32
	town.mesh = disc
	town.position.y = 0.12
	town.material_override = paving
	add_child(town)

	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 9.9
	rim_mesh.outer_radius = 10.15
	rim.mesh = rim_mesh
	rim.position.y = 0.22
	rim.material_override = paving_edge
	add_child(rim)

	# A glowing crystal fountain marks the safe-zone hub.
	var fountain := Node3D.new()
	fountain.name = "CaldraHeartFountain"
	fountain.position = Vector3(0, 0.2, 0)
	add_child(fountain)
	var basin := CylinderMesh.new()
	basin.top_radius = 1.45
	basin.bottom_radius = 1.6
	basin.height = 0.42
	basin.radial_segments = 12
	_add_mesh(fountain, basin, _mat(Color("6b7776")), Vector3(0, 0.24, 0))
	var water := CylinderMesh.new()
	water.top_radius = 1.18
	water.bottom_radius = 1.18
	water.height = 0.08
	water.radial_segments = 16
	_add_mesh(fountain, water, _mat(Color("4dbed0"), true), Vector3(0, 0.48, 0))
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.75, 1.35, 0.65)
	var crystal_node := _add_mesh(fountain, crystal, _mat(Color("8ce7e2"), true), Vector3(0, 1.12, 0))
	crystal_node.rotation_degrees = Vector3(0, 45, 0)

	# Six compact frontier houses with distinct roof colours and readable doors/windows.
	var roof_colors := [Color("a95f42"), Color("607c8d"), Color("b88b4f"), Color("7c7955"), Color("9b5c59"), Color("557b67")]
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var pos := Vector3(cos(angle) * 6.9, 0.0, sin(angle) * 6.9)
		_add_house(pos, roof_colors[i], angle + PI)

	for i in 8:
		var angle := TAU * float(i) / 8.0 + PI / 8.0
		_add_lamp(Vector3(cos(angle) * 9.0, 0.0, sin(angle) * 9.0))

func _add_house(pos: Vector3, roof_color: Color, facing_angle: float) -> void:
	var house := Node3D.new()
	house.position = pos
	house.rotation.y = facing_angle
	add_child(house)
	var wall := _mat(Color("d8c49b"))
	var trim := _mat(Color("78533c"))
	var roof := _mat(roof_color)
	var dark_window := _mat(Color("31434a"), true)
	_box(house, Vector3(2.35, 1.65, 1.85), Vector3(0, 0.88, 0), wall)
	_box(house, Vector3(2.48, 0.15, 1.98), Vector3(0, 0.16, 0), trim)
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 1.65
	roof_mesh.height = 1.25
	roof_mesh.radial_segments = 4
	var roof_node := _add_mesh(house, roof_mesh, roof, Vector3(0, 2.18, 0))
	roof_node.rotation_degrees.y = 45.0
	_box(house, Vector3(0.48, 0.92, 0.08), Vector3(0, 0.58, 0.96), trim)
	_box(house, Vector3(0.38, 0.42, 0.06), Vector3(-0.69, 1.05, 0.96), dark_window)
	_box(house, Vector3(0.38, 0.42, 0.06), Vector3(0.69, 1.05, 0.96), dark_window)
	_box(house, Vector3(0.12, 0.48, 0.08), Vector3(0, 0.58, 1.015), _mat(Color("d2a36c")))
	var chimney := BoxMesh.new()
	chimney.size = Vector3(0.28, 0.7, 0.28)
	_add_mesh(house, chimney, trim, Vector3(0.72, 2.18, -0.25))

func _add_lamp(pos: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.position = pos
	add_child(lamp)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.09
	pole.height = 1.65
	_add_mesh(lamp, pole, _mat(Color("55463a")), Vector3(0, 0.82, 0))
	var cap := SphereMesh.new()
	cap.radius = 0.2
	cap.height = 0.4
	_add_mesh(lamp, cap, _mat(Color("ffce78"), true), Vector3(0, 1.72, 0))

func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261019
	var trunk_mats := [_mat(Color("594333")), _mat(Color("725039")), _mat(Color("493d32"))]
	var leaf_mats := [_mat(Color("426b49")), _mat(Color("527d50")), _mat(Color("668954")), _mat(Color("3c6047"))]
	var pine_mats := [_mat(Color("315a4c")), _mat(Color("3e6b54")), _mat(Color("547b5c"))]
	var rock_mats := [_mat(Color("777c72")), _mat(Color("8d8b7b")), _mat(Color("625f58"))]
	for i in 92:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(17.0, 82.0)
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		# Keep the town approaches clear so the four paths remain readable.
		if minf(absf(x), absf(z)) < 4.1 and radius < 47.0:
			continue
		_add_tree(Vector3(x, 0.0, z), rng, trunk_mats, leaf_mats, pine_mats)
	for i in 34:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(16.0, 68.0)
		if radius < 40.0 and minf(absf(cos(angle) * radius), absf(sin(angle) * radius)) < 4.2:
			continue
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = rng.randf_range(0.35, 0.9)
		rock_mesh.height = rng.randf_range(0.45, 1.25)
		rock.mesh = rock_mesh
		rock.position = Vector3(cos(angle) * radius, rock_mesh.height * 0.36, sin(angle) * radius)
		rock.scale = Vector3(rng.randf_range(0.8, 1.5), 0.8, rng.randf_range(0.7, 1.3))
		rock.material_override = rock_mats[rng.randi_range(0, rock_mats.size() - 1)]
		add_child(rock)

func _add_tree(pos: Vector3, rng: RandomNumberGenerator, trunks: Array, leaves: Array, pines: Array) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = rng.randf_range(0.0, TAU)
	var size := rng.randf_range(0.78, 1.55)
	tree.scale = Vector3.ONE * size
	add_child(tree)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.28
	trunk.height = rng.randf_range(1.7, 2.5)
	trunk.radial_segments = 7
	_add_mesh(tree, trunk, trunks[rng.randi_range(0, trunks.size() - 1)], Vector3(0, trunk.height * 0.5, 0))
	if rng.randf() < 0.32:
		for tier in 3:
			var crown := CylinderMesh.new()
			crown.top_radius = 0.0
			crown.bottom_radius = 1.15 - float(tier) * 0.22
			crown.height = 1.3
			crown.radial_segments = 7
			_add_mesh(tree, crown, pines[rng.randi_range(0, pines.size() - 1)], Vector3(0, trunk.height * 0.72 + float(tier) * 0.62, 0))
	else:
		var crown := SphereMesh.new()
		crown.radius = 1.0
		crown.height = 1.8
		crown.radial_segments = 8
		crown.rings = 5
		_add_mesh(tree, crown, leaves[rng.randi_range(0, leaves.size() - 1)], Vector3(0, trunk.height + 0.48, 0), Vector3(1.0, 1.12, 0.95))
		_add_mesh(tree, crown, leaves[rng.randi_range(0, leaves.size() - 1)], Vector3(0.52, trunk.height + 0.35, 0.08), Vector3(0.63, 0.72, 0.62))
		_add_mesh(tree, crown, leaves[rng.randi_range(0, leaves.size() - 1)], Vector3(-0.46, trunk.height + 0.28, -0.05), Vector3(0.67, 0.75, 0.68))

func _build_flora() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 731
	var flower_colors := [Color("f4d17b"), Color("d98a9a"), Color("d9e7b0"), Color("b4a4e8")]
	for i in 64:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(11.0, 72.0)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if radius < 42.0 and minf(absf(pos.x), absf(pos.z)) < 3.4:
			continue
		var tuft := Node3D.new()
		tuft.position = pos
		add_child(tuft)
		var stem := CylinderMesh.new()
		stem.top_radius = 0.025
		stem.bottom_radius = 0.035
		stem.height = 0.3
		_add_mesh(tuft, stem, _mat(Color("47734a")), Vector3(0, 0.15, 0))
		var bloom := SphereMesh.new()
		bloom.radius = 0.12
		bloom.height = 0.16
		_add_mesh(tuft, bloom, _mat(flower_colors[rng.randi_range(0, flower_colors.size() - 1)], true), Vector3(0, 0.34, 0))
