class_name StarterQuiz
extends PanelContainer
## พิธีไข่: ตอบคำถามสถานการณ์ -> คะแนนซ่อน -> เห็น % ความเข้ากันของทั้ง 5 ตัว -> เปลี่ยนใจได้ก่อนยืนยัน
## เสมอคะแนน: ให้ข้อสุดท้ายตัดสิน | Temperament มาจากคำตอบ (ตัวที่เลือก + ตัวที่เข้ากันรองลงมา)

signal chosen(line: String, temper: String)

const NAMES := {"cinder": "ไฟ", "tide": "น้ำ", "wind": "ลม", "plant": "พฤกษา", "earth": "ดิน"}

var _i := 0
var _scores := {}
var _last := {}
var _box: VBoxContainer
var _pick := ""

func _ready() -> void:
	custom_minimum_size = Vector2(560, 320)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_box = VBoxContainer.new()
	add_child(_box)
	_next()

func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()

func _next() -> void:
	_clear()
	if _i >= Data.QUIZ.size():
		_result()
		return
	var q: Dictionary = Data.QUIZ[_i]
	var title := Label.new()
	title.text = "พิธีไข่ (%d/%d)\n%s" % [_i + 1, Data.QUIZ.size(), q["q"]]
	_box.add_child(title)
	for a in q["a"]:
		var b := Button.new()
		b.text = a["t"]
		b.pressed.connect(_answer.bind(a))
		_box.add_child(b)

func _answer(a: Dictionary) -> void:
	for line in a["s"]:
		_scores[line] = _scores.get(line, 0.0) + float(a["s"][line])
		if _i == Data.QUIZ.size() - 1:
			_last[line] = float(a["s"][line])
	_i += 1
	_next()

func _score(line: String) -> float:
	return _scores.get(line, 0.0) + _last.get(line, 0.0) * 0.01   # ข้อสุดท้ายตัดสินเมื่อเสมอ

func _ranked() -> Array:
	var r: Array = Data.LINES.keys()
	r.sort_custom(func(a, b): return _score(a) > _score(b))
	return r

func _result() -> void:
	var ranked := _ranked()
	_pick = ranked[0]
	var title := Label.new()
	title.text = "ไข่ที่ตอบรับคุณ — กดดู Preview ทั้ง 5 ตัวได้ ก่อนยืนยัน"
	_box.add_child(title)
	var group := ButtonGroup.new()
	for line in ranked:
		var sprout: Dictionary = Data.FORMS[Data.LINES[line]["sprout"]]
		var pct := minf(100.0, 100.0 * _scores.get(line, 0.0) / (2.0 * Data.QUIZ.size()))
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = (line == _pick)
		b.text = "%s — %s (%s)  เข้ากัน %d%%  | นิสัย: %s" % [NAMES[line], sprout["name"], sprout["role"], int(pct), Data.TEMPER_ADJ[line]]
		b.pressed.connect(func(): _pick = line)
		_box.add_child(b)
	var ok := Button.new()
	ok.text = "ยืนยัน"
	ok.pressed.connect(_confirm)
	_box.add_child(ok)

func _confirm() -> void:
	var temper: String = Data.TEMPER_ADJ[_pick]
	for other in _ranked():                      # นิสัยรอง = ตัวที่เข้ากันรองลงมา -> ตัวแรกของแต่ละคนไม่เหมือนกัน
		if other != _pick and _scores.get(other, 0.0) > 0.0:
			temper += "/" + Data.TEMPER_ADJ[other]
			break
	chosen.emit(_pick, temper)
