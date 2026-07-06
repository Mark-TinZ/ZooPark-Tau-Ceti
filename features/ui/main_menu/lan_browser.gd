extends MarginContainer

const BROADCAST_PORT = 42355
const LISTEN_PORT = 42355
const HOST_PORT = 7777

var udp: PacketPeerUDP
var discovered_servers = {} # IP -> Server Name
var _poll_timer: float = 0.0

@onready var server_list_container: VBoxContainer = %ServerListContainer
@onready var refresh_status_lbl: Label = %RefreshStatusLabel
@onready var ip_input: LineEdit = %IpInput
@onready var connect_btn: Button = %ConnectBtn
@onready var add_server_btn: Button = %AddServerBtn
@onready var host_btn: Button = %HostBtn

func _ready() -> void:
	connect_btn.pressed.connect(_on_direct_connect_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	# add_server_btn.pressed.connect(_on_add_server) # TODO
	
	_setup_udp()
	set_process(true)
	
	_refresh_server_list()

func _setup_udp() -> void:
	udp = PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	var err = udp.bind(LISTEN_PORT)
	if err != OK:
		push_error("LAN Browser: Ошибка привязки UDP порта " + str(LISTEN_PORT))

func _exit_tree() -> void:
	if udp:
		udp.close()

func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= 1.5:
		_poll_timer = 0.0
		_broadcast_ping()
		_poll_udp_packets()

func _broadcast_ping() -> void:
	if udp:
		var msg = "ZOOPARK_PING"
		udp.set_dest_address("255.255.255.255", BROADCAST_PORT)
		udp.put_packet(msg.to_utf8_buffer())

func _poll_udp_packets() -> void:
	if not udp: return
	
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		var sender_ip = udp.get_packet_ip()
		var msg = packet.get_string_from_utf8()
		
		if msg.begins_with("ZOOPARK_PONG:"):
			var server_name = msg.replace("ZOOPARK_PONG:", "")
			if not discovered_servers.has(sender_ip):
				discovered_servers[sender_ip] = server_name
				_refresh_server_list()

func _refresh_server_list() -> void:
	# Удаляем старые серверы
	for c in server_list_container.get_children():
		if c != refresh_status_lbl:
			c.queue_free()
		
	if discovered_servers.is_empty():
		refresh_status_lbl.show()
		return
		
	refresh_status_lbl.hide()
	
	for ip in discovered_servers.keys():
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = discovered_servers[ip] + " (" + ip + ")"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var btn = Button.new()
		btn.text = "KEY_CONNECT"
		btn.pressed.connect(func(): _join_game(ip))
		
		hbox.add_child(lbl)
		hbox.add_child(btn)
		server_list_container.add_child(hbox)

func _on_direct_connect_pressed() -> void:
	var target_ip = ip_input.text
	if target_ip.is_empty():
		target_ip = "127.0.0.1"
	_join_game(target_ip)

func _on_host_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(HOST_PORT, 8)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Сервер успешно создан на порту ", HOST_PORT)
		SceneManager.load_scene_async("res://features/game/game.tscn")
	else:
		push_error("Не удалось создать сервер. Ошибка: " + str(error))

func _join_game(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, HOST_PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Подключение к ", ip, ":", HOST_PORT)
		SceneManager.load_scene_async("res://features/game/game.tscn")
	else:
		push_error("Ошибка подключения к " + ip)
