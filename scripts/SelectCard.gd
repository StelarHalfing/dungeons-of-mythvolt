extends Button

# One selectable card on the run-setup screens (a character or a map):
# a portrait, a name, and a check mark in the bottom-right corner while
# it is the chosen one. Emits chosen(id) when clicked; RunSetup.gd owns
# which card is selected.

signal chosen(id: String)

var id: String = ""

@onready var portrait: TextureRect = $Content/Portrait
@onready var name_label: Label = $Content/NameLabel
@onready var check: TextureRect = $Check

func _ready() -> void:
	pressed.connect(func(): chosen.emit(id))

# Call after the card is in the tree (the @onready nodes must exist).
func setup(card_id: String, display_name: String, texture: Texture2D) -> void:
	id = card_id
	name_label.text = display_name
	portrait.texture = texture

func set_selected(selected: bool) -> void:
	check.visible = selected
