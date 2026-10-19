class_name World
extends Node3D
## ฉาก Caldra (prototype): พื้นที่ปลอดภัยกลางเมือง + ทุ่งเถ้า + มอนสเตอร์ป่าเกิดใหม่
## Spawner ใช้ spawn_function เพื่อสร้างโหนดจากโค้ด (ไม่ต้องมี .tscn แยก)

const SAFE_RADIUS := 8.0
const MAX_ENEMIES := 8
const WILD_ELEMENTS := [Data.Element.FIRE, Data.Element.EARTH, Data.Element.PLANT, Data.Element.WIND, Data.Element.WATER]

var _players: Node
var _enemies: Node
var _player_spawner: MultiplayerSpawner
var _enemy_spawner: MultiplayerSpawner
var _spawn_t := 2.0

func _ready() -> void:
	Net.world = self
	_build_scenery()
	_players = Node.new(); _players.name = "Players"; add_child(_players)
	_enemies = Node.new(); _enemies.name = "Enemies"; add_child(_enemies)
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

# ---- เรียกบน server เท่านั้น ----
func add_player(peer: int) -> void:
	_player_spawner.spawn({"peer": peer, "pos": Vector3(randf_range(-3, 3), 1.0, randf_range(-3, 3))})

func remove_player(peer: int) -> void:
	var p := _players.get_node_or_null(str(peer))
	if p:
		p.save_now()
		p.queue_free()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server(): return
	_spawn_t -= delta
	if _spawn_t > 0.0: return
	_spawn_t = 4.0
	if get_tree().get_nodes_in_group("enemies").size() >= MAX_ENEMIES: return
	var a := randf() * TAU
	var r := randf_range(16.0, 34.0)
	_enemy_spawner.spawn({"id": randi() % 1000000, "pos": Vector3(cos(a) * r, 1.0, sin(a) * r),
		"el": WILD_ELEMENTS[randi() % WILD_ELEMENTS.size()]})

# ---- ฉาก placeholder (แทนที่ด้วยโมเดล Blender ภายหลัง) ----
func _mat(c: Color, emit := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit:
		m.emission_enabled = true; m.emission = c
	return m

func _build_scenery() -> void:
	var ground := StaticBody3D.new()                       # คอลลิชันพื้น (server ต้องใช้ด้วย)
	var gcol := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(240, 1, 240)
	gcol.shape = box; gcol.position.y = -0.5
	ground.add_child(gcol)
	add_child(ground)
	if DisplayServer.get_name() == "headless": return      # dedicated server ไม่ต้องวาดภาพ
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("3a2420")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffd7b8"); env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0); sun.light_color = Color("ffb780")
	add_child(sun)
	var gm := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(240, 240)
	gm.mesh = plane; gm.material_override = _mat(Color("4b3b36"))
	ground.add_child(gm)
	var town := MeshInstance3D.new()                       # พื้นที่ปลอดภัย (เมือง Caldra)
	var disc := CylinderMesh.new()
	disc.top_radius = SAFE_RADIUS; disc.bottom_radius = SAFE_RADIUS; disc.height = 0.1
	town.mesh = disc; town.position.y = 0.05
	town.material_override = _mat(Color("8a6a4a"))
	add_child(town)
	var rng := RandomNumberGenerator.new(); rng.seed = 7   # seed คงที่: ทุก client เห็นฉากเหมือนกัน
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(14.0, 60.0)
		var lava := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = rng.randf_range(1.5, 4.0); cyl.bottom_radius = cyl.top_radius; cyl.height = 0.05
		lava.mesh = cyl; lava.position = Vector3(cos(a) * r, 0.03, sin(a) * r)
		lava.material_override = _mat(Color("ff5a1f"), true)
		add_child(lava)
	for i in 10:
		var a := rng.randf() * TAU
		var r := rng.randf_range(12.0, 55.0)
		var rock := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0; cone.bottom_radius = rng.randf_range(1.0, 2.5); cone.height = rng.randf_range(2.0, 6.0)
		rock.mesh = cone; rock.position = Vector3(cos(a) * r, cone.height / 2.0, sin(a) * r)
		rock.material_override = _mat(Color("2b2220"))
		add_child(rock)
