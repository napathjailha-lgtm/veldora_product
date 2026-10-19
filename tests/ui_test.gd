extends Node
## รัน: godot --headless --path . res://tests/ui_test.tscn
func _ready() -> void:
	var hud := HUD.new()
	add_child(hud)
	var m1 := MonsterState.create("cinder", "อบอุ่น/อิสระ")
	var m2 := MonsterState.create("wind", "x"); m2.to_egg(Time.get_unix_time_from_system())
	var d := {"team": [m1.to_dict(), m2.to_dict()], "active": 0, "bond_gauge": 40.0, "stamina": 80.0, "combat": true,
		"now": Time.get_unix_time_from_system(), "items": {}, "flags": {}, "box": [], "res_left": 0.0}
	hud.apply_state(d)
	hud.say("ทดสอบข้อความ")
	hud.show_quiz()
	var got := []
	hud.quiz_done.connect(func(l, t): got.append([l, t]))
	var quiz: StarterQuiz = hud._quiz
	for i in Data.QUIZ.size():
		quiz._answer(Data.QUIZ[i]["a"][0])          # ตอบข้อแรกของทุกคำถาม = สายไฟ
	print("ranked: ", quiz._ranked(), " pick=", quiz._pick)
	quiz._confirm()
	print("quiz result: ", got)
	# ลอง round-trip เซฟ + วิวัฒนาการ
	var m := MonsterState.create("cinder", "t")
	m.gain_exp(3000); m.bond_level = 6; m.style_atk = 60.0
	print("bloom unlocked: ", m.unlocked_forms, " lv=", m.level())
	m.exp = MonsterState.exp_for_level(25)
	print("branch err (no item): '", m.try_choose_branch(Data.Branch.A, false), "'")
	print("branch err (ok): '", m.try_choose_branch(Data.Branch.A, true), "' -> ", m.unlocked_forms)
	print("branch B after choosing A: '", m.try_choose_branch(Data.Branch.B, true), "'")
	var back := MonsterState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	print("save roundtrip ok: ", back.unlocked_forms == m.unlocked_forms and back.chosen_branch == m.chosen_branch)
	var wind := MonsterState.create("wind", "x"); wind.gain_exp(999999)
	print("wind line capped at Bloom (apex unreleased): lv=", wind.level(), " err='", wind.try_choose_branch(Data.Branch.A, true), "'")
	print("reactions: ", Data.reaction(Data.Element.FIRE, Data.Element.WATER)["name"], ", ", Data.reaction(Data.Element.PLANT, Data.Element.FIRE)["name"], ", ", Data.reaction(Data.Element.EARTH, Data.Element.WIND)["name"], ", none=", Data.reaction(Data.Element.FIRE, Data.Element.FIRE))
	get_tree().quit()
