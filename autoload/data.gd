extends Node
## ฐานข้อมูลเกม (ตอนนี้เป็น Dictionary เพื่อความเร็ว ภายหลังย้ายเป็น Resource/.tres ได้)
## ตามเอกสาร v1.3: ธาตุ 10 ตัว, สาย Cinder เต็ม, ตัวเริ่มต้นอีก 4 ตัวหยุดที่ Bloom ใน 1.0

enum Element { FIRE, WATER, WIND, EARTH, ICE, THUNDER, PLANT, LIGHT, SHADOW, AETHER }
enum Stage { SPROUT, BLOOM, APEX, RESONANCE }
enum Branch { NONE, A, B }

const ELEMENT_COLOR := {
	Element.FIRE: Color("ff7a2f"), Element.WATER: Color("3fa7ff"), Element.WIND: Color("8df0c0"),
	Element.EARTH: Color("a98a5a"), Element.PLANT: Color("6fd64f"), Element.AETHER: Color("a58bff"),
}

# ---- ตั้งค่าเปลี่ยนร่าง (FormSwitchConfig) ----
const EE_MAX := 100.0
const BOND_GAUGE_MAX := 100.0
const BOND_RESONANCE_SECONDS := 12.0
const RESONANCE_MIN_BOND := 8            # สมมติฐาน: เอกสารบอกแค่ "Bond สูง"
const BRANCH_MIN_BOND := 5
const SWITCH_COOLDOWN := {Stage.BLOOM: 5.0, Stage.APEX: 7.0, Stage.RESONANCE: 10.0}
const EARLY_RETURN_CD_MULT := 0.7         # กลับร่างเองก่อน EE หมด ลด CD 30%
const EE_COST := {Stage.BLOOM: 20.0, Stage.APEX: 35.0, Stage.RESONANCE: 60.0}
const EE_DRAIN_PER_SEC := {Stage.BLOOM: 2.0, Stage.APEX: 4.0, Stage.RESONANCE: 6.0}
const STAMINA_DRAIN_PER_SEC := {Stage.BLOOM: 3.0, Stage.APEX: 6.0, Stage.RESONANCE: 10.0}

# ---- เลเวล ----
const STAGE_UNLOCK_LEVEL := {Stage.BLOOM: 10, Stage.APEX: 25, Stage.RESONANCE: 40}
const MAX_LEVEL_BY_STAGE := {Stage.SPROUT: 15, Stage.BLOOM: 30, Stage.APEX: 50, Stage.RESONANCE: 60}
const MIN_LEVEL_BY_STAGE := {Stage.SPROUT: 1, Stage.BLOOM: 10, Stage.APEX: 25, Stage.RESONANCE: 40}

# ---- เวลาฟักไข่ (Soft Death) วินาที ----
const HATCH_SECONDS := {Stage.SPROUT: 1200.0, Stage.BLOOM: 1200.0, Stage.APEX: 10800.0, Stage.RESONANCE: 25200.0}
var egg_time_scale := 1.0   # ปรับด้วย CLI: -- --egg-scale=0.005 (ใช้ทดสอบฝั่ง server)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--egg-scale="):
			egg_time_scale = float(a.substr(12))

# ---- ฟอร์มทั้งหมด (id -> ข้อมูล) released=false จะแสดง silhouette "เร็วๆ นี้" ----
const FORMS := {
	"embit":    {"name": "Embit",    "line": "cinder", "stage": Stage.SPROUT,    "branch": Branch.NONE, "hp": 60,  "atk": 10, "role": "Support/Striker", "released": true},
	"cindrake": {"name": "Cindrake", "line": "cinder", "stage": Stage.BLOOM,     "branch": Branch.NONE, "hp": 110, "atk": 22, "role": "Striker",   "released": true},
	"pyrovane": {"name": "Pyrovane", "line": "cinder", "stage": Stage.APEX,      "branch": Branch.A,    "hp": 150, "atk": 38, "role": "Controller/Striker", "released": true},
	"anvilord": {"name": "Anvilord", "line": "cinder", "stage": Stage.APEX,      "branch": Branch.B,    "hp": 240, "atk": 28, "role": "Guardian",  "released": true},
	"heliovane":{"name": "Heliovane","line": "cinder", "stage": Stage.RESONANCE, "branch": Branch.A,    "hp": 190, "atk": 50, "role": "Controller/Striker", "released": true},
	"magmarch": {"name": "Magmarch", "line": "cinder", "stage": Stage.RESONANCE, "branch": Branch.B,    "hp": 320, "atk": 36, "role": "Guardian",  "released": true},
	# ตัวเริ่มต้นอีก 4 ตัว: ชื่อ Sprout ยังไม่ออกแบบ (ใช้ placeholder) หยุดที่ Bloom
	"tide_sprout": {"name": "Tidekin (TBD)",  "line": "tide",  "stage": Stage.SPROUT, "branch": Branch.NONE, "hp": 60, "atk": 9,  "role": "Controller", "released": true},
	"tide_bloom":  {"name": "Tidekin Bloom",  "line": "tide",  "stage": Stage.BLOOM,  "branch": Branch.NONE, "hp": 115, "atk": 20, "role": "Controller", "released": true},
	"wind_sprout": {"name": "Wingkin (TBD)",  "line": "wind",  "stage": Stage.SPROUT, "branch": Branch.NONE, "hp": 55, "atk": 11, "role": "Striker", "released": true},
	"wind_bloom":  {"name": "Wingkin Bloom",  "line": "wind",  "stage": Stage.BLOOM,  "branch": Branch.NONE, "hp": 100, "atk": 24, "role": "Striker", "released": true},
	"flora_sprout":{"name": "Florakin (TBD)", "line": "plant", "stage": Stage.SPROUT, "branch": Branch.NONE, "hp": 65, "atk": 8,  "role": "Support", "released": true},
	"flora_bloom": {"name": "Florakin Bloom", "line": "plant", "stage": Stage.BLOOM,  "branch": Branch.NONE, "hp": 120, "atk": 18, "role": "Support", "released": true},
	"golem_sprout":{"name": "Golemkin (TBD)", "line": "earth", "stage": Stage.SPROUT, "branch": Branch.NONE, "hp": 75, "atk": 8,  "role": "Guardian", "released": true},
	"golem_bloom": {"name": "Golemkin Bloom", "line": "earth", "stage": Stage.BLOOM,  "branch": Branch.NONE, "hp": 140, "atk": 17, "role": "Guardian", "released": true},
}

