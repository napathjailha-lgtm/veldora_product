class_name Player
extends CharacterBody3D

const Visuals = preload("res://scripts/visuals.gd")
## Tamer 1 คน = 1 โหนด (ชื่อโหนด = peer id)
## - client เจ้าของคุมการเดิน (sync ตำแหน่งผ่าน SyncMove)
## - server คุม Party/ต่อสู้/ไข่ (sync ร่างปัจจุบันผ่าน SyncState) แล้วส่ง snapshot ให้เจ้าของทุก 0.25 วิ

const SPEED := 6.0
const ACTIONS := {
	"form_next": ["form_next", 0], "form_sprout": ["form_sprout", 0], "bond_res": ["bond_res", 0],
	"slot1": ["slot", 0], "slot2": ["slot", 1], "slot3": ["slot", 2], "slot4": ["slot", 3],
	"branch_a": ["branch", 1], "branch_b": ["branch", 2], "awaken": ["awaken", 0],
	"cheat_exp": ["cheat", "exp"], "cheat_bond": ["cheat", "bond"],
	"cheat_items": ["cheat", "items"], "cheat_kill": ["cheat", "kill"],
}

var peer_id := 0
var party := Party.new()          # ค่าจริงอยู่บน server เท่านั้น
var snap := {}                    # snapshot ฝั่ง client
var form_id := ""                 # replicate จาก server
var facing := Vector3(0, 0, 1)
var hud: HUD = null
var logged_in := false
var _profile := ""
var _tamer: Node3D
var _pet: Node3D
var _pet_label: Label3D
var _last_form := "?"
var _prev_pos := Vector3.ZERO
var _cd := {"strike": 0.0, "skill": 0.0}
var combat_target_id := "" # Server-selected target, replicated to clients.
var auto_battle := false
var _auto_attack_t := 0.0
var _sync_t := 0.0
var _save_t := 0.0

func _is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()

func _ready() -> void:
	peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	add_to_group("players")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.7
	col.shape = cap; col.position.y = 0.85
	add_child(col)
	_tamer = Visuals.make_tamer()
	_tamer.position.y = 0.0
	add_child(_tamer)
	_pet = Visuals.make_monster(Data.Element.FIRE, 0)
	_pet.position = Vector3(0, 0.7, 0)
	add_child(_pet)
	_pet_label = Label3D.new()
	_pet_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pet_label.pixel_size = 0.005
	_pet_label.font_size = 30
	_pet_label.position.y = 1.48
	_pet.add_child(_pet_label)
	var tag := Label3D.new()
	tag.text = "P%d" % peer_id; tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.006; tag.position.y = 2.1
	add_child(tag)
	_add_sync("SyncMove", [":position"], peer_id)      # เจ้าของส่งตำแหน่ง
	_add_sync("SyncState", [":form_id", ":combat_target_id"], 1)            # server ส่งร่างปัจจุบัน
	_prev_pos = position
	if _is_local():
		var cam := Camera3D.new()
		cam.position = Vector3(0, 10, 8); cam.rotation_degrees = Vector3(-52, 0, 0)
		add_child(cam)
		cam.make_current()
		if DisplayServer.get_name() != "headless":
			hud = HUD.new()
			add_child(hud)
			hud.quiz_done.connect(_on_quiz_done)
		_to_server("req_action", ["login", Net.profile_id])

