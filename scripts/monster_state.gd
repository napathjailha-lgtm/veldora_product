class_name MonsterState
extends RefCounted
## สถานะมอนสเตอร์รายตัว (ตรงกับ MonsterState ในเอกสารหัวข้อ 13.1)
## เก็บที่ server เป็นหลัก ส่งให้ client เป็น Dictionary

var unique_id := ""
var line := "cinder"
var chosen_branch: int = Data.Branch.NONE
var temperament := ""
var bond_level := 0                 # ความผูกพันถาวร (ไม่ใช่ Bond Gauge)
var exp := 0
var unlocked_forms: Array = []      # form id
var current_form := ""
var hp_frac := 1.0                  # เก็บเป็นสัดส่วน กัน HP กระโดดตอนเปลี่ยนร่าง
var ee := 0.0                       # Evolve Energy (รายตัว)
var style_atk := 0.0                # แต้มสไตล์โจมตี/คอมโบ (เงื่อนไขกิ่ง A)
var style_def := 0.0                # แต้มสไตล์รับ/ปกป้อง (เงื่อนไขกิ่ง B)
var is_egg := false
var hatch_at := 0.0                 # unix time (เดินต่อได้ตอนออฟไลน์)
var hatch_locked := false           # ไข่ Pip ของ Kaelen: ไม่ฟักจนกว่าเควสต์ Trust Lv.5
var switch_cd_until := 0.0          # runtime เท่านั้น (ticks วินาที)

static func create(line_id: String, temper: String) -> MonsterState:
	var m := MonsterState.new()
	m.unique_id = "%d_%d" % [Time.get_unix_time_from_system(), randi()]
	m.line = line_id
	m.temperament = temper
	m.current_form = Data.LINES[line_id]["sprout"]
	m.unlocked_forms = [m.current_form]
	return m

# ---------- เลเวล / สเตตัส ----------
static func exp_for_level(l: int) -> int:
	return 30 * (l - 1) * (l - 1)

func level() -> int:
	return 1 + int(sqrt(exp / 30.0))

func element() -> int:
	return Data.LINES[line]["element"]

func stage_of(form_id: String) -> int:
	return Data.FORMS[form_id]["stage"]

func highest_form_id() -> String:
	var best := unlocked_forms[0] as String
	for f in unlocked_forms:
		if stage_of(f) >= stage_of(best):
			best = f
	return best

func highest_stage() -> int:
	return stage_of(highest_form_id())

func stat_mult() -> float:
	return 1.0 + 0.06 * (level() - 1)

func max_hp() -> float:
	return Data.FORMS[highest_form_id()]["hp"] * stat_mult()

func atk() -> float:
	return Data.FORMS[current_form]["atk"] * stat_mult()

# ---------- EXP / วิวัฒนาการ ----------
## คืนข้อความเหตุการณ์ (เช่น ปลดล็อก Bloom) ให้ HUD แสดง
func gain_exp(amount: int) -> Array:
	var events: Array = []
	var total := exp + amount
	while true:                                    # คำนวณแคปใหม่ทุกครั้งที่ปลดล็อกร่างใหม่
		var cap := exp_for_level(Data.MAX_LEVEL_BY_STAGE[highest_stage()])   # MaxLevelByStage
		exp = mini(total, cap)
		if highest_stage() == Data.Stage.SPROUT and level() >= Data.STAGE_UNLOCK_LEVEL[Data.Stage.BLOOM]:
			var id := _find_form(Data.Stage.BLOOM, Data.Branch.NONE)
			if id != "":
				unlocked_forms.append(id)
				events.append("%s ปลดล็อกร่าง %s!" % [Data.FORMS[unlocked_forms[0]]["name"], Data.FORMS[id]["name"]])
				continue
		break
	return events

func _find_form(stage: int, branch: int) -> String:
	for id in Data.FORMS:
		var f: Dictionary = Data.FORMS[id]
		if f["line"] == line and f["stage"] == stage and f["branch"] == branch and f["released"]:
			return id
	return ""

