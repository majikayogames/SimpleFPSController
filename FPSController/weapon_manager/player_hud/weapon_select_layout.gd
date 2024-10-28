extends MarginContainer

@export var is_expanded : bool = false
@export var show_slot_num : bool = false
@export var show_weapon_icon : bool = false

@export var weapon_name : String
@export var weapon_icon : Texture2D
@export var slot_num : int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_visibility()

func update_visibility():
	$MarginContainer/VBoxContainer/WeaponName.text = weapon_name
	$SizedBackgroundPanel/SlotNumber.text = str(slot_num)
	$MarginContainer/VBoxContainer/MarginContainer/WeaponIcon.texture = weapon_icon
	
	$MarginContainer/VBoxContainer/MarginContainer/WeaponIcon.visible = show_weapon_icon
	$MarginContainer/VBoxContainer/WeaponName.visible = is_expanded
	$SizedBackgroundPanel/SlotNumber.visible = show_slot_num
	
	$SizedBackgroundPanel.custom_minimum_size = Vector2(75, 75) if not is_expanded else Vector2(150, 0)
	$MarginContainer/VBoxContainer/IconMargin.custom_minimum_size = Vector2(0, 40 if is_expanded and show_weapon_icon else 20)
