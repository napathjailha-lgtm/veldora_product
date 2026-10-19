class_name HUD
extends CanvasLayer
## HUD ฝั่ง client: ทีม 4 ช่อง (HP/EE/ไข่), Bond Gauge, Stamina, ข้อความ, แบบทดสอบพิธีไข่

signal quiz_done(line: String, temper: String)

var quiz_open := false
var _slots: Array = []
var _bond: ProgressBar
var _stam: ProgressBar
var _status: Label
var _log: Label
var _log_lines: Array = []
var _quiz: Control

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var team := VBoxContainer.new()
	team.position = Vector2(12, 12)
	root.add_child(team)
	for i in 4:
		var l := Label.new()
		var hp := _bar(Color("e5484d"), 190)
		var ee := _bar(Color("4aa3ff"), 190)
		team.add_child(l); team.add_child(hp); team.add_child(ee)
		_slots.append({"label": l, "hp": hp, "ee": ee})
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-170, -110)
	root.add_child(bottom)
	_status = Label.new()
	_bond = _bar(Color("c58bff"), 340)
	_stam = _bar(Color("6fd64f"), 340)
	bottom.add_child(_status); bottom.add_child(_bond); bottom.add_child(_stam)
	_log = Label.new(); _log.position = Vector2(12, 330)
	root.add_child(_log)
	var help := Label.new()
	help.text = "WASD เดิน | J ฟัน | K สกิลมอน | 1-4 เลือกตัว | Q ร่างถัดไป | E กลับ Sprout\nR Bond Resonance | B/N เลือกกิ่ง | M ปลุก Resonance\nDebug: F1 EXP  F2 Bond  F3 ไอเทม  F4 ฆ่าตัวที่ใช้ (ทดสอบไข่)"
	help.position = Vector2(12, 640)
	help.modulate = Color(1, 1, 1, 0.75)
	root.add_child(help)

func _bar(color: Color, w: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, 9)
	b.show_percentage = false
	b.max_value = 100.0
	var sb := StyleBoxFlat.new(); sb.bg_color = color
	b.add_theme_stylebox_override("fill", sb)
	return b

func apply_state(d: Dictionary) -> void:
	var team: Array = d["team"]
	for i in 4:
		var s: Dictionary = _slots[i]
		if i >= team.size():
			s["label"].text = "%d. — ว่าง —" % (i + 1)
			s["hp"].value = 0.0; s["ee"].value = 0.0
			continue
		var m: Dictionary = team[i]
		var f: Dictionary = Data.FORMS[m["cur"]]
		var mark := ">" if i == int(d["active"]) else " "
		if m["egg"]:
			var left := maxf(0.0, float(m["hatch_at"]) - float(d["now"]))
			s["label"].text = "%s%d. [ไข่] ฟักใน %02d:%02d" % [mark, i + 1, int(left) / 60, int(left) % 60]
			s["hp"].value = 0.0; s["ee"].value = 0.0
		else:
			var lv := 1 + int(sqrt(float(m["exp"]) / 30.0))
			s["label"].text = "%s%d. %s Lv.%d Bond %d (%s)" % [mark, i + 1, f["name"], lv, m["bond"], m["temper"]]
			s["hp"].value = float(m["hp"]) * 100.0
			s["ee"].value = float(m["ee"])
	_bond.value = float(d["bond_gauge"])
	_stam.value = float(d["stamina"])
	_status.text = "%s | Bond Gauge / Stamina" % ("⚔ ต่อสู้" if d["combat"] else "สำรวจ")

func say(s: String) -> void:
	_log_lines.append(s)
	if _log_lines.size() > 7: _log_lines.pop_front()
	_log.text = "\n".join(_log_lines)

func show_quiz() -> void:
	quiz_open = true
	_quiz = StarterQuiz.new()
	_quiz.chosen.connect(_on_chosen)
	add_child(_quiz)

func _on_chosen(line: String, temper: String) -> void:
	quiz_open = false
	_quiz.queue_free()
	quiz_done.emit(line, temper)
