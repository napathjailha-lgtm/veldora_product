class_name Party
extends RefCounted
## ตรรกะทีม 4 ตัว + เปลี่ยนร่าง (EE / Bond Gauge / Cooldown) + ไข่ Soft Death
## รันบน server เท่านั้น (authoritative) แล้วส่งผลให้ client ผ่าน Player.sync_to_owner()

const TEAM_SIZE := 4
const COMBAT_TIMEOUT := 6.0
const COMBO_WINDOW := 2.0

var monsters: Array = []            # MonsterState (ทีม สูงสุด 4)
var box: Array = []                 # ที่ฐานพักพิง
var active := 0
var bond_gauge := 0.0               # ของ Tamer ทั้งทีม รีเซ็ตทุกครั้งที่จบสู้
var bond_resonance_left := 0.0
var stamina := 100.0                # ใช้ตอนเปลี่ยนร่างนอกการต่อสู้
var in_combat := false
var combat_timer := 0.0
var in_safe_zone := false
var items := {"ember_whetstone": 0, "forge_core": 0, "ultimate_catalyst": 0}
var story_flags := {}               # Trust ผู้พิทักษ์ ทางเลือก Anchor/Harmony ฯลฯ
var log: Array = []                 # ข้อความรอส่งให้ HUD
var _last_tamer_hit := -99.0
var _last_skill_hit := -99.0

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func say(s: String) -> void:
	log.append(s)

func active_monster() -> MonsterState:
	if active >= 0 and active < monsters.size() and not monsters[active].is_egg:
		return monsters[active]
	return null

func add_monster(m: MonsterState) -> void:
	if monsters.size() < TEAM_SIZE: monsters.append(m)
	else: box.append(m)

func has_line(line: String) -> bool:
	for m in monsters + box:
		if m.line == line: return true
	return false

# ---------------- เปลี่ยนร่าง ----------------
## คืน "" ถ้าสำเร็จ หรือข้อความ error
func request_switch(to_form: String) -> String:
	var m := active_monster()
	if m == null: return "ไม่มีมอนสเตอร์ที่ใช้งานได้"
	if not Data.FORMS.has(to_form) or not (to_form in m.unlocked_forms): return "ยังไม่ได้ปลดล็อกร่างนี้"
	if to_form == m.current_form: return ""
	var st := m.stage_of(to_form)
	if st == Data.Stage.SPROUT:
		_revert(m, true)
		return ""
	if in_safe_zone: return "พื้นที่ปลอดภัยใช้ได้แค่ร่าง Sprout"
	if st == Data.Stage.RESONANCE and m.bond_level < Data.RESONANCE_MIN_BOND:
		return "Bond Level ไม่พอสำหรับ Resonance"
	var wait := m.switch_cd_until - _now()
	if wait > 0.0: return "คูลดาวน์อีก %.1f วิ" % wait
	if in_combat:
		var cost: float = Data.EE_COST[st]
		if m.ee < cost: return "EE ไม่พอ (ต้องใช้ %d)" % int(cost)
		m.ee -= cost
	elif stamina < 10.0:
		return "Stamina ไม่พอ"
	m.current_form = to_form
	return ""

## Bond Gauge เต็ม -> เข้า Resonance ฟรีช่วงสั้น ไม่ติด Cooldown ตอนเข้า
func activate_bond_resonance() -> String:
	var m := active_monster()
	if m == null: return "ไม่มีมอนสเตอร์ที่ใช้งานได้"
	if bond_gauge < Data.BOND_GAUGE_MAX: return "Bond Gauge ยังไม่เต็ม"
	if m.bond_level < Data.RESONANCE_MIN_BOND: return "Bond Level ไม่พอสำหรับ Resonance"
	for f in m.unlocked_forms:
		if m.stage_of(f) == Data.Stage.RESONANCE:
			m.current_form = f
			bond_gauge = 0.0
			bond_resonance_left = Data.BOND_RESONANCE_SECONDS
			return ""
	return "ยังไม่ได้ปลุกร่าง Resonance"

func _revert(m: MonsterState, manual: bool) -> void:
	var st := m.stage_of(m.current_form)
	m.current_form = Data.LINES[m.line]["sprout"]
	if st == Data.Stage.SPROUT: return
	var cd: float = Data.SWITCH_COOLDOWN[st]
	m.switch_cd_until = _now() + (cd * Data.EARLY_RETURN_CD_MULT if manual else cd)
	bond_resonance_left = 0.0

func select_active(i: int) -> String:
	if i < 0 or i >= monsters.size(): return "ไม่มีช่องนี้"
	if monsters[i].is_egg: return "ตัวนี้ยังเป็นไข่อยู่"
	var cur := active_monster()
	if cur: _revert(cur, true)
	active = i
	return ""