func _make_sprite(color: Color, px: float, y: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Data.blob(color); s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position.y = y
	add_child(s)
	return s

func _add_sync(node_name: String, props: Array, authority: int) -> void:
	var s := MultiplayerSynchronizer.new()
	s.name = node_name
	s.root_path = NodePath("..")
	var cfg := SceneReplicationConfig.new()
	for p in props:
		cfg.add_property(NodePath(p))
	s.replication_config = cfg
	s.set_multiplayer_authority(authority)
	add_child(s)

# ---------------- ส่งข้อความ client <-> server (ใช้ได้ทั้ง host และ client ล้วน) ----------------
func _to_server(method: String, args: Array) -> void:
	if multiplayer.is_server():
		callv(method, args)
	else:
		callv("rpc_id", [1, method] + args)

func _to_owner(method: String, args: Array) -> void:
	if peer_id == 1:
		callv(method, args)
	else:
		callv("rpc_id", [peer_id, method] + args)

# ---------------- ลูปหลัก ----------------
func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var v := Vector2.ZERO
		if not (hud and hud.quiz_open):
			v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity.x = v.x * SPEED
		velocity.z = v.y * SPEED
		if not is_on_floor(): velocity.y -= 20.0 * delta
		move_and_slide()
	if multiplayer.is_server():
		_server_tick(delta)

func _process(delta: float) -> void:
	var d := global_position - _prev_pos
	d.y = 0.0
	if d.length() > 0.01: facing = d.normalized()
	_prev_pos = global_position
	if form_id != _last_form: _refresh_pet()
	if _pet.visible:
		var follow_target := -facing * 1.3 + Vector3(0, 0.7 * (0.9 + 0.1 * sin(Time.get_ticks_msec() / 250.0)), 0)
		var target_node := _find_enemy_by_id(combat_target_id)
		if target_node and not target_node.dead and not (hud and hud.quiz_open):
			# The partner moves into the fight; the human stays back and never deals damage.
			var toward := target_node.global_position - global_position
			toward.y = 0.0
			var side := Vector3(-toward.z, 0, toward.x).normalized() * 0.85
			var desired_global := target_node.global_position + side + Vector3(0, 0.55, 0)
			follow_target = to_local(desired_global)
			if toward.length() > 0.1:
				_pet.look_at(target_node.global_position, Vector3.UP)
		_pet.position = _pet.position.lerp(follow_target, 1.0 - exp(-6.0 * delta))

func _find_enemy_by_id(id: String) -> Enemy:
	if id == "": return null
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and node.name == id:
			return node
	return null

func _refresh_pet() -> void:
	_last_form = form_id
	if not Data.FORMS.has(form_id):
		_pet.visible = false
		return
	var f: Dictionary = Data.FORMS[form_id]
	var element := int(Data.LINES[f["line"]]["element"])
	var old_pos := _pet.position
	remove_child(_pet)
	_pet.queue_free()
	_pet = Visuals.make_monster(element, int(f["stage"]))
	_pet.position = old_pos
	add_child(_pet)
	_pet_label = Label3D.new()
	_pet_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pet_label.pixel_size = 0.005
	_pet_label.font_size = 30
	_pet_label.position.y = 1.48 + 0.18 * float(f["stage"])
	_pet_label.text = str(f["name"])
	_pet.add_child(_pet_label)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_local() or (hud and hud.quiz_open): return
	for a in ["strike", "skill"]:
		if event.is_action_pressed(a):
			if a == "strike":
				_to_server("req_action", ["command_attack", null])
			else:
				_to_server("req_action", [a, facing])
			return
	for a in ACTIONS:
		if event.is_action_pressed(a):
			_to_server("req_action", ACTIONS[a].duplicate())
			return

func _on_quiz_done(line: String, temper: String) -> void:
	_to_server("req_action", ["starter", {"line": line, "temper": temper}])

# ---------------- ฝั่ง server ----------------
func _server_tick(delta: float) -> void:
	party.in_safe_zone = Vector2(global_position.x, global_position.z).length() < World.SAFE_RADIUS
	party.tick(delta)
	var m := party.active_monster()
	form_id = m.current_form if m else ""
	if not logged_in: return
	_auto_battle_tick(delta)
	_sync_t += delta
	if _sync_t >= 0.25 or not party.log.is_empty():
		_sync_t = 0.0
		_push_state()
	_save_t += delta
	if _save_t >= 30.0:
		_save_t = 0.0
		save_now()

func _push_state() -> void:
	_to_owner("client_state", [party.to_dict(), party.log.duplicate()])
	party.log.clear()

func save_now() -> void:
	if logged_in: Net.save_profile(_profile, party.to_dict())

func server_hit(amount: float) -> void:        # เรียกโดย Enemy บน server
	party.on_damage_taken(amount)

@rpc("any_peer", "call_remote", "reliable")
func req_action(kind: String, arg: Variant) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0: sender = 1                  # เรียกจาก host เอง
	if sender != peer_id: return
	if kind == "login":
		_login(str(arg)); return
	if not logged_in: return
	var err := ""
	var m := party.active_monster()
	match kind:
		"command_attack":
			auto_battle = not auto_battle
			if auto_battle:
				_select_nearest_target()
				party.say("คู่หูเริ่มต่อสู้อัตโนมัติ" if combat_target_id != "" else "ไม่มีเป้าหมายใกล้ตัว")
			else:
				combat_target_id = ""
				party.say("คู่หูหยุดต่อสู้และกลับมาติดตาม")
		"skill": _attack(kind, arg)
		"form_next": err = _cycle_form()
		"form_sprout":
			if m: err = party.request_switch(Data.LINES[m.line]["sprout"])
		"bond_res": err = party.activate_bond_resonance()
		"slot": err = party.select_active(int(arg))
		"starter": err = _pick_starter(arg)
		"branch":
			if m:
				var item := "ember_whetstone" if int(arg) == Data.Branch.A else "forge_core"
				err = m.try_choose_branch(int(arg), party.items[item] > 0)
				if err == "":
					party.items[item] -= 1
					party.say("เลือกกิ่ง Apex แล้ว: %s" % Data.FORMS[m.highest_form_id()]["name"])
		"awaken":
			if m:
				err = m.try_awaken_resonance(party.items["ultimate_catalyst"] > 0)
				if err == "":
					party.items["ultimate_catalyst"] -= 1
					party.say("ปลุก Resonance แล้ว: %s" % Data.FORMS[m.highest_form_id()]["name"])
		"cheat": if Net.debug_cheats: _cheat(str(arg))
	if err != "": party.say(err)
	if logged_in: _push_state()

func _login(pid: String) -> void:
	if logged_in: return
	_profile = Net.sanitize(pid)
	if _profile == "": _profile = "guest_%d" % peer_id
	var data := Net.load_profile(_profile)
	if not data.is_empty(): party.load_dict(data)
	logged_in = true
	_push_state()

func _pick_starter(arg: Variant) -> String:
	if not party.monsters.is_empty(): return "มีมอนสเตอร์อยู่แล้ว"
	if typeof(arg) != TYPE_DICTIONARY or not Data.LINES.has(str(arg.get("line", ""))): return "ตัวเลือกไม่ถูกต้อง"
	var line := str(arg["line"])
	party.add_monster(MonsterState.create(line, str(arg.get("temper", "")).substr(0, 40)))
	if not party.has_line("cinder"):     # ข้อเสนอ (รอยืนยัน): เควสต์แรกใน Caldra แจก Embit ให้ทุกคน
		party.add_monster(MonsterState.create("cinder", Data.TEMPER_ADJ["cinder"]))
		party.say("เควสต์แรกใน Caldra: ได้รับ Embit ไว้ใช้ในเควสต์ Pyrrhael")
	party.say("พิธีไข่สำเร็จ! ไข่ฟักแล้ว")
	return ""

func _cycle_form() -> String:
	var m := party.active_monster()
	if m == null: return "ไม่มีมอนสเตอร์ที่ใช้งานได้"
	var forms := m.unlocked_forms.filter(func(f): return m.stage_of(f) != Data.Stage.SPROUT)
	if forms.is_empty(): return "ยังไม่มีร่างให้เปลี่ยน"
	forms.sort_custom(func(a, b): return m.stage_of(a) < m.stage_of(b))
	return party.request_switch(forms[(forms.find(m.current_form) + 1) % forms.size()])

func _select_nearest_target() -> void:
	var best: Enemy = null
	var best_d := 12.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Enemy: continue
		var enemy := node as Enemy
		if enemy.dead: continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_d:
			best = enemy
			best_d = d
	combat_target_id = best.name if best else ""

func _auto_battle_tick(delta: float) -> void:
	if party.in_safe_zone:
		auto_battle = false
		combat_target_id = ""
		return
	if not auto_battle: return
	var target := _find_enemy_by_id(combat_target_id)
	if target == null or target.dead:
		_select_nearest_target()
		target = _find_enemy_by_id(combat_target_id)
	if target == null: return
	_auto_attack_t -= delta
	if global_position.distance_to(target.global_position) <= 3.1 and _auto_attack_t <= 0.0:
		var mon := party.active_monster()
		if mon == null: return
		_auto_attack_t = 1.15
		var result: Dictionary = target.take_hit(mon.atk(), -1)
		party.enter_combat()
		mon.style_atk += 1.0
		if result["killed"]:
			party.award_exp(target.exp_reward)
			_select_nearest_target()

func _attack(kind: String, _dir_v: Variant) -> void:
	if party.in_safe_zone: return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _cd[kind]: return
	var mon := party.active_monster()
	if mon == null:
		party.say("ไม่มีคู่หูที่พร้อมต่อสู้")
		return
	var target := _find_enemy_by_id(combat_target_id)
	if target == null or target.dead:
		_select_nearest_target()
		target = _find_enemy_by_id(combat_target_id)
	if target == null:
		party.say("เลือกเป้าหมายก่อน: กด J เพื่อสั่งคู่หูโจมตี")
		return
	if global_position.distance_to(target.global_position) > 8.0:
		party.say("เป้าหมายอยู่ไกลเกินไป")
		return
	_cd[kind] = now + 0.9
	var result: Dictionary = target.take_hit(mon.atk() * 1.2, mon.element())
	party.on_skill_hit(result["reaction"])
	if not result["reaction"].is_empty():
		party.say("คู่หูใช้สกิล! ปฏิกิริยา %s!" % result["reaction"]["name"])
	else:
		party.say("%s ใช้สกิลโจมตี!" % Data.FORMS.get(mon.current_form, {}).get("name", "คู่หู"))
	if result["killed"]:
		party.award_exp(target.exp_reward)
		_select_nearest_target()
	fx_attack.rpc("skill", (target.global_position - global_position).normalized(), mon.element())

func _cheat(what: String) -> void:
	match what:
		"exp":
			for mon in party.monsters:
				for e in mon.gain_exp(600): party.say(e)
		"bond":
			for mon in party.monsters: mon.bond_level = mini(mon.bond_level + 2, 10)
			party.bond_gauge = Data.BOND_GAUGE_MAX
			party.say("[debug] Bond +2, Bond Gauge เต็ม")
		"items":
			for k in party.items: party.items[k] += 1
			for mon in party.monsters: mon.style_atk += 60.0; mon.style_def += 60.0
			party.say("[debug] ได้ไอเทมกิ่ง/Catalyst + แต้มสไตล์")
		"kill": party.on_damage_taken(99999.0)

@rpc("any_peer", "call_local", "unreliable")
func fx_attack(kind: String, dir: Vector3, el: int) -> void:
	var s := multiplayer.get_remote_sender_id()
	if (s != 0 and s != 1) or DisplayServer.get_name() == "headless": return
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new(); sph.radius = 0.35 if kind == "strike" else 0.6; sph.height = sph.radius * 2.0
	mi.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Data.ELEMENT_COLOR.get(el, Color.WHITE)
	mat.emission_enabled = true; mat.emission = mat.albedo_color
	mi.material_override = mat
	get_parent().add_child(mi)
	mi.global_position = _pet.global_position + Vector3(0, 0.7, 0) + dir * 0.9
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 2.2, 0.25)
	tw.tween_callback(mi.queue_free)

# ---------------- ฝั่ง client (เจ้าของ) ----------------
@rpc("any_peer", "call_remote", "reliable")
func client_state(d: Dictionary, logs: Array) -> void:
	var s := multiplayer.get_remote_sender_id()
	if s != 0 and s != 1: return
	snap = d
	if hud == null: return
	hud.apply_state(d)
	for l in logs: hud.say(str(l))
	if d["team"].is_empty() and not hud.quiz_open: hud.show_quiz()
