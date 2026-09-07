extends Control

# Run setup between the main menu and the game: pick a character, then a
# map. Both pages are instances of SelectPage.tscn built from
# GameManager.CHARACTER_DEFS / MAP_DEFS, so a new character or map is one
# table entry (plus its portrait) - the page grows a card for it
# automatically. This script only routes: it stores the choice in
# GameManager.selected_character / selected_map and moves between the
# pages, the menu and the game.

const GAME_SCENE := "res://scenes/Main.tscn"
const MENU_SCENE := "res://scenes/MainMenu.tscn"

# Untyped on purpose: SelectPage.gd has no class_name, and its
# build()/select() are called through the instance.
@onready var character_page = $CharacterPage
@onready var map_page = $MapPage

func _ready() -> void:
	character_page.build(GameManager.CHARACTER_DEFS, "portrait")
	map_page.build(GameManager.MAP_DEFS, "preview")
	character_page.selected.connect(_select_character)
	map_page.selected.connect(_select_map)
	character_page.back_pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	character_page.action_pressed.connect(_show_page.bind(map_page))
	map_page.back_pressed.connect(_show_page.bind(character_page))
	map_page.action_pressed.connect(_start_run)

	# Reflect the current (or default) choices so the sole option starts
	# checked and the description is never empty.
	_select_character(GameManager.selected_character)
	_select_map(GameManager.selected_map)
	_show_page(character_page)

func _select_character(id: String) -> void:
	id = _valid_id(GameManager.CHARACTER_DEFS, id)
	GameManager.selected_character = id
	character_page.select(id, GameManager.CHARACTER_DEFS[id])

func _select_map(id: String) -> void:
	id = _valid_id(GameManager.MAP_DEFS, id)
	GameManager.selected_map = id
	map_page.select(id, GameManager.MAP_DEFS[id])

# A stored choice that no longer matches a table entry (a renamed key)
# falls back to the table's first entry instead of erroring out and
# leaving the page with nothing checked.
func _valid_id(defs: Dictionary, id: String) -> String:
	return id if defs.has(id) else defs.keys()[0]

func _show_page(page: Control) -> void:
	character_page.visible = page == character_page
	map_page.visible = page == map_page

func _start_run() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