# ---------------- เหตุการณ์ในการต่อสู้ ----------------
func enter_combat() -> void:
	in_combat = true
	combat_timer = COMBAT_TIMEOUT

func on_tamer_hit() -> void:
	enter_combat()
	_last_tamer_hit = _now()
	if _now() - _last_skill_hit < COMBO_WINDOW: _charge_bond(12.0)   # คอมโบร่วมกับ Tamer

func on_skill_hit(reaction: Dictionary) -> void:
	var m := active_monster()
	if m == null: return
	enter_combat()
	_last_skill_hit = _now()
	m.ee = minf(Data.EE_MAX, m.ee + (6.0 + (12.0 if not reaction.is_empty() else 0.0)))
	m.style_atk += 1.0
	if not reaction.is_empty(): _charge_bond(8.0)
	if _now() - _last_tamer_hit < COMBO_WINDOW: _charge_bond(12.0)

func on_damage_taken(amount: float) -> void:
	var m := active_monster()
	if m == null: return
	enter_combat()
	m.ee = minf(Data.EE_MAX, m.ee + 4.0)
	m.style_def += amount * 0.1
	if m.take_damage(amount):
		_faint(m)

func _charge_bond(v: float) -> void:
	bond_gauge = minf(Data.BOND_GAUGE_MAX, bond_gauge + v)

func _faint(m: MonsterState) -> void:
	m.to_egg(Time.get_unix_time_from_system())
	say("%s กลายเป็นไข่..." % Data.FORMS[Data.LINES[m.line]["sprout"]]["name"])
	bond_resonance_left = 0.0
	for i in monsters.size():                   # สลับไปตัวถัดไปที่ยังไม่เป็นไข่
		if not monsters[i].is_egg:
			active = i
			return

func award_exp(amount: int) -> void:
	for m in monsters:
		if not m.is_egg:
			for e in m.gain_exp(amount): say(e)

# ---------------- ทุกเฟรมฝั่ง server ----------------
func tick(delta: float) -> void:
	var m := active_monster()
	if m != null and m.stage_of(m.current_form) != Data.Stage.SPROUT:
		var st := m.stage_of(m.current_form)
		if in_safe_zone:
			_revert(m, false); say("กลับร่าง Sprout อัตโนมัติ (พื้นที่ปลอดภัย)")
		elif bond_resonance_left > 0.0:
			bond_resonance_left -= delta
			if bond_resonance_left <= 0.0: _revert(m, false); say("Resonance สิ้นสุด")
		elif in_combat:
			m.ee -= Data.EE_DRAIN_PER_SEC[st] * delta
			if m.ee <= 0.0: m.ee = 0.0; _revert(m, false); say("EE หมด กลับร่าง Sprout")
		else:
			stamina -= Data.STAMINA_DRAIN_PER_SEC[st] * delta
			if stamina <= 0.0: stamina = 0.0; _revert(m, false); say("Stamina หมด กลับร่าง Sprout")
	elif not in_combat:
		stamina = minf(100.0, stamina + 15.0 * delta)
	if in_combat:
		combat_timer -= delta
		if combat_timer <= 0.0:
			in_combat = false
			bond_gauge = 0.0                    # Bond Gauge รีเซ็ตทุกครั้งหลังจบสู้
	var now_u := Time.get_unix_time_from_system()
	for mon in monsters + box:                  # ไข่เดินเวลาตาม unix time (ออฟไลน์ได้)
		if mon.egg_ready(now_u):
			mon.hatch(); say("ไข่ฟักแล้ว! (EXP/Bond รีเซ็ตตามกฎ Soft Death)")
			if active_monster() == null: active = monsters.find(mon) if mon in monsters else active

# ---------------- เซฟ / ส่ง client ----------------
func to_dict() -> Dictionary:
	var t: Array = []; var b: Array = []
	for m in monsters: t.append(m.to_dict())
	for m in box: b.append(m.to_dict())
	return {"team": t, "box": b, "active": active, "items": items, "flags": story_flags,
		"bond_gauge": bond_gauge, "stamina": stamina, "res_left": bond_resonance_left,
		"combat": in_combat, "now": Time.get_unix_time_from_system()}

func load_dict(d: Dictionary) -> void:
	monsters.clear(); box.clear()
	for x in d.get("team", []): monsters.append(MonsterState.from_dict(x))
	for x in d.get("box", []): box.append(MonsterState.from_dict(x))
	active = d.get("active", 0)
	items = d.get("items", items)
	story_flags = d.get("flags", {})
