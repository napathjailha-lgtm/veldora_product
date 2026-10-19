extends Node2D
## Veldara 2D isometric-style prototype. No 3D nodes or meshes are used in this scene.
## The companion is the combatant; the tamer only moves and issues commands.

const MAP_TEXTURE: Texture2D = preload("res://assets/2d/caldra_map.svg")
const PLAYER_TEXTURE: Texture2D = preload("res://assets/2d/player.svg")
const PET_TEXTURE: Texture2D = preload("res://assets/2d/companion_fire.svg")
const ENEMY_TEXTURE: Texture2D = preload("res://assets/2d/enemy_mushroom.svg")
const NPC_TEXTURE: Texture2D = preload("res://assets/2d/npc.svg")

const PLAYER_SPEED := 210.0
const PET_FOLLOW_SPEED := 7.0
const ENEMY_SPEED := 54.0
const ATTACK_RANGE := 94.0
const MAX_ENEMIES := 7

var player: Sprite2D
var pet: Sprite2D
var pet_label: Label
var hud: CanvasLayer
var status_label: Label
var stats_label: Label
var log_label: Label
var auto_battle := false
var player_hp := 100.0
var player_max_hp := 100.0
var partner_hp := 100.0
var partner_max_hp := 100.0
var exp := 0
var level := 1
var attack_timer := 0.0
var skill_timer := 0.0
var spawn_timer := 4.0
var pet_target: Node2D
var enemies: Array[Node2D] = []
var log_lines: Array[String] = ["ยินดีต้อนรับสู่ Caldra", "คู่หูเป็นผู้ต่อสู้หลักของคุณ"]

func _ready() -> void:
	_build_world()
	_build_player()
	_build_npcs()
	_build_hud()
	_refresh_hud()

func _build_world() -> void:
	var ground := Sprite2D.new()
	ground.name = "CaldraMap"
	ground.texture = MAP_TEXTURE
	ground.centered = true
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.z_index = -100
	add_child(ground)

func _build_player() -> void:
	player = Sprite2D.new()
	player.name = "Tamer"
	player.texture = PLAYER_TEXTURE
	player.position = Vector2(0, 150)
	player.centered = true
	player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.scale = Vector2(1.2, 1.2)
	add_child(player)
	var shadow := _make_shadow(player, Vector2(0, 32), Vector2(23, 8))
	shadow.z_index = -1
	pet = Sprite2D.new()
	pet.name = "Partner_Embit"
	pet.texture = PET_TEXTURE
	pet.position = player.position + Vector2(48, 28)
	pet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pet.scale = Vector2(1.05, 1.05)
	add_child(pet)
	_make_shadow(pet, Vector2(0, 25), Vector2(21, 7))
	pet_label = Label.new()
	pet_label.text = "Embit"
	pet_label.position = Vector2(-25, -52)
	pet_label.add_theme_color_override("font_color", Color("#fff1c8"))
	pet_label.add_theme_color_override("font_shadow_color", Color("#263d2d"))
	pet_label.add_theme_constant_override("shadow_offset_x", 1)
	pet_label.add_theme_constant_override("shadow_offset_y", 2)
	pet.add_child(pet_label)
	var cam := Camera2D.new()
	cam.name = "FollowCamera"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.zoom = Vector2(1.05, 1.05)
	player.add_child(cam)
	cam.position = Vector2.ZERO
	cam.make_current()

func _make_shadow(parent: Node2D, offset: Vector2, size: Vector2) -> Polygon2D:
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-size.x, 0), Vector2(-size.x * 0.5, -size.y),
		Vector2(size.x * 0.5, -size.y), Vector2(size.x, 0),
		Vector2(size.x * 0.5, size.y), Vector2(-size.x * 0.5, size.y)
	])
	shadow.color = Color(0.12, 0.18, 0.12, 0.38)
	shadow.position = offset
	shadow.z_index = -1
	parent.add_child(shadow)
	return shadow

func _build_npcs() -> void:
	_add_npc("Kaelen Vorr", "ช่างตีเหล็ก", Vector2(-178, -142), Color("#d6a45f"))
	_add_npc("Tessa", "ผู้ดูแลไข่", Vector2(182, -142), Color("#9ecf87"))
	_add_npc("Pip", "นักสำรวจ", Vector2(0, 20), Color("#80d6d3"))

