extends Node
## เครือข่าย (ENet) + เซฟ + ลงทะเบียนปุ่มกด
## โมเดล: Listen-server หรือ Dedicated server (--server) ถือความจริงของ Party/ไข่/ดาเมจ
## client ควบคุมตำแหน่งตัวเอง (client-authoritative movement) แล้ว server ตัดสินทุกอย่างที่เหลือ

const PORT := 7777
const MAX_CLIENTS := 3          # + host = 4 คน
const SAVE_VERSION := 1

var debug_cheats := true        # ปิดตอนปล่อยจริง
var profile_id := ""
var world: Node = null

func _ready() -> void:
	_register_inputs()
	_load_profile_id()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func host(port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err

func join(address: String, port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server() and world:
		world.add_player(id)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and world:
		world.remove_player(id)

# ---------------- เซฟ (มีเวอร์ชัน + อัปเกรดอัตโนมัติ) ----------------
func sanitize(id: String) -> String:
	var out := ""
	for ch in id.substr(0, 40):
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "-" or ch == "_":
			out += ch
	return out

func save_profile(pid: String, data: Dictionary) -> void:
	pid = sanitize(pid)
	if pid == "": return
	DirAccess.make_dir_recursive_absolute("user://saves")
	data["v"] = SAVE_VERSION
	var f := FileAccess.open("user://saves/%s.json" % pid, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))

func load_profile(pid: String) -> Dictionary:
	pid = sanitize(pid)
	var path := "user://saves/%s.json" % pid
	if pid == "" or not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	return _migrate(parsed)

func _migrate(d: Dictionary) -> Dictionary:
	var v: int = d.get("v", 0)
	# if v < 2: ... เพิ่มขั้นอัปเกรดตรงนี้เมื่อเปลี่ยนโครงสร้างเซฟ
	d["v"] = maxi(v, SAVE_VERSION)
	return d

func _load_profile_id() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://profile.cfg")
	profile_id = cfg.get_value("p", "id", "")
	if profile_id == "":
		profile_id = "%x%x" % [randi(), Time.get_ticks_usec()]
		cfg.set_value("p", "id", profile_id)
		cfg.save("user://profile.cfg")

# ---------------- ปุ่มกด ----------------
func _register_inputs() -> void:
	var keys := {
		"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S,
		"strike": KEY_J, "skill": KEY_K, "form_next": KEY_Q, "form_sprout": KEY_E, "bond_res": KEY_R,
		"slot1": KEY_1, "slot2": KEY_2, "slot3": KEY_3, "slot4": KEY_4,
		"branch_a": KEY_B, "branch_b": KEY_N, "awaken": KEY_M,
		"cheat_exp": KEY_F1, "cheat_bond": KEY_F2, "cheat_items": KEY_F3, "cheat_kill": KEY_F4,
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[a]
		InputMap.action_add_event(a, ev)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("strike", click)
