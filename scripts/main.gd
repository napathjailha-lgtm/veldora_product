extends Node
## เมนูเริ่มต้น: Host / Join  |  CLI: --server (dedicated, ใช้กับ --headless)  --host  --join=IP  --bot

var _ui: CanvasLayer
var _addr: LineEdit
var _msg: Label

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)
	if "--server" in args:
		_start(true, false, "")
	elif "--host" in args:
		_start(true, true, "")
	else:
		for a in args:
			if a.begins_with("--join="):
				_start(false, false, a.substr(7)); return
		_build_menu()

func _build_menu() -> void:
	_ui = CanvasLayer.new(); add_child(_ui)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(320, 0)
	_ui.add_child(box)
	var t := Label.new(); t.text = "Veldara: Bond of the Wild\nCaldra Arc (Online Co-op Prototype)"
	_addr = LineEdit.new(); _addr.text = "127.0.0.1"; _addr.placeholder_text = "IP ของ Host"
	var host := Button.new(); host.text = "Host เกม (พอร์ต %d)" % Net.PORT
	var join := Button.new(); join.text = "Join"
	_msg = Label.new()
	for c in [t, _addr, host, join, _msg]: box.add_child(c)
	host.pressed.connect(func(): _start(true, true, ""))
	join.pressed.connect(func(): _start(false, false, _addr.text.strip_edges()))

func _start(is_server: bool, with_player: bool, address: String) -> void:
	var w := World.new(); w.name = "World"; add_child(w)     # ต้องชื่อ/พาธเดียวกันทุกเครื่อง
	var err := Net.host() if is_server else Net.join(address)
	if err != OK:
		_fail("เชื่อมต่อไม่สำเร็จ (error %d)" % err)
		return
	if is_server and with_player: w.add_player(1)
	if is_server and _ui: _ui.queue_free()
	if _msg and not is_server: _msg.text = "กำลังเชื่อมต่อ..."
	if "--bot" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/bot.gd").new())

func _on_connected() -> void:
	if _ui: _ui.queue_free()

func _on_failed() -> void:
	_fail("เชื่อมต่อไม่สำเร็จ")

func _on_server_lost() -> void:
	get_tree().reload_current_scene()

func _fail(text: String) -> void:
	if has_node("World"): get_node("World").queue_free()
	multiplayer.multiplayer_peer = null
	if _msg: _msg.text = text