func _add_npc(npc_name: String, role: String, pos: Vector2, tint: Color) -> void:
	var root := Node2D.new()
	root.name = npc_name.replace(" ", "")
	root.position = pos
	root.z_index = int(pos.y)
	add_child(root)
	var sprite := Sprite2D.new()
	sprite.texture = NPC_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = tint
	sprite.position = Vector2(0, -5)
	root.add_child(sprite)
	var label := Label.new()
	label.text = npc_name
	label.position = Vector2(-48, -64)
	label.add_theme_color_override("font_color", Color("#fff2c8"))
	label.add_theme_color_override("font_shadow_color", Color("#243a2b"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(label)
	var subtitle := Label.new()
	subtitle.text = role
	subtitle.position = Vector2(-36, -46)
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color("#e4e9ca"))
	root.add_child(subtitle)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "ROStyleHUD"
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#182b2a"), Color("#c8a66b")))
	root.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	var title := Label.new()
	title.text = "VELDARA  •  CALDRA"
	title.add_theme_color_override("font_color", Color("#f6d78e"))
	title.add_theme_font_size_override("font_size", 18)
	stack.add_child(title)
	stats_label = Label.new()
	stats_label.add_theme_color_override("font_color", Color("#edf3db"))
	stack.add_child(stats_label)
	stack.add_child(_make_bar("TAMER HP", Color("#d95656"), "player"))
	stack.add_child(_make_bar("PARTNER HP", Color("#e58b42"), "partner"))
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("#a9e1a0"))
	stack.add_child(status_label)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-250, -92)
	bottom.custom_minimum_size = Vector2(500, 66)
	bottom.add_theme_stylebox_override("panel", _panel_style(Color("#182b2a"), Color("#c8a66b")))
	root.add_child(bottom)
	var hints := VBoxContainer.new()
	bottom.add_child(hints)
	var skills := Label.new()
	skills.text = "  [J] Auto Battle     [K] Partner Skill     [WASD] Move"
	skills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills.add_theme_color_override("font_color", Color("#f6d78e"))
	hints.add_child(skills)
	log_label = Label.new()
	log_label.text = "\n".join(log_lines)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.add_theme_color_override("font_color", Color("#eaf0d5"))
	hints.add_child(log_label)

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_bar(label_text: String, color: Color, kind: String) -> Control:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#d6dcca"))
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.name = kind + "_bar"
	bar.custom_minimum_size = Vector2(265, 12)
	bar.max_value = 100.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#3b4640")
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)
	return box

func _process(delta: float) -> void:
	_handle_player_input(delta)
	_update_partner(delta)
	_update_enemies(delta)
	_update_combat(delta)
	_update_spawns(delta)
	_refresh_hud()
	player.z_index = int(player.position.y)
	pet.z_index = int(pet.position.y) + 1

func _handle_player_input(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left"))
	input_dir.y = float(Input.is_action_pressed("move_down")) - float(Input.is_action_pressed("move_up"))
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()
	player.position += input_dir * PLAYER_SPEED * delta
	player.position.x = clampf(player.position.x, -700.0, 700.0)
	player.position.y = clampf(player.position.y, -500.0, 500.0)
	if input_dir.x < -0.1:
		player.flip_h = true
	elif input_dir.x > 0.1:
		player.flip_h = false
	if Input.is_action_just_pressed("strike"):
		auto_battle = not auto_battle
		if auto_battle:
			pet_target = _nearest_enemy(420.0)
			_say("คู่หูเริ่มต่อสู้อัตโนมัติ" if pet_target else "ไม่มีมอนสเตอร์ใกล้ตัว")
		else:
			pet_target = null
			_say("คู่หูกลับมาติดตามคุณ")
	if Input.is_action_just_pressed("skill"):
		_use_partner_skill()

func _update_partner(delta: float) -> void:
	var follow := player.position + Vector2(43 if not player.flip_h else -43, 26)
	if auto_battle and is_instance_valid(pet_target) and pet_target.get("dead") != true:
		var direction := pet_target.position - pet.position
		if direction.length() > ATTACK_RANGE * 0.65:
			follow = pet.position + direction.normalized() * minf(ENEMY_SPEED * 2.0 * delta, direction.length())
			pet.flip_h = direction.x < 0.0
		else:
			follow = pet.position
	else:
		if not is_instance_valid(pet_target):
			pet_target = null
		pet.position = pet.position.lerp(follow, 1.0 - exp(-PET_FOLLOW_SPEED * delta))
	pet.position.x = clampf(pet.position.x, -740.0, 740.0)
	pet.position.y = clampf(pet.position.y, -520.0, 520.0)

func _update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			enemies.erase(enemy)
			continue
		if enemy.get("dead") == true:
			continue
		var dist: float = enemy.position.distance_to(player.position)
		if dist < 260.0 and dist > 84.0:
			var direction := (player.position - enemy.position).normalized()
			enemy.position += direction * ENEMY_SPEED * delta
			enemy.z_index = int(enemy.position.y)
		if dist < 72.0:
			enemy.set_meta("contact_time", float(enemy.get_meta("contact_time", 0.0)) + delta)
			if float(enemy.get_meta("contact_time")) >= 1.7:
				enemy.set_meta("contact_time", 0.0)
				player_hp = maxf(0.0, player_hp - 4.0)
				_say("มอนสเตอร์โจมตีผู้ฝึก!")
		else:
			enemy.set_meta("contact_time", 0.0)

func _update_combat(delta: float) -> void:
	attack_timer = maxf(0.0, attack_timer - delta)
	skill_timer = maxf(0.0, skill_timer - delta)
	if not auto_battle:
		return
	if not is_instance_valid(pet_target) or pet_target.get("dead") == true:
		pet_target = _nearest_enemy(460.0)
		if not is_instance_valid(pet_target):
			return
	if pet.position.distance_to(pet_target.position) <= ATTACK_RANGE and attack_timer <= 0.0:
		attack_timer = 1.0
		_damage_enemy(pet_target, 10.0, false)

func _use_partner_skill() -> void:
	if skill_timer > 0.0:
		_say("สกิลคู่หูยังคูลดาวน์อยู่")
		return
	var target := pet_target if is_instance_valid(pet_target) and pet_target.get("dead") != true else _nearest_enemy(220.0)
	if not is_instance_valid(target):
		_say("ไม่มีเป้าหมายในระยะสกิล")
		return
	skill_timer = 3.0
	pet_target = target
	var fx := Polygon2D.new()
	fx.polygon = PackedVector2Array([Vector2(0,-42), Vector2(35,-12), Vector2(24,28), Vector2(-24,28), Vector2(-35,-12)])
	fx.color = Color(1.0, 0.55, 0.2, 0.78)
	fx.position = target.position
	fx.z_index = 5000
	add_child(fx)
	var tw := create_tween()
	tw.tween_property(fx, "scale", Vector2(1.7, 1.7), 0.18)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.35)
	tw.tween_callback(fx.queue_free)
	_damage_enemy(target, 28.0, true)