## เลือกกิ่ง Apex (ครั้งเดียวต่อตัว) คืนข้อความ error หรือ "" ถ้าสำเร็จ
func try_choose_branch(branch: int, has_item: bool) -> String:
	if chosen_branch != Data.Branch.NONE: return "เลือกกิ่งไปแล้ว"
	if highest_stage() != Data.Stage.BLOOM: return "ต้องอยู่ที่ Bloom ก่อน"
	if level() < Data.STAGE_UNLOCK_LEVEL[Data.Stage.APEX]: return "เลเวลยังไม่ถึง"
	if bond_level < Data.BRANCH_MIN_BOND: return "Bond Level ยังไม่ถึง 5"
	if not has_item: return "ต้องมีไอเทมกิ่ง"
	if (branch == Data.Branch.A and style_atk < 50.0) or (branch == Data.Branch.B and style_def < 50.0):
		return "สไตล์การต่อสู้ยังไม่เข้ากับกิ่งนี้"
	var id := _find_form(Data.Stage.APEX, branch)
	if id == "": return "กิ่งนี้ยังไม่เปิดใน 1.0 (เร็วๆ นี้)"
	chosen_branch = branch
	unlocked_forms.append(id)
	return ""

## ปลุก Resonance ด้วย Catalyst (เฉพาะสายที่มีร่าง Resonance released)
func try_awaken_resonance(has_catalyst: bool) -> String:
	if highest_stage() != Data.Stage.APEX: return "ต้องอยู่ที่ Apex"
	if level() < Data.MAX_LEVEL_BY_STAGE[Data.Stage.APEX]: return "ต้องถึงเลเวลสูงสุดของ Apex"
	if bond_level < Data.RESONANCE_MIN_BOND: return "Bond Level ยังไม่พอ"
	if not has_catalyst: return "ต้องมี Catalyst"
	var id := _find_form(Data.Stage.RESONANCE, chosen_branch)
	if id == "": return "สายนี้ยังไม่เปิด Resonance ใน 1.0 (ช่องล็อก)"
	unlocked_forms.append(id)
	return ""

# ---------- HP / ไข่ (Soft Death) ----------
## คืน true ถ้าตาย
func take_damage(amount: float) -> bool:
	hp_frac = maxf(0.0, hp_frac - amount / max_hp())
	return hp_frac <= 0.0

func to_egg(now: float) -> void:
	var secs: float = Data.HATCH_SECONDS[highest_stage()] * Data.egg_time_scale
	secs *= 1.0 - minf(bond_level, 10) * 0.02          # Bond สูง ฟักเร็วขึ้น
	is_egg = true
	hp_frac = 0.0
	ee = 0.0
	current_form = Data.LINES[line]["sprout"]
	hatch_at = now + secs

func egg_ready(now: float) -> bool:
	return is_egg and not hatch_locked and now >= hatch_at

func hatch() -> void:
	# ร่างที่ปลดล็อก/กิ่ง/สกิลคงเดิม แต่เสีย EXP (กลับเลเวลขั้นต่ำของร่างสูงสุด) และ Bond = 0
	is_egg = false
	exp = exp_for_level(Data.MIN_LEVEL_BY_STAGE[highest_stage()])
	bond_level = 0
	hp_frac = 1.0

# ---------- เซฟ / ส่งผ่านเน็ต ----------
func to_dict() -> Dictionary:
	return {"id": unique_id, "line": line, "branch": chosen_branch, "temper": temperament,
		"bond": bond_level, "exp": exp, "forms": unlocked_forms, "cur": current_form,
		"hp": hp_frac, "ee": ee, "sa": style_atk, "sd": style_def,
		"egg": is_egg, "hatch_at": hatch_at, "lock": hatch_locked}

static func from_dict(d: Dictionary) -> MonsterState:
	var m := MonsterState.new()
	m.unique_id = d.get("id", ""); m.line = d.get("line", "cinder")
	m.chosen_branch = d.get("branch", 0); m.temperament = d.get("temper", "")
	m.bond_level = d.get("bond", 0); m.exp = d.get("exp", 0)
	m.unlocked_forms = Array(d.get("forms", []))
	m.current_form = d.get("cur", "")
	m.hp_frac = d.get("hp", 1.0); m.ee = d.get("ee", 0.0)
	m.style_atk = d.get("sa", 0.0); m.style_def = d.get("sd", 0.0)
	m.is_egg = d.get("egg", false); m.hatch_at = d.get("hatch_at", 0.0)
	m.hatch_locked = d.get("lock", false)
	return m
