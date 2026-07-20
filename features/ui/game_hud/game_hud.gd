extends CanvasLayer

@onready var money_label: Label = %MoneyLabel
@onready var power_label: Label = %PowerLabel
@onready var staff_label: Label = %StaffLabel
@onready var time_label: Label = %TimeLabel

@onready var btn_terraform: Button = %BtnTerraform
@onready var btn_paths: Button = %BtnPaths
@onready var btn_enclosures: Button = %BtnEnclosures
@onready var btn_infra: Button = %BtnInfra
@onready var btn_shop: Button = %BtnShop
@onready var btn_close_shop: Button = %BtnCloseShop

@onready var shop_panel: CenterContainer = $HUDContainer/ShopCenterContainer
@onready var shop_items_grid: GridContainer = %ShopItemsGrid
@onready var shop_title: Label = $HUDContainer/ShopCenterContainer/ShopPanel/MarginContainer/VBoxContainer/HeaderBox/Title

@onready var enclosure_label: Label = %EnclosureLabel

var shop_item_scene = preload("res://features/ui/game_hud/shop_item.tscn")

func _ready() -> void:
	# Локализация статичных кнопок
	btn_terraform.text = tr("HUD_BTN_TERRAFORM")
	btn_paths.text = tr("HUD_BTN_PATHS")
	btn_enclosures.text = tr("HUD_BTN_ENCLOSURES")
	btn_infra.text = tr("HUD_BTN_INFRA")
	btn_shop.text = tr("HUD_BTN_SHOP")
	shop_title.text = tr("SHOP_TITLE")

	EconomyManager.money_changed.connect(_on_money_changed)
	EconomyManager.day_changed.connect(_on_day_changed)
	EconomyManager.staff_changed.connect(_on_staff_changed)
	
	_on_money_changed(EconomyManager.money)
	_on_day_changed(EconomyManager.day)
	_on_staff_changed(EconomyManager.workers.size())
	
	btn_shop.pressed.connect(_on_btn_shop_pressed)
	btn_close_shop.pressed.connect(_on_btn_close_shop_pressed)
	btn_enclosures.pressed.connect(_on_btn_enclosures_pressed)
	EconomyManager.active_enclosure_changed.connect(_on_active_enclosure_changed)
	
	_populate_shop()
	_on_active_enclosure_changed(EconomyManager.active_enclosure)

func _on_active_enclosure_changed(enc: Enclosure) -> void:
	if enc:
		enclosure_label.text = "Выбран вольер: " + str(enc.climate)
	else:
		enclosure_label.text = ""

func _populate_shop() -> void:
	# Очищаем сетку
	for child in shop_items_grid.get_children():
		child.queue_free()
		
	# Фейковые данные для примера (позже брать из базы данных/ресурсов)
	var items = [
		{"title": "Cat", "type": "animal", "data": {"animal_type": Animal.Type.CAT, "price": 200}},
		{"title": "Penguin", "type": "animal", "data": {"animal_type": Animal.Type.PENGUIN, "price": 800}},
		{"title": "Tropical Enclosure", "type": "enclosure", "data": {"climate": Enclosure.Climate.TROPICAL, "price": 1500}},
		{"title": "Polar Enclosure", "type": "enclosure", "data": {"climate": Enclosure.Climate.POLAR, "price": 2000}}
	]
	
	for item in items:
		var node = shop_item_scene.instantiate()
		shop_items_grid.add_child(node)
		node.setup(item.title, item.data.price, item.type, item.data)
		node.buy_requested.connect(_on_item_buy_requested)

func _on_item_buy_requested(item_type: String, item_data: Dictionary) -> void:
	var price = item_data.get("price", 0)
	
	if item_type == "animal":
		if EconomyManager.active_enclosure == null:
			print(tr("SHOP_NO_ENCLOSURE"))
			return
		
		if EconomyManager.spend_money(price):
			var a = Animal.new()
			a.type = item_data.animal_type
			EconomyManager.active_enclosure.animals.append(a)
			print("Animal purchased and added to active enclosure!")
			
	elif item_type == "enclosure":
		print("Select placement for enclosure...")
		var placement = get_tree().current_scene.get_node_or_null("BuildingPlacementManager")
		if placement and placement.has_method("start_placement"):
			placement.start_placement("res://features/buildings/building_basic.tscn", item_data)
			shop_panel.hide()

func _on_money_changed(new_amount: int) -> void:
	money_label.text = tr("HUD_MONEY") % new_amount

func _on_day_changed(new_day: int) -> void:
	time_label.text = tr("HUD_TIME") % new_day

func _on_staff_changed(total_count: int) -> void:
	staff_label.text = tr("HUD_STAFF") % total_count

func _on_btn_shop_pressed() -> void:
	shop_panel.visible = !shop_panel.visible
	if shop_panel.visible:
		var placement = get_tree().current_scene.get_node_or_null("BuildingPlacementManager")
		if placement and placement.has_method("cancel_placement"):
			placement.cancel_placement()

func _on_btn_close_shop_pressed() -> void:
	shop_panel.visible = false

func _on_btn_enclosures_pressed() -> void:
	var placement = get_tree().current_scene.get_node_or_null("BuildingPlacementManager")
	if placement and placement.has_method("start_placement"):
		placement.start_placement("res://features/buildings/building_basic.tscn", {"price": 1000})