const LINES := {
	"cinder": {"element": Element.FIRE,  "sprout": "embit"},
	"tide":   {"element": Element.WATER, "sprout": "tide_sprout"},
	"wind":   {"element": Element.WIND,  "sprout": "wind_sprout"},
	"plant":  {"element": Element.PLANT, "sprout": "flora_sprout"},
	"earth":  {"element": Element.EARTH, "sprout": "golem_sprout"},
}

# ---- ปฏิกิริยาธาตุที่เปิดใน 1.0 (เปลี่ยนชื่อ "Bloom" ของไฟ+พฤกษา เป็น Wildfire กันชื่อซ้ำ) ----
func reaction(aura: int, incoming: int) -> Dictionary:
	if aura < 0 or aura == incoming:
		return {}
	var pair := [aura, incoming]
	if Element.FIRE in pair and Element.WATER in pair:
		return {"name": "Steam", "mult": 1.8, "aoe": 4.0}
	if Element.FIRE in pair and Element.PLANT in pair:
		return {"name": "Wildfire", "mult": 1.4, "aoe": 0.0}
	if Element.WIND in pair:   # Swirl: ลม + ธาตุใดก็ได้
		return {"name": "Swirl", "mult": 1.2, "aoe": 5.0}
	return {}

# ---- แบบทดสอบพิธีไข่ (เอกสารออกแบบแล้วแค่ 2 จาก 7 ข้อ) ----
const QUIZ := [
	{"q": "คืนก่อนเดินทาง นอนไม่หลับ คุณจะทำอะไร", "a": [
		{"t": "นั่งดูกองไฟกับเพื่อน", "s": {"cinder": 2, "plant": 1}},
		{"t": "ออกไปเดินดูดาวคนเดียว", "s": {"wind": 2, "tide": 1}},
		{"t": "ตรวจของทุกชิ้นอีกรอบ", "s": {"earth": 2, "tide": 1}},
		{"t": "ช่วยคนอื่นเตรียมของ", "s": {"plant": 2, "earth": 1}}]},
	{"q": "เพื่อนทำพลาดจนแผนล่ม คุณจะ", "a": [
		{"t": "ยิ้มแล้วบอกว่าลองใหม่", "s": {"cinder": 2, "wind": 1}},
		{"t": "ถามว่าพลาดตรงไหน แล้วหาทางแก้", "s": {"tide": 2, "earth": 1}},
		{"t": "ปลอบก่อน ค่อยคุยทีหลัง", "s": {"plant": 2, "cinder": 1}},
		{"t": "รับผิดชอบส่วนที่เหลือเอง", "s": {"earth": 2, "cinder": 1}}]},
	# TODO: ข้อ 3-7 รอออกแบบ (ใส่ต่อได้เลย รูปแบบเดียวกัน)
]

# ---- นิสัย (Temperament) ของตัวเริ่มต้น ตามคอลัมน์ "นิสัยที่เข้ากัน" ในเอกสาร ----
const TEMPER_ADJ := {"cinder": "อบอุ่น", "tide": "สุขุม", "wind": "อิสระ", "plant": "อ่อนโยน", "earth": "หนักแน่น"}

# ---- ภาพ placeholder (ยังไม่มีอาร์ต) วาดเป็นก้อนกลมมีตา ----
var _tex_cache := {}
func blob(color: Color) -> ImageTexture:
	var key := color.to_html()
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 32).length()
			var c := Color(0, 0, 0, 0)
			if d < 28.0:
				c = color if d < 22.0 else color.darkened(0.45)
			if Vector2(x - 24, y - 28).length() < 3.5 or Vector2(x - 40, y - 28).length() < 3.5:
				c = Color("1b1b1b")
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex
