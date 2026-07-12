extends PanelContainer

signal buy_requested(item_type: String, item_data: Dictionary)

@onready var name_label: Label = %NameLabel
@onready var price_label: Label = %PriceLabel
@onready var btn_buy: Button = %BtnBuy

var current_type: String = ""
var current_data: Dictionary = {}

func _ready() -> void:
	btn_buy.pressed.connect(_on_buy_pressed)

func setup(title: String, price: int, item_type: String, item_data: Dictionary) -> void:
	name_label.text = title
	price_label.text = tr("HUD_MONEY") % price
	btn_buy.text = tr("SHOP_BTN_BUY")
	current_type = item_type
	current_data = item_data

func _on_buy_pressed() -> void:
	buy_requested.emit(current_type, current_data)
