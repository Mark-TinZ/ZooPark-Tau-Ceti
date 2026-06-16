extends MarginContainer

const BROADCAST_PORT = 42355
const LISTEN_PORT = 42355
const HOST_PORT = 7777

var udp: PacketPeerUDP
var discovered_servers = {} # IP -> Server Name
var _poll_timer: float = 0.0

var server_list_container: VBoxContainer
var ip_input: LineEdit

func _ready() -> void:
	# Даем отступы
	add_theme_constant_override("margin_left", 20)
	add_theme_constant_override("margin_right", 20)
	add_theme_constant_override("margin_top", 20)
	add_theme_constant_override("margin_bottom", 20)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	_build_ui(main_vbox)
	_setup_udp()
	
	set_process(true)

func _setup_udp() -> void:
	udp = PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	# Привязываем на прослушивание входящих броадкастов
	var err = udp.bind(LISTEN_PORT)
	if err != OK:
		push_error("LAN Browser: Ошибка привязки UDP порта " + str(LISTEN_PORT))

func _exit_tree() -> void:
	if udp:
		udp.close()

func _process(delta: float) -> void:
	_poll_timer += delta
	# Опрашиваем сокет и пингуем раз в 1.5 секунды, чтобы не грузить поток
	if _poll_timer >= 1.5:
		_poll_timer = 0.0
		_broadcast_ping()
		_poll_udp_packets()

func _broadcast_ping() -> void:
	if udp:
		var msg = "ZOOPARK_PING"
		# Броадкаст на 255.255.255.255
		udp.set_dest_address("255.255.255.255", BROADCAST_PORT)
		udp.put_packet(msg.to_utf8_buffer())

func _poll_udp_packets() -> void:
	if not udp: return
	
	# Неблокирующий опрос
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		var sender_ip = udp.get_packet_ip()
		var msg = packet.get_string_from_utf8()
		
		# Если получаем ответ PONG от сервера
		if msg.begins_with("ZOOPARK_PONG:"):
			var server_name = msg.replace("ZOOPARK_PONG:", "")
			if not discovered_servers.has(sender_ip):
				discovered_servers[sender_ip] = server_name
				_refresh_server_list()

func _build_ui(parent: Control) -> void:
	# Список серверов
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	server_list_container = VBoxContainer.new()
	server_list_container.add_theme_constant_override("separation", 10)
	scroll.add_child(server_list_container)
	
	# Ручное подключение
	var direct_connect_hbox = HBoxContainer.new()
	var ip_label = Label.new()
	ip_label.text = "IP Адрес:"
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "127.0.0.1"
	ip_input.custom_minimum_size = Vector2(200, 0)
	var connect_btn = Button.new()
	connect_btn.text = "Быстрое подключение"
	connect_btn.pressed.connect(_on_direct_connect_pressed)
	
	direct_connect_hbox.add_child(ip_label)
	direct_connect_hbox.add_child(ip_input)
	direct_connect_hbox.add_child(connect_btn)
	
	# Кнопки управления
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 20)
	
	var add_server_btn = Button.new()
	add_server_btn.text = "Добавить в избранное"
	# add_server_btn.pressed.connect(_on_add_server) # TODO
	
	var host_btn = Button.new()
	host_btn.text = "Создать сервер (Host)"
	host_btn.pressed.connect(_on_host_pressed)
	
	bottom_hbox.add_child(add_server_btn)
	bottom_hbox.add_child(host_btn)
	
	parent.add_child(Label.new()) # отступ
	parent.add_child(scroll)
	parent.add_child(HSeparator.new())
	parent.add_child(direct_connect_hbox)
	parent.add_child(HSeparator.new())
	parent.add_child(bottom_hbox)
	
	_refresh_server_list()

func _refresh_server_list() -> void:
	for c in server_list_container.get_children():
		c.queue_free()
		
	if discovered_servers.is_empty():
		var lbl = Label.new()
		lbl.text = "Идёт поиск серверов в локальной сети..."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		server_list_container.add_child(lbl)
		return
		
	for ip in discovered_servers.keys():
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = discovered_servers[ip] + " (" + ip + ")"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var btn = Button.new()
		btn.text = "Подключиться"
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
	# Пример создания сервера ENet
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(HOST_PORT, 8)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Сервер успешно создан на порту ", HOST_PORT)
		# В реальной игре нужно запустить сцену с игрой
		SceneManager.load_scene_async("res://scenes/game/game.tscn")
	else:
		push_error("Не удалось создать сервер. Ошибка: " + str(error))

func _join_game(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, HOST_PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Подключение к ", ip, ":", HOST_PORT)
		SceneManager.load_scene_async("res://scenes/game/game.tscn")
	else:
		push_error("Ошибка подключения к " + ip)