func _damage_enemy(target: Node2D, damage: float, skill: bool) -> void:
	if not is_instance_valid(target) or target.get("dead") == true:
		return
	var hp: float = float(target.get_meta("hp", 40.0)) - damage
	target.set_meta("hp", hp)
	var bar: ProgressBar = target.get_node_or_null("HPBar")
	if bar:
		bar.value = maxf(0.0, hp) / 40.0 * 100.0
	if skill:
		_say("Embit ใช้ Ember Burst! -%d" % int(damage))
	if hp <= 0.0:
		target.set("dead", true)
		exp += 20
		if exp >= level * 60:
			exp -= level * 60
			level += 1
			_say("เลเวลอัป! Tamer Lv.%d" % level)
		else:
			_say("มอนสเตอร์ถูกคู่หูจัดการ +20 EXP")
		var tw := create_tween()
		tw.tween_property(target, "modulate:a", 0.0, 0.25)
		tw.tween_callback(target.queue_free)
		if pet_target == target:
			pet_target = null

func _nearest_enemy(max_distance: float) -> Node2D:
	var best: Node2D
	var best_dist := max_distance
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("dead") == true:
			continue
		var d := pet.position.distance_to(enemy.position)
		if d < best_dist:
			best = enemy
			best_dist = d
	return best

func _update_spawns(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	spawn_timer = 5.0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.get("dead") != true and enemy.position.distance_to(player.position) < 360.0:
			return
	if enemies.size() < MAX_ENEMIES:
		var angle := randf() * TAU
		var radius := randf_range(260.0, 390.0)
		_spawn_enemy(player.position + Vector2(cos(angle), sin(angle)) * radius)

func _spawn_enemy(pos: Vector2) -> void:
	var enemy := Node2D.new()
	enemy.name = "WildMushroom_%d" % randi()
	enemy.position = Vector2(clampf(pos.x, -720.0, 720.0), clampf(pos.y, -510.0, 510.0))
	enemy.set_meta("hp", 40.0)
	enemy.set_meta("contact_time", 0.0)
	enemy.set("dead", false)
	var sprite := Sprite2D.new()
	sprite.texture = ENEMY_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(1.05, 1.05)
	enemy.add_child(sprite)
	var label := Label.new()
	label.text = "Ashling"
	label.position = Vector2(-27, -58)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#fff0cb"))
	label.add_theme_color_override("font_shadow_color", Color("#273b2d"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	enemy.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "HPBar"
	bar.position = Vector2(-22, -42)
	bar.custom_minimum_size = Vector2(44, 5)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#d85650")
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#353e34")
	bar.add_theme_stylebox_override("background", bg)
	enemy.add_child(bar)
	enemy.z_index = int(enemy.position.y)
	add_child(enemy)
	enemies.append(enemy)

func _refresh_hud() -> void:
	if not is_instance_valid(stats_label):
		return
	stats_label.text = "Tamer Lv.%d  •  EXP %d/%d" % [level, exp, level * 60]
	var player_bar: ProgressBar = hud.get_node_or_null("Control/PanelContainer/VBoxContainer/VBoxContainer/PlayerBar")
	var partner_bar: ProgressBar = hud.get_node_or_null("Control/PanelContainer/VBoxContainer/VBoxContainer2/PartnerBar")
	# Update bars by their stable names to avoid brittle layout assumptions.
	for bar in hud.find_children("*", "ProgressBar", true, false):
		if bar.name == "player_bar":
			bar.value = player_hp / player_max_hp * 100.0
		elif bar.name == "partner_bar":
			bar.value = partner_hp / partner_max_hp * 100.0
	status_label.text = "⚔ AUTO BATTLE" if auto_battle else "✦ EXPLORE"
	status_label.add_theme_color_override("font_color", Color("#f5bd75") if auto_battle else Color("#a9e1a0"))
	log_label.text = "\n".join(log_lines.slice(maxi(0, log_lines.size() - 2), log_lines.size()))

func _say(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 8:
		log_lines.pop_front()
