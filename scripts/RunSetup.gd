extends Control

# Run setup between the main menu and the game: pick a character, then a
# map. Both pages are built from GameManager.CHARACTER_DEFS / MAP_DEFS,
# so a new character or map is one table entry (plus its portrait) -
# this scene grows a card for it automatically. Clicking a card selects
# it (check mark bottom-right, description panel filled with its traits)
# and stores the choice in GameManager.selected_character / selected_map.

const GAME_SCENE := "res://scenes/Main.tscn"
const MENU_SCENE := "res://scenes/MainMenu.tscn"
const CardScene := preload("res://scenes/SelectCard.tscn")

@onready var character_page: Control = $CharacterPage
@onready var map_page: Control = $MapPage

var character_cards: Dictionary = {}
var map_cards: Dictionary = {}

func _ready() -> void:
	_build_cards(GameManager.CHARACTER_DEFS, $CharacterPage/Cards, character_cards, "portrait", _select_character)
	_build_cards(GameManager.MAP_DEFS, $MapPage/Cards, map_cards, "preview", _select_map)

	$CharacterPage/BackButton.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	$CharacterPage/NextButton.pressed.connect(_show_map_page)
	$MapPage/BackButton.pressed.connect(_show_character_page)
	$MapPage/StartButton.pressed.connect(_start_run)

	# Reflect the current (or default) choices so the sole option starts
	# checked and the description is never empty.
	_select_character(GameManager.selected_character)
	_select_map(GameManager.selected_map)
	_show_character_page()

func _build_cards(defs: Dictionary, container: Container, cards: Dictionary, image_key: String, on_chosen: Callable) -> void:
	for id in defs.keys():
		var card = CardScene.instantiate()
		container.add_child(card)
		card.setup(id, defs[id]["display_name"], load(defs[id][image_key]))
		card.chosen.connect(on_chosen)
		cards[id] = card

func _select_character(id: String) -> void:
	GameManager.selected_character = id
	_refresh_page(character_cards, id, GameManager.CHARACTER_DEFS[id], $CharacterPage/DescPanel)

func _select_map(id: String) -> void:
	GameManager.selected_map = id
	_refresh_page(map_cards, id, GameManager.MAP_DEFS[id], $MapPage/DescPanel)

func _refresh_page(cards: Dictionary, selected_id: String, def: Dictionary, panel: Control) -> void:
	for id in cards.keys():
		cards[id].set_selected(id == selected_id)
	panel.get_node("VBox/NameLabel").text = def["display_name"]
	panel.get_node("VBox/FlavorLabel").text = def["flavor"]
	var lines: PackedStringArray = []
	for line in def["traits"]:
		lines.append("- " + line)
	panel.get_node("VBox/TraitsLabel").text = "\n".join(lines)

func _show_character_page() -> void:
	character_page.visible = true
	map_page.visible = false

func _show_map_page() -> void:
	character_page.visible = false
	map_page.visible = true

func _start_run() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
