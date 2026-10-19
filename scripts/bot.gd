extends Node
## บอททดสอบ: รันด้วย --bot เพื่อเช็กว่าระบบออนไลน์ทำงานครบ (ไม่ใช้ตอนเล่นจริง)
## server ต้องเปิดด้วย: -- --server --egg-scale=0.005

var p: Player

func _ready() -> void:
	_run()

func _find_player() -> Player:
	var w := get_parent().get_node_or_null("World")
	if w == null: return null
	return w.get_node_or_null("Players/%d" % multiplayer.get_unique_id()) as Player

func _act(kind: String, arg: Variant = null) -> void:
	p._to_server("req_action", [kind, arg])

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _team() -> Array:
	return p.snap.get("team", [])

func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	for e in get_parent().get_node("World/Enemies").get_children():
		if e is Enemy and not e.dead and (best == null or e.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)):
			best = e
	return best

func _run() -> void:
	await _wait(2.0)
	p = _find_player()
	print("[bot] 1 player node: ", p != null)
	_act("starter", {"line": "wind", "temper": "bot"})
	await _wait(0.6)
	print("[bot] 2 team size (wind + free Embit): ", _team().size())
	for i in 6: _act("cheat", "exp")
	_act("cheat", "bond"); _act("cheat", "items")
	await _wait(0.8)
	print("[bot] 3 unlocked forms: ", _team().map(func(m): return m["forms"]))
	_act("slot", 1)                                  # Embit
	while _nearest_enemy() == null: await _wait(0.5) # รอมอนสเตอร์ป่าเกิด
	var e := _nearest_enemy()
	p.global_position = e.global_position + Vector3(2.5, 0, 0)
	await _wait(0.5)
	var dir := (e.global_position - p.global_position).normalized()
	for i in 3:
		_act("skill", dir); await _wait(1.0)
	print("[bot] 4 after fire skill x3: enemy hp=%d aura=%d  embit EE=%.0f" % [e.hp, e.aura, _team()[1]["ee"]])
	_act("form_next")                                # Bloom: ต้องใช้ EE 20
	await _wait(0.5)
	print("[bot] 5 in combat switch -> ", _team()[1]["cur"], " EE=%.0f" % _team()[1]["ee"])
	_act("form_sprout")
	_act("form_next")                                # ติดคูลดาวน์ ต้องถูกปฏิเสธ
	await _wait(0.4)
	print("[bot] 6 re-switch during cooldown (expect embit): ", _team()[1]["cur"])
	_act("slot", 0)                                  # ลม + ไฟที่ติดอยู่ = Swirl
	e = _nearest_enemy()
	dir = (e.global_position - p.global_position).normalized()
	_act("skill", dir)
	await _wait(0.6)
	print("[bot] 7 after wind skill (Swirl clears aura): aura=", e.aura if is_instance_valid(e) else "dead")
	_act("slot", 1)
	_act("cheat", "kill")
	await _wait(1.0)
	print("[bot] 8 egg after death: ", _team()[1]["egg"])
	await _wait(8.0)
	var m: Dictionary = _team()[1]
	print("[bot] 9 hatched: egg=%s bond=%d exp=%d (Bloom unlocked -> min exp %d)" % [m["egg"], m["bond"], m["exp"], MonsterState.exp_for_level(10)])
	get_tree().quit()
