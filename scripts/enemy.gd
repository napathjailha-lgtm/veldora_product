class_name Enemy
extends CharacterBody3D
## มอนสเตอร์ป่า Caldra (AI รันบน server, client แค่รับตำแหน่ง/HP/ออร่า)

var element: int = Data.Element.FIRE
var hp := 80.0
var max_hp := 80.0
var aura := -1                     # ธาตุที่ติดตัวอยู่ รอปฏิกิริยา
var exp_reward := 40
var dead := false
var _aura_t := 0.0
var _atk_cd := 1.5
var _sprite: Sprite3D
var _bar: Label3D

func _ready() -> void:
	add_to_group("enemies")
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new(); sh.radius = 0.5
	col.shape = sh; col.position.y = 0.5
	add_child(col)
	_sprite = Sprite3D.new()
	_sprite.texture = Data.blob(Data.ELEMENT_COLOR.get(element, Color.GRAY))
	_sprite.pixel_size = 0.02
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.position.y = 0.7
	add_child(_sprite)
	_bar = Label3D.new()
	_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar.position.y = 1.7; _bar.font_size = 36; _bar.pixel_size = 0.005
	add_child(_bar)
	var sync := MultiplayerSynchronizer.new()
	sync.root_path = NodePath("..")
	var cfg := SceneReplicationConfig.new()
	for p in [":position", ":hp", ":aura"]:
		cfg.add_property(NodePath(p))
	sync.replication_config = cfg
	add_child(sync)

func _process(_d: float) -> void:
	var aura_name: String = "" if aura < 0 else " [%s]" % Data.Element.keys()[aura]
	_bar.text = "%d/%d%s" % [maxi(0, int(hp)), int(max_hp), aura_name]
	_sprite.modulate = Color.WHITE if aura < 0 else Color.WHITE.lerp(Data.ELEMENT_COLOR.get(aura, Color.WHITE), 0.6)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or dead: return
	if not is_on_floor(): velocity.y -= 20.0 * delta
	_aura_t -= delta
	if _aura_t <= 0.0: aura = -1
	_atk_cd -= delta
	var target: Player = _nearest_player()
	if target:
		var to := target.global_position - global_position; to.y = 0.0
		if to.length() > 1.6:
			var dir := to.normalized()
			velocity.x = dir.x * 2.8; velocity.z = dir.z * 2.8
		else:
			velocity.x = 0.0; velocity.z = 0.0
			if _atk_cd <= 0.0:
				_atk_cd = 1.5
				target.server_hit(7.0)
	else:
		velocity.x = 0.0; velocity.z = 0.0
	move_and_slide()

func _nearest_player() -> Player:
	var best: Player = null
	var best_d := 14.0
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.party.in_safe_zone or p.party.active_monster() == null: continue
		var d: float = p.global_position.distance_to(global_position)
		if d < best_d: best_d = d; best = p
	return best

## server เรียก คืน {"reaction": Dictionary, "killed": bool}
func take_hit(amount: float, el: int) -> Dictionary:
	var r := Data.reaction(aura, el)
	var dmg := amount
	if not r.is_empty():
		dmg *= r["mult"]
		aura = -1
		if r["aoe"] > 0.0:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e != self and not e.dead and e.global_position.distance_to(global_position) <= r["aoe"]:
					e._apply(dmg * 0.5, "")
	elif el >= 0:
		aura = el; _aura_t = 8.0
	var killed := _apply(dmg, r.get("name", ""))
	return {"reaction": r, "killed": killed}

func _apply(dmg: float, label: String) -> bool:
	hp -= dmg
	fx_hit.rpc(dmg, label)
	if hp <= 0.0 and not dead:
		dead = true
		remove_from_group("enemies")
		get_tree().create_timer(0.4).timeout.connect(queue_free)   # รอให้ RPC ถึงก่อนลบ
	return dead

@rpc("authority", "call_local", "reliable")
func fx_hit(dmg: float, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var t := Label3D.new()
	t.text = ("%s " % label if label != "" else "") + str(int(dmg))
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	t.modulate = Color("ffe066") if label != "" else Color.WHITE
	t.font_size = 48; t.pixel_size = 0.008; t.no_depth_test = true
	get_parent().add_child(t)                 # อยู่ต่อได้แม้ศัตรูถูกลบ
	t.global_position = global_position + Vector3(0, 2.0, 0)
	var tw := t.create_tween()
	tw.tween_property(t, "global_position:y", t.global_position.y + 1.2, 0.7)
	tw.tween_callback(t.queue_free)
