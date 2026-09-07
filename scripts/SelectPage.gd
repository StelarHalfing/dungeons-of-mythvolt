extends Control

# One page of the run-setup flow (RunSetup.tscn instances this twice: the
# character page and the map page, differing only in title/action text).
# build() fills the card row from a GameManager def table and select()
# marks a card + fills the description panel from its def; the page only
# reports clicks through its signals - RunSetup.gd owns the actual
# choice. The card row scrolls sideways, so any number of table entries
# fit without running under the description panel.

signal selected(id: String)
signal back_pressed
signal action_pressed

@export var title_text: String = "Choose"
@export var action_text: String = "Next"

const CardScene := preload("res://scenes/SelectCard.tscn")

@onready var cards_row: HBoxContainer = $CardScroll/Cards
@onready var name_label: Label = $DescPanel/VBox/NameLabel
@onready var flavor_label: Label = $DescPanel/VBox/FlavorLabel
@onready var traits_label: Label = $DescPanel/VBox/TraitsLabel

# id -> SelectCard
var cards: Dictionary = {}

func _ready() -> void:
	$Title.text = title_text
	$ActionButton.text = action_text
	$BackButton.pressed.connect(back_pressed.emit)
	$ActionButton.pressed.connect(action_pressed.emit)

# One card per def entry; image_key names the def key holding the card
# picture ("portrait" for characters, "preview" for maps).
func build(defs: Dictionary, image_key: String) -> void:
	for id in defs.keys():
		var card = CardScene.instantiate()
		cards_row.add_child(card)
		card.setup(id, defs[id]["display_name"], load(defs[id][image_key]))
		card.chosen.connect(selected.emit)
		cards[id] = card

func select(id: String, def: Dictionary) -> void:
	for card_id in cards.keys():
		cards[card_id].set_selected(card_id == id)
	name_label.text = def["display_name"]
	flavor_label.text = def["flavor"]
	var lines: PackedStringArray = []
	for line in def["traits"]:
		lines.append("- " + line)
	traits_label.text = "\n".join(lines)
