# Plan: permanent inventory, luck chests and 15:00 extraction

Status: design plan, written 2026-09-08 and revised the same day
(rolled affixes instead of one fixed stat per slot; a three-slot run
backpack; five wear slots, all with art the packs already have).
Progress: **phases 1 (data layer), 2 (Luck), 3 (chests, the reveal,
the run backpack, HUD rows), 4 (securing at 15:00, Victory panel,
kill counter), 5 (the Inventory screen) and 6 (the pause menu's
Backpack panel, Saves item count, README, build-folder sync) landed
2026-09-08** - 104 + 37 + 67 + 28 + 42 + 30 harness checks passed;
the reveal, the panels, the Inventory screen and the Backpack panel
checked in windowed captures. All six phases are built; nothing is
committed yet. Numbers are starting points to tune in the
harness, not promises.

## The loop in one paragraph

Chests turn up during a run. Opening one rolls a piece of armour: its
rarity decides how many buffs it carries and how strong they are, and
both rolls are weighted by a new Luck stat. Armour found this run is
worn immediately if it beats what is on, otherwise it goes into a
three-slot **backpack**; five worn pieces plus three stowed is all a
run can carry out. Reach 15:00 and everything worn or stowed that was
found this run is *secured*: it lands in the main menu's Backpack tab
as last run's haul, and **Extract All** moves it into the permanent
inventory; die before 15:00 and it is lost with the run. Between runs
the Inventory screen's Equip bar dresses the character by drag and
drop, up to five pieces, which then start every run already worn (and
are never at risk). 15:00 is
also the moment the Reaper's field wipe is one second away, so
extraction is the run's win condition made tangible.

## What already exists to build on

- **Per-slot save file** (`user://save_slot_N.json`: coins, permanent
  upgrades, unlocks) with exactly one reader (`_apply_slot()`) and one
  writer (`_save_slot()`), everything on disk treated as untrusted and
  clamped. Inventory goes in the same file the same way.
- **The getter convention**: `get_damage_mult()`, `get_coin_mult()`
  etc. are the single place a run bonus and a permanent bonus combine.
  Run-only and permanent sources that share a stat ADD, so both maxed
  is exactly x2. Armour affixes and Luck follow this rule.
- **Free stat hooks**: `speed_mult` and `max_hp_bonus` exist in
  `GameManager.gd` with nothing driving them; `Player.gd` already
  reads both every physics frame (mid-run max HP gains become free HP).
- **The 15:00 trigger**: `_check_unlocks()` already fires
  `passive_slot_15min` at `game_time >= 900`. Extraction is a sibling
  check on the same clock.
- **Patterns to copy**: pickups that home and free themselves
  (`MagnetPickup.gd`, `GoldDreamPickup.gd`); press-E in a ring
  (`BossTotem.gd`); the HUD toast (`unlock_toast` in `HUD.gd`); the
  `IconSlot`/`WeaponIcon` grid (IconSlot already has two theme
  variations, `IconSlot` and `IconSlotLocked`, so a rarity frame is
  more of the same); the main menu's panel pattern (Upgrades /
  Unlocks / Saves); `format_bonus()` for turning a stat and value into
  shop text; `TotemPointer.gd` for pointing at a thing off-screen;
  `ScreenWrap.gd` so a chest left behind comes back round in front of
  the player like a gem does.
- **Art already in `allassets/`** (surveyed 2026-09-08):
  - Chests: `2D Pixel Dungeon Asset Pack/items and trap_animation/chest/`
    (4 closed + 4 open frames, plus a `mini_chest` set) and
    `Fantasy Dreamland/Free Treasure Chests/32x32/RGW_Chests.png` (three
    colour variants, handy for showing rarity on the chest itself).
  - Helmets and chest armour: `Item Icons 32x32/Armor Icons 32x32
    Pixelart/` (ElvGames): `Leather Helm/` (424 files), `Steel Helm/`,
    `Leather Armor/`, `Steel Armor/` (256 files), recolours of a few
    base shapes in brown, red, grey, purple and orange, plus steel
    variants with a blue gem inlay.
  - Boots, shields and a glove: `Dungeon Gathering .../New Items
    [Update]/16x16 Items Pack v3.png` (also the `All items (Separated
    Files)` folder next to it): a boots row and a shields row in eight
    colours each (brown, grey, steel-blue, gold, cyan, purple, green,
    orange), and a single red glove on the bottom row.
  - Sound: `Platformer World/Sound Effects/OGG/Treasure_Chest_Open.ogg`
    (nothing is wired for audio yet, so optional).

## Decisions

Each one lists the recommendation first. Changing any of these changes
the work, so confirm or override before phase 1 starts.

### 1. Five wear slots, all with art the packs already have; the slot only decides the icon

| Slot   | Icon source                                                          | Look by rarity                                                     |
|--------|----------------------------------------------------------------------|--------------------------------------------------------------------|
| Helmet | ElvGames `Leather Helm/` and `Steel Helm/`                           | leather (Common, Rare), steel (Epic), steel with the blue gem (Legendary) |
| Armor  | ElvGames `Leather Armor/` and `Steel Armor/`                         | same rule                                                          |
| Boots  | DG boots row, eight colours                                          | brown (Common), steel-blue (Rare), purple (Epic), gold (Legendary) |
| Shield | DG shields row, eight colours                                        | same colour rule                                                   |
| Gloves | the DG sheet's red glove (bottom row, one colour)                    | frame and name only                                                |

A slot is a place to wear one piece and picks its icon. It carries no
stat of its own: every stat on a piece is a rolled affix (decision 2).
So five worn pieces is the cap on how many affixes a run can carry
(up to 20 with a full Legendary set), and a Legendary helmet and a
Legendary pair of gloves are equally good rolls of the same thing.

**How rarity shows.** On the `IconSlot` frame (a rarity-coloured
border, a fourth theme variation next to `IconSlot` /
`IconSlotLocked`) and in the item name's colour, never by recolouring
the sprite: a modulate tint only works on pale sprites and would turn
the red glove to mud. Where a row has colour variants (boots, shields,
leather vs steel vs gem-steel) the variant follows rarity too, so the
sprite and the frame agree. The Fire Zone `Shield.png` stays the
Forcefield's icon; the shield slot uses the DG row so the two never
look alike.

Alternatives for the fifth slot, both weaker: **Amulet** on the DG
medallion-orb row (eight colours, but its gold one is already the
Lucky Coin passive's icon), or **Cloak** on the plain pennant row (a
stretch as art). The glove is the honest read of the sheet.

Damage reduction and block chance are not in this version; they can
join the affix pool later if a defensive stat is wanted.

### 2. Rarity sets the number of buffs and their range; both rolls are luck-weighted

| Rarity    | Weight at Luck x1 | Weight at Luck x2 (max) | Buffs | Value range | Frame / name colour | Salvage |
|-----------|-------------------|-------------------------|-------|-------------|---------------------|---------|
| Common    | 94                | 60                      | 1     | 5% to 10%   | white               | 50      |
| Rare      | 5                 | 29                      | 2     | 12% to 20%  | blue                | 150     |
| Epic      | 1                 | 15                      | 3     | 25% to 35%  | purple              | 500     |
| Legendary | 0                 | 1                       | 4     | 40% to 50%  | gold                | 1500    |

Rolling a piece, in order:

1. **Slot**: uniform over the five.
2. **Rarity**: weighted pick between two anchor tables. At base Luck a
   chest is almost always Common (94/5/1/0: Rare one chest in twenty,
   Epic one in a hundred, never Legendary); with the Luck upgrade and
   the Four-Leaf Clover both maxed (x2, `LUCK_MAX_MULT`) it is
   60/29/15/1 (57/28/14/1%, since those weights sum to 105). In
   between each weight slides linearly, and past x2 it keeps sliding
   (clamped at zero), so luck sources added later keep pushing Common
   down: x3 would be about 24/48/26/2%, and Common runs out at x4.
3. **Buffs**: draw the rarity's count from the affix pool below
   without replacement, so one piece never carries the same stat
   twice. Every stat is equally likely.
4. **Values**: each buff rolls `t = randf() ** (1.0 / get_luck_mult())`
   and lands at `round(lerp(range_min, range_max, t))` whole percent.
   At Luck x1 that is uniform across the range; at Luck x2 the average
   roll sits two thirds of the way up instead of halfway, so a lucky
   Legendary reads 47/48/49/50 rather than 41/44/42/46. One formula,
   one luck stat, no second table.

Items are stored as their rolls, not re-rolled from a seed:
`{"id": "helmet", "rarity": 3, "affixes": [{"stat": "damage", "value": 47}, ...]}`.
Icon choice (leather vs steel, which colour of boot) follows from
`id` and `rarity`, so it is never stored.

### 3. The affix pool: every passive stat except projectile count

Eleven stats. Ten are the passives and permanent upgrades that already
exist plus the two the user named (Luck and max HP); move speed is
added because its hook is already free and boots without it feel
wrong. Projectile Count and the slot-count upgrades are excluded (not
stat buffs). A rolled value `p` (whole percent) applies as:

| Affix key      | Reads as            | Applies as                                             | Legendary example      |
|----------------|---------------------|--------------------------------------------------------|------------------------|
| `damage`       | +p% damage          | added to Power Emblem's run term in `get_damage_mult()` | +45% damage            |
| `max_hp`       | +p% max HP          | multiplies `(100 + max_hp_bonus)` in `get_max_hp()`    | 145 HP                 |
| `luck`         | +p% luck            | added in `get_luck_mult()`                             | x1.45 luck             |
| `xp_gain`      | +p% XP gain         | added to Wisdom Orb's run term in `get_xp_mult()`      | +45% XP                |
| `gold_gain`    | +p% gold gain       | added in `get_coin_mult()`                             | +45% gold              |
| `pickup_range` | +p% pickup range    | added in a new `get_pickup_range_mult()`               | +45% range             |
| `regen`        | +x HP/s             | `p / 100 * 2.0` HP/s added in `get_health_regen_rate()` | +0.9 HP/s (a maxed Vitality Elixir) |
| `duration`     | +p% duration        | added in `get_duration_mult()`                         | +45% duration          |
| `knockback`    | +p% knockback       | added in `get_knockback_mult()`                        | +45% knockback         |
| `attack_speed` | +p% attack speed    | added to the denominator in `get_cooldown_mult()`      | +45% attacks/sec       |
| `move_speed`   | +p% move speed      | added in a new `get_speed_mult()`                      | +45% speed             |

Regen is the one flat stat, so its percent is scaled: 2.0 HP/s is the
100% mark, which puts a Legendary regen roll level with a maxed
Vitality Elixir or a maxed Health Regeneration upgrade (both 1.0 HP/s).

**Stacking**: an affix adds into the *run-side* term of its stat, the
same way a passive does, so armour, passive and permanent bonuses
follow the existing add-then-multiply rules and nothing needs a
special case. The same stat on several worn pieces adds. The ceiling
is real: five Legendary pieces that all rolled damage would be +250%
damage on top of a maxed Power Emblem. Recommendation: no cap in v1,
since a full Legendary set is well over a hundred chests of luck and
is the long-term goal the whole system exists for. If it proves too
much, `ARMOR_STAT_CAP` (say 1.0 per stat across all worn pieces) is a
one-line clamp in `_apply_armor()`.

### 4. Luck is a stat with two additive sources plus armour

`get_luck_mult() = 1.0 + get_permanent_bonus("luck") + luck_bonus + armor("luck")`.
A permanent **Luck** upgrade (+10%/level, 5 levels, Damage's cost
curve) and a run passive (**Four-Leaf Clover**, +10%/level, 5 levels).
Both maxed is exactly x2 before armour, per the house rule. Luck
multiplies:

- the per-kill chest drop chance (decision 5),
- the rarity table's slide from almost-all-Common to 60/29/15/1 and
  the affix value roll (decision 2),
- the Magnet and Gold Dream drop chances (`Zombie.MAGNET_DROP_CHANCE`),
  which `TODO.md` already earmarked for a luck stat.

Luck on armour feeds back into the next chest, which is the point: a
lucky pair of gloves makes the next Legendary likelier.

### 5. Chests drop from kills, throttled, plus one from the boss

Any enemy kill rolls `CHEST_DROP_CHANCE = 0.0025 * get_luck_mult()`,
but a chest never drops while one is still on the field, and never
within `CHEST_MIN_INTERVAL = 45 s` of the last one. Late game (~27
spawns/s) that settles to one chest a minute; early game they are
rare and feel earned. Expect roughly 8 to 12 per full run at base
Luck, nearly all of them Common; Legendaries need Luck (none at x1),
and at max Luck about one chest in a hundred is Legendary and four in
ten are Rare or better.

The **Ancient Keeper always drops a chest** on top of its gem and coin
pile, with the rarity floor raised to Rare. That gives the boss a
reason beyond XP and coins to walk five minutes for.

Alternative: a fixed schedule (a chest at 3:00, 6:00, 9:00, 12:00 with
a pointer). Simpler, but it makes Luck do less and removes the
"a chest just dropped in the middle of the horde" moment. Can be
added later as a pity timer (if no chest for 120 s, the next kill
drops one) if the roll feels too streaky.

### 6. Walk over a chest to open it; the reveal pauses the run; loot is worn immediately

No E prompt: the chest is an `Area2D` like a pickup and opens on
contact. Opening pauses the run for a **reveal** on the HUD
(`ChestReveal.tscn`, modelled on Vampire Survivors' treasure chests,
revised 2026-09-08 from the earlier no-pause toast): a "Treasure
Found!" panel with the closed chest and an Open prompt (it opens by
itself after 1.2 s); the chest springs open with a burst, beams of
light fan up out of it, sparkles and a fountain of coins pour out
while a counter ticks up the chest's gold, and the piece rises
spinning out of the chest into the light; at the top it settles with a
starburst, its name and rarity, its affix lines and where it went.
Rarity sets the fanfare: one white beam for Common, one blue for Rare,
three purple for Epic, five gold-orange-red for Legendary, with more
coins, a longer show and a screen flash up the tiers; the chest also
pays 10 / 25 / 60 / 150 gold through `add_coins()`. Any click or key
skips to the settled piece, one more closes it. Where the piece goes
is still decided automatically, so the reveal never asks a question:

1. If its slot is empty, or it out-ranks what is worn there (higher
   rarity; more buffs and a bigger range make rarity a fair tiebreak),
   it is worn for the rest of the run. A run find it displaces goes to
   the backpack; a brought-in piece it displaces just stops applying
   (it is still safe in the save).
2. Otherwise it goes into the backpack if a slot is free.
3. If the backpack is full it swaps with the lowest-rarity stowed
   item when it beats it, and that item is left behind; if it doesn't
   beat anything the new piece is left behind. Either way the toast
   says so: `Backpack full - Common Boots left behind`.

Wearing is immediate so a chest is worth something even in a run that
dies at 14:59. Chests use `ScreenWrap` so one left behind cycles back
in front of the player like gems do (no despawn, no safe zone, per
the overwhelm principle).

### 7. A three-slot backpack, managed from the pause menu

`BACKPACK_SLOTS := 3`. The backpack is run-only: it holds pieces found
this run that aren't being worn, it starts every run empty, and
nothing brought in from the inventory can be stowed in it (brought-in
gear is already safe, so stowing it would only waste a slot). With
five wear slots that makes eight pieces the most a run can extract,
against the 8 to 12 chests a full run drops, so from the midgame on
every chest is a keep-or-leave decision rather than free loot.

It shows in two places. The HUD's collection grid gets a fourth row
of three boxes under the worn row (rarity frame, affixes in the
tooltip), so what you are carrying is always visible. The pause
menu, where the in-game Settings button already lives, gets a
**Backpack** button beside it opening the same `EquipBar` +
`ItemGridPage` pair the main menu's Inventory screen uses (see *The
Inventory screen* below) in run mode: the five worn pieces in the bar,
the three stowed in the grid, every cell with its affix lines in the
tooltip. Drag a stowed piece onto its equip slot to wear it (the
displaced run find takes the freed backpack cell; a displaced
brought-in piece just stops applying), drag a worn run find down into
a free backpack cell to stow it, drag anything stowed onto the bar's
**Drop** zone to leave it behind for good. Brought-in gear shows
greyed in the bar and can't be dragged. That is the manual override
for the automatic rule in decision 6, for the player who would rather
carry three Rares with luck rolls than one Epic with knockback.

Alternative, if "in the settings" meant the shop: a **Backpack**
permanent upgrade (3 levels, one slot each) instead of a fixed three.
One table entry and `get_backpack_slots()` in place of the constant.

### 8. Secured at 15:00, extracted from the menu, all or nothing

`EXTRACT_TIME := 900.0`, its own constant next to
`EnemySpawner.REAPER_TIME` so the two can drift apart later (secure
at 15:00, keep fighting to 20:00 for more loot is the obvious v2 hook
once the late game exists). When `game_time` crosses it,
`_secure_run_loot()` copies every run find, worn and stowed alike,
into the slot's `haul`, marks the slot dirty and flushes, and the HUD
toasts `Secured: 5 items`. `equipped` and `inventory` are untouched at
this point: the haul sits in the main menu's **Backpack** tab as
"what you got on your last run" until the player presses **Extract
All**, which moves it into `inventory`. If a run ends with the haul
still un-extracted, the next secured run appends to it, so skipping
the ceremony never loses anything.

`reset()` clears the run backpack and any worn run finds; `end_run()`
and `Player.die()` never touch `haul`. Dying (or quitting) before
15:00 deletes the run's finds on the spot (`_lose_run_loot()`: the
backpack empties, each slot goes back to the brought-in piece, the
HUD rows go blank) and nothing else is lost. Reaching 15:00 makes the
run a win whatever ends it afterwards (the Reaper, usually): the end
panel is the same panel titled **Victory!** with `Items secured: N`,
where a death before 15:00 shows **You Died** with `Items lost: N`.
The HUD carries a small kill counter top right with `Secure loot at
15:00` under it until it flips to `Loot secured`; securing toasts the
count (toasts queue, since the fifth passive slot unlocks in the same
tick).

### 9. Equipped gear is safe; duplicates stay in the bag

Gear equipped from the inventory is permanent progression like an
upgrade level: it is never lost on death (v1). A "bring it in at your
own risk" mode can come later as an opt-in. Outclassed pieces sit in
the inventory; the Equip bar's **Salvage** zone (the Salvage column
above) turns them into coins so the bag never needs a cap.

## The Inventory screen

Opened by a new **Inventory** button among the main menu's buttons.
It hides the title and main buttons like the other panels do
(`_set_menu_visible(false)`) and fills the screen: one scene,
`InventoryScreen.tscn`, instanced inside `MainMenu.tscn`, built from
the same textured theme as the rest of the menu.

**Tabs.** Five toggle buttons across the top in a `ButtonGroup`:
**Inventory** · **Key Items** · **Ingredients** · **Potions** ·
**Backpack**. The screen opens on Inventory every time. Below them is
one page area; picking a tab swaps the page the way
`RunSetup._show_page()` does. Back sits bottom-right and returns to
the menu. The Backpack tab carries a badge with the haul count while
the haul isn't empty, so a fresh haul is visible from the tab row.

**Inventory tab.** A scrolling grid of `ItemCell`s, eight columns, one
cell per armour piece in `inventory` (sorted rarity-descending, then
slot), each showing its icon in its rarity frame with a tooltip of the
name and affix lines. While this tab is active the **Equip** bar
slides in from the left edge (a 0.2 s tween on `position.x`, sliding
back out when the tab changes): the Knight's portrait
(`portrait_knight.tres`) with the five equip slots around it, Helmet
above, Armor and Shield either side, Gloves and Boots below, each an
`ItemCell` filtered to its slot; under them a **Salvage** zone and
the coins label.

**Drag and drop**, using Godot's built-in `_get_drag_data` /
`_can_drop_data` / `_drop_data` on `ItemCell` with
`set_drag_preview()` showing the icon under the cursor:

- Inventory cell onto its equip slot: equips. If the slot was filled
  the old piece returns to the grid, so a swap is one motion.
- Inventory cell onto the wrong slot: refused (`_can_drop_data` is
  false and the slot shows its "no" frame while the drag hovers).
  Every valid target lights up on `NOTIFICATION_DRAG_BEGIN`, so where a
  piece can go is obvious the moment the drag starts.
- Equip slot onto anywhere in the grid: unequips.
- Any cell onto the Salvage zone: pays the rarity's coins. Epic and
  Legendary ask first, through the `ConfirmOverlay` the Saves panel
  already uses for deletes.
- Without dragging: double-click an inventory cell to equip it into
  its slot, double-click an equip slot to unequip, right-click to
  salvage (which always asks first, whatever the rarity). Mouse
  only, like the rest of the menu.

**Backpack tab.** The same grid page fed by `haul`, with a line above
it, `From your last run - 5 items`, and one big **Extract All** button
that moves everything into `inventory`, clears `haul`, saves, and
toasts `5 items extracted`. Nothing in the haul can be equipped or
salvaged until it is extracted; that step is the point of the tab.
Empty state: `Nothing to extract. Survive to 15:00 with loot to bring
some back.`

**Key Items, Ingredients, Potions.** The same grid page component fed
by three new save keys, all empty in v1: the tabs exist now so the
screen never needs rebuilding when those systems land. Their intended
shape, so the save keys are right from the start: key items are
one-off flags (a totem key, a map unlock) shown as an icon with a
description; ingredients are stackable counts dropped by enemies, the
natural currency for the later "re-roll an affix" sink; potions are
stackable consumables carried into a run. Each tab's empty state says
in one line what will fill it.

The in-run HUD's worn and backpack rows and the pause menu's Backpack
panel use the same `ItemCell` and `EquipBar`, so a piece looks and
behaves the same in and out of a run.

## Data model

```gdscript
# GameManager.gd
const ARMOR_SLOTS := ["helmet", "armor", "boots", "shield", "gloves"]
const ARMOR_DEFS := {
    "helmet": {"display_name": "Helmet"},
    "armor":  {"display_name": "Armor"},
    "boots":  {"display_name": "Boots"},
    "shield": {"display_name": "Shield"},
    "gloves": {"display_name": "Gloves"},
}
# Rarity index is the item's "rarity" field; order matters (0 = Common).
# "color" is the frame and name colour, not a sprite tint.
const RARITY_DEFS := [
    {"name": "Common",    "weight": 60.0, "affixes": 1, "value_min": 5,  "value_max": 10, "color": Color.WHITE,             "salvage": 50},
    {"name": "Rare",      "weight": 30.0, "affixes": 2, "value_min": 12, "value_max": 20, "color": Color(0.45, 0.8, 1.0),  "salvage": 150},
    {"name": "Epic",      "weight": 9.0,  "affixes": 3, "value_min": 25, "value_max": 35, "color": Color(0.85, 0.5, 1.0),  "salvage": 500},
    {"name": "Legendary", "weight": 1.0,  "affixes": 4, "value_min": 40, "value_max": 50, "color": Color(1.0, 0.85, 0.35), "salvage": 1500},
]
# The affix pool. stat_label/format feed format_bonus() like PASSIVE_DEFS;
# "scale" turns the rolled whole-percent value into the number the
# getter adds (1.0 for a plain fraction, 2.0 for regen HP/s).
const AFFIX_DEFS := {
    "damage":       {"stat_label": "damage",       "format": "percent", "scale": 1.0},
    "max_hp":       {"stat_label": "max HP",       "format": "percent", "scale": 1.0},
    "luck":         {"stat_label": "luck",         "format": "percent", "scale": 1.0},
    "xp_gain":      {"stat_label": "XP gain",      "format": "percent", "scale": 1.0},
    "gold_gain":    {"stat_label": "gold gain",    "format": "percent", "scale": 1.0},
    "pickup_range": {"stat_label": "pickup range", "format": "percent", "scale": 1.0},
    "regen":        {"stat_label": "HP/sec",       "format": "flat",    "scale": 2.0},
    "duration":     {"stat_label": "duration",     "format": "percent", "scale": 1.0},
    "knockback":    {"stat_label": "knockback",    "format": "percent", "scale": 1.0},
    "attack_speed": {"stat_label": "attack speed", "format": "percent", "scale": 1.0},
    "move_speed":   {"stat_label": "move speed",   "format": "percent", "scale": 1.0},
}
# An item: {"id": ARMOR_DEFS key, "rarity": 0..3, "affixes": [{"stat": AFFIX_DEFS key, "value": int}]}
var inventory: Array = []        # persistent, unequipped
var equipped: Dictionary = {}    # persistent, slot -> item or null
var haul: Array = []             # persistent: secured at 15:00, waiting for Extract All
var key_items: Dictionary = {}   # persistent, id -> true      (empty in v1, tab exists)
var ingredients: Dictionary = {} # persistent, id -> count     (empty in v1, tab exists)
var potions: Dictionary = {}     # persistent, id -> count     (empty in v1, tab exists)
const BACKPACK_SLOTS := 3
var backpack: Array = []         # run-only: stowed finds, at most BACKPACK_SLOTS, cleared by reset()
var run_worn: Dictionary = {}    # slot -> item worn right now (equipped + worn finds)
# A worn find is told apart from brought-in gear by an in-memory
# "found": true flag on the item dictionary, stripped by _save_slot().
var armor_bonus: Dictionary = {} # affix key -> summed fraction across run_worn, rebuilt by _apply_armor()
```

Slot file gains six keys, read in `_apply_slot()` and written in
`_save_slot()` only:

```json
"inventory":   [{"id": "boots", "rarity": 1, "affixes": [{"stat": "move_speed", "value": 17}, {"stat": "luck", "value": 13}]}],
"equipped":    {"helmet": {"id": "helmet", "rarity": 3, "affixes": [{"stat": "damage", "value": 47}, {"stat": "max_hp", "value": 42}, {"stat": "luck", "value": 50}, {"stat": "regen", "value": 44}]}, "armor": null, "boots": null, "shield": null, "gloves": null},
"haul":        [{"id": "gloves", "rarity": 2, "affixes": [{"stat": "attack_speed", "value": 31}, {"stat": "xp_gain", "value": 28}, {"stat": "luck", "value": 33}]}],
"key_items":   {},
"ingredients": {},
"potions":     {}
```

Clamping on load (`_clamped_item()`, the one reader, applied to
`inventory`, `equipped` and `haul` alike): unknown ids dropped; rarity
clamped to `0..RARITY_DEFS.size()-1`; affixes with an unknown stat
dropped, duplicates dropped keeping the first, the list truncated to
the rarity's count, each value clamped into the rarity's range; an
equipped item whose id doesn't match its slot dropped. The three
future dictionaries are coerced to string keys with `true` / a
non-negative int, and otherwise kept as-is until their defs exist.
Note that retuning a rarity's range later re-clamps every saved item
on its next load, which is the intended way to rebalance old loot.
`slot_summary()` adds an `items` count for the Saves panel.

Stat application: `_apply_armor()` rebuilds `armor_bonus` by summing
`value / 100.0 * scale` per stat over `run_worn`; it runs in `reset()`
and after every chest. The getters read `armor_bonus.get(key, 0.0)`.
Armour never shares a var with a passive: `_apply_passive()` writes
the passive's stat with `set()`, so the next passive level-up would
overwrite an armour bonus stored there.

Getter changes (the only places the maths lives):

```gdscript
func get_damage_mult():        return (1.0 + get_permanent_bonus("damage")) * (damage_mult + _armor("damage"))
func get_xp_mult():            return (1.0 + get_permanent_bonus("xp_gain")) * (xp_mult + _armor("xp_gain"))
func get_coin_mult():          # existing line, + _armor("gold_gain")
func get_duration_mult():      # existing line, + _armor("duration")
func get_knockback_mult():     # existing line, + _armor("knockback")
func get_cooldown_mult():      return 1.0 / (1.0 + get_permanent_bonus("cooldown") + attack_speed_bonus + _armor("attack_speed"))
func get_health_regen_rate():  # existing line, + _armor("regen")   (already in HP/s via scale 2.0)
func get_luck_mult():          return 1.0 + get_permanent_bonus("luck") + luck_bonus + _armor("luck")
func get_max_hp():             return (100.0 + max_hp_bonus) * (1.0 + _armor("max_hp"))
func get_speed_mult():         return speed_mult + _armor("move_speed")
func get_pickup_range_mult():  return pickup_range_mult + _armor("pickup_range")
```

`Player.gd` switches to `get_max_hp()` / `get_speed_mult()`;
`XPGem.gd`, `CoinPickup.gd`, `MagnetPickup.gd`, `GoldDreamPickup.gd`
switch from `pickup_range_mult` to `get_pickup_range_mult()`.

Display: an item's name is its slot's `display_name` in the rarity's
colour (`Steel Armor` reads as "Armor" in purple; the material is in
the sprite). An affix line is `format_bonus()` on the AFFIX_DEFS entry
with the scaled value, so `+47% damage` and `+0.9 HP/sec` come out of
the same code the shop uses. The inventory list shows name, rarity
and one line per affix; the HUD armour boxes show the icon in a
rarity frame and list the affixes in a tooltip.

## Code changes by file

- `scripts/GameManager.gd`: the defs above; `luck` in
  `PERMANENT_UPGRADE_DEFS`; `four_leaf_clover` in `PASSIVE_DEFS` (stat
  `luck_bonus`); `roll_rarity(min_rarity)`, `roll_affixes(rarity)`,
  `roll_armor(min_rarity)` (picks the slot too); `_clamped_item()`;
  `_armor(key)`, `_apply_armor()`; `stow_or_wear(item)` (decision 6's
  rule), `wear_from_backpack(index)`, `stow_worn(slot)`,
  `drop_from_backpack(index)`, `_secure_run_loot()`, `extract_all()`,
  `equip(item)`, `unequip(slot)`, `salvage(item)`; the getters above;
  `BACKPACK_SLOTS`; `EXTRACT_TIME` and `_check_extraction()` called
  from `_process()` next to `_check_unlocks()`; `reset()` empties
  `backpack` and seeds `run_worn` from `equipped`; the save
  reader/writer/summary; chest throttle state (`chest_on_field`,
  `last_chest_time`) behind `try_drop_chest(pos)` so `Zombie.die()`
  stays one line.
- `scripts/Player.gd`: `get_max_hp()` and `get_speed_mult()` instead of
  the raw stats. No damage changes in this version.
- `scripts/XPGem.gd`, `CoinPickup.gd`, `MagnetPickup.gd`,
  `GoldDreamPickup.gd`: `get_pickup_range_mult()`.
- `scripts/Zombie.gd`: `die()` calls `GameManager.try_drop_chest(global_position)`;
  Magnet / Gold Dream rolls multiply by `get_luck_mult()`.
- `scripts/AncientKeeper.gd`: `_drop_loot()` also spawns a chest with
  `min_rarity = 1`.
- `scenes/Chest.tscn` + `scripts/Chest.gd`: Area2D in a `chests` group,
  closed/open AnimatedSprite2D, `min_rarity` export, contact opens,
  `roll_armor()`, spawns the item reveal, calls `stow_or_wear()`,
  `ScreenWrap` like a gem.
- `scenes/ItemCell.tscn` + `scripts/ItemCell.gd`: one item box, used
  everywhere a piece is shown: a `WeaponIcon` child, the rarity frame
  (a theme variation per rarity next to `IconSlot` / `IconSlotLocked`),
  the name + affix tooltip, and the drag source / drop target
  overrides. `slot_filter` (an equip slot accepts one id), `mode`
  (inventory / equip / haul / run-worn / run-stowed, which decides what
  drags where), the double-click and right-click fallbacks.
- `scenes/EquipBar.tscn` + `scripts/EquipBar.gd`: the slide-in bar:
  portrait, five slot cells, the Salvage zone (Drop zone in
  `run_mode`), coins label, the tween in/out.
- `scenes/ItemGridPage.tscn` + `scripts/ItemGridPage.gd`: title line,
  scrolling grid of `ItemCell`s built from a list, empty-state label,
  optional action button (Extract All on the Backpack tab).
- `scenes/InventoryScreen.tscn` + `scripts/InventoryScreen.gd`: the
  five tabs in a `ButtonGroup`, page switching, the Backpack badge,
  Back; owns one `EquipBar` and five `ItemGridPage`s.
- `scripts/HUD.gd` / `scenes/HUD.tscn`: a third grid row of 5 worn
  `ItemCell`s (fits the 6-per-row grid with one box spare) and a
  fourth of 3 backpack cells; a `secure 15:00` note by the clock until
  it fires; found, left-behind and secured toasts reuse `unlock_toast`
  (found toast gets affix lines); the pause panel's **Backpack** button
  opening an `EquipBar` + `ItemGridPage` in run mode; game-over panel
  line.
- `scripts/WeaponIcon.gd`: `configure_item(item)`: an `ARMOR_TEXTURES`
  table of slot -> per-rarity texture (four `AtlasTexture` slices of
  the DG sheet for boots and shields, four ElvGames files for helmets
  and armour, the one glove four times), the same `.tres` slice
  approach the passive icons already use.
- `assets/ui/`: the new `icon_*.tres` slices (boots x4, shield x4,
  gloves), same folder as `icon_lucky_coin.tres` and friends.
- `scripts/MainMenu.gd` / `scenes/MainMenu.tscn`: the **Inventory**
  button and the instanced `InventoryScreen`, shown and hidden like
  the other panels; the `ConfirmOverlay` reused for Epic+ salvage.
- `README.md`, `TODO.md`: document the systems and the tuning numbers.
- `build-branches`: the new preloads (the ElvGames helmet/armour files,
  the DG item sheet, chest sheets) must be copied into the trimmed
  `allassets/` before the next export, or the build ships without them
  (dynamic-load gap). Use `preload`, never `load`, so the export
  filter can trace them.

## Phases

1. **Data and persistence** (GameManager only): defs, the roll
   functions, `_clamped_item()`, inventory/equipped in the slot file,
   `_apply_armor()` and every getter, Player and pickup readers moved to
   the getters. Testable headless before any scene exists. **Done
   2026-09-08**, including `equip` / `unequip` / `salvage` /
   `extract_all`, the `haul` and future-tab keys, `slot_summary().items`,
   and Player re-syncing max HP downward each frame (its `_ready()` runs
   before `Main.gd`'s `reset()`, so it can briefly see last run's armour).
   `get_luck_mult()` reads the passive and armour terms only until phase
   2 adds the permanent upgrade.
2. **Luck**: the permanent upgrade, the passive, Magnet/Gold Dream
   hooked to it. Small and independent of 3. **Done 2026-09-08**: the
   Luck upgrade (Damage's costs) sits after Cooldown in the shop, the
   Four-Leaf Clover passive uses the clover frame of the Pixel VFX
   `Luck_Up` sheet (`assets/ui/icon_four_leaf_clover.tres`), and the
   rarity roll became the two-anchor table above (base 94/5/1/0, max
   60/29/15/1, `LUCK_MAX_MULT = 2.0`, linear slide, extrapolates).
3. **Chest**: scene, drop roll and throttle, opening, reveal, the
   stow-or-wear rule and the backpack, Keeper's guaranteed chest, HUD
   worn and backpack rows with rarity frames, found and left-behind
   toasts, the icon table and `.tres` slices. **Done 2026-09-08**:
   `Chest.tscn`/`Chest.gd` (screen-wraps like a gem, lingers open for
   0.8 s once the run resumes), `ChestReveal.tscn`/`.gd` +
   `ChestRevealFx.gd` (the paused reveal, replacing the toasts),
   `ItemCell.tscn`/`.gd` (rarity frame + tooltip, no drag yet),
   `WeaponIcon.configure_item()` with 17 slices in `assets/ui/armor_*.tres`
   and `chest_frames.tres`, `GameManager.try_drop_chest / spawn_chest /
   open_chest / close_chest / stow_or_wear / wear_from_backpack /
   stow_worn / drop_from_backpack`, `is_paused_for_chest`, and the two
   HUD rows. Stowing a worn find puts the brought-in piece for that
   slot back on.
4. **Securing**: `EXTRACT_TIME`, `_secure_run_loot()`, `haul` in the
   save, secured toast, game-over panel line. **Done 2026-09-08**, plus
   the user's additions: `_lose_run_loot()` on an early death, the
   Victory / You Died panel with the items line, the top-right kill
   counter and secure note, and the toast queue.
5. **Inventory screen**: `ItemCell`, `EquipBar`, `ItemGridPage`,
   `InventoryScreen` with the five tabs, drag and drop, Salvage with
   confirmation, the Backpack tab with Extract All, the three empty
   tabs, the menu button. The largest phase; `ItemCell` + `EquipBar`
   first since everything else is built from them. **Done
   2026-09-08**: `ItemCell.gd` grew `mode` / `slot_filter`, the drag
   hooks, `accepts()`, `drag_payload()`, the green / dimmed drag look
   and the double-click / right-click signals; `ItemGridPage.tscn`
   (title, action button, 10-column grid, empty line, page-wide drop
   target), `EquipBar.tscn` (portrait, five filtered slots with
   captions, the Salvage zone as a drop target on the bar, coins,
   slide tween), `InventoryScreen.tscn` (five toggle tabs in a
   ButtonGroup, Backpack badge, pages shift left when the bar is out,
   Back). `MainMenu` gained the Inventory button (the four main
   buttons are 84 px / 56 pt now) and a generic `ask_confirm(message,
   yes_text, on_confirm)` that slot deletes and Epic+ salvages share.
6. **Run-mode reuse and docs**: the pause menu's Backpack panel and the
   HUD rows on the shared cells, Saves panel item count, README/TODO,
   build-branches sync. **Done 2026-09-08**: `RunBackpackPanel.tscn`
   (an `EquipBar` with `run_mode = true` - brought-in gear greyed and
   fixed, finds draggable, a Drop zone - beside an `ItemGridPage` of
   three `run_stowed` cells padded via `populate(..., min_cells)`,
   gated by `can_accept` so a full backpack refuses drops), opened by
   a Backpack button in the pause panel, Escape steps back;
   `GameManager.discard_worn(slot)` for leaving a worn find behind;
   the Saves panel's fourth line `Items: N`; the README's armour /
   chest / extraction / inventory write-up and structure lists; a
   sync script that copies changed sources and every referenced
   `allassets/` file into `build-branches/`.

Each phase is a commit on its own after a harness pass; 1 and 2 could
land together, as could 3 and 4.

## Harness checks before committing

- Rarity roll: 100k rolls at Luck x1, x2 and x3 land within 1% of the
  two anchor tables and their extrapolation; `min_rarity` never
  returns below the floor, and a Rare floor at base luck never yields
  Legendary; the slot pick is within 1% of a fifth each.
- Affix roll: 100k pieces per rarity carry exactly the rarity's count,
  never a duplicate stat, every value inside the range; each of the 11
  stats appears within 1% of 1/11 of the draws; the mean value at Luck
  x1 sits at the range midpoint and at Luck x2 two thirds of the way up.
- Save round trip: write a slot with inventory + equipped, reload,
  equal; a hand-edited file with a bad id, rarity 9, six affixes on a
  Common, a duplicate stat, a value of 999 and a helmet in the boots
  slot loads as the clamped version.
- Stats: a worn Legendary helmet with damage 47 / max_hp 42 / luck 50
  / regen 44 gives `get_damage_mult()` of (1+perm) x (1.0+0.47), 142
  max HP at run start, luck x1.5, +0.88 HP/s; two pieces both rolling
  damage add; Four-Leaf Clover Lv5 + Luck Lv5 with no armour gives
  exactly x2.
- Backpack: a fourth find with three stowed swaps out the lowest
  rarity only when it beats it; a find that out-ranks a worn run find
  wears and pushes the old one down; a find that out-ranks brought-in
  gear wears it and the brought-in piece is still in `equipped` on
  disk; nothing brought in can ever be stowed or dropped; the pause
  panel's drags (stowed onto a slot, worn find into a free cell,
  stowed onto Drop) keep counts at 5 worn + 3 stowed at most.
- Securing: advance `game_time` past 900 wearing one run find over a
  brought-in helmet with three stowed: the slot file's `haul` has all
  four with every affix intact and `equipped` / `inventory` are
  unchanged; die at 899 with the same load, `haul` unchanged; a second
  secured run appends rather than replaces; `reset()` empties the run
  backpack, clears worn finds and re-wears `equipped`.
- Inventory screen, headless (calling the drop handlers directly):
  `_can_drop_data` is false for a helmet over the boots slot and true
  over the helmet slot; dropping onto a filled slot swaps and the old
  piece is back in `inventory`; an equip cell dropped on the grid
  unequips; Salvage pays the table's coins and routes Epic+ through the
  confirm overlay; Extract All empties `haul` into `inventory`, clears
  the badge and writes the slot; the screen opens on the Inventory tab
  every time; the Equip bar is on-screen only while that tab is active;
  haul cells refuse every drag.
- Inventory screen, windowed: a real mouse drag
  (`InputEventMouseButton` + `InputEventMouseMotion` through
  `Input.parse_input_event`) from a grid cell to its slot equips it,
  the preview follows the cursor, valid slots light up on drag start,
  the wrong slot shows its "no" frame; double-click and right-click
  fallbacks do what the drags do.
- Chest throttle: 10k kills in one frame drop exactly one chest; a
  second only after 45 s and only once the first is opened.
- Windowed: the chest wraps round the screen edge like a gem, the open
  animation plays once, the reveal icon reaches the player, the found
  toast lists the right affix lines, all five slot icons at all four
  rarities draw legibly in the grid at HUD scale with the right frame
  colour and sprite variant.

## Implementation handoff (what phases 5 and 6 build on)

Everything below exists and is harness-verified as of 2026-09-08.
Nothing is committed yet; commit only when the user asks, never push.

**GameManager.gd (autoload `GameManager`)**
- Defs: `ARMOR_SLOTS` (helmet, armor, boots, shield, gloves),
  `ARMOR_DEFS[id].display_name`, `RARITY_DEFS[i]` with `name weight
  weight_max affixes value_min value_max color salvage coins`,
  `AFFIX_DEFS[key]` with `stat_label format scale`, `LUCK_MAX_MULT`,
  `BACKPACK_SLOTS = 3`, `CHEST_DROP_CHANCE`, `CHEST_MIN_INTERVAL`,
  `EXTRACT_TIME = 900`.
- Persistent (slot file, read by `_apply_slot()`, written by
  `_save_slot()`): `inventory: Array`, `equipped: Dictionary` (slot ->
  item or null, always all five keys), `haul: Array`, `key_items`,
  `ingredients`, `potions` (Dictionaries, empty). An item is
  `{"id", "rarity", "affixes": [{"stat", "value"}]}`; run finds carry an
  in-memory `"found": true` that `_clean_item()` strips.
- Run state: `backpack: Array`, `run_worn: Dictionary`, `armor_bonus`,
  `luck_bonus`, `run_secured`, `secured_count`, `lost_count`,
  `is_paused_for_chest`, `last_chest_time`.
- Menu-side data ops (each writes the slot): `equip(item) -> bool`
  (moves an inventory piece into its slot, swaps the old one back),
  `unequip(slot) -> bool`, `salvage(item) -> int` (coins paid, 0 if
  not in the inventory; flat, no Gold Gain), `extract_all() -> int`
  (haul -> inventory). Display: `item_name(item)`, `rarity_name(item)`,
  `affix_text(affix)` ("+47% damage", "+0.9 HP/sec"),
  `item_tooltip(item)` (name line + affix lines).
- Run-side: `roll_armor(min_rarity)`, `stow_or_wear(item) -> {outcome,
  displaced, left}`, `wear_from_backpack(i)`, `stow_worn(slot)`,
  `drop_from_backpack(i)`, `try_drop_chest(pos)`, `spawn_chest(pos,
  min_rarity)`, `open_chest(item)` / `close_chest()`,
  `run_find_count()`, `_check_extraction()`.
- Signals: `chest_opened(item, outcome)`, `haul_secured(count)`,
  plus the older `unlock_earned`, `player_died`, `level_up_choices`.
- Getters every reader uses: `get_luck_mult()`, `get_max_hp()`,
  `get_speed_mult()`, `get_pickup_range_mult()` and the existing
  `get_damage_mult()` family; `_armor(key)` reads `armor_bonus`.

**Scenes and scripts**
- `scenes/ItemCell.tscn` + `scripts/ItemCell.gd`: Panel (theme
  variation `IconSlot`, 48x48 min) with a `WeaponIcon` child;
  `set_item(item)` (empty dict = blank), `item`, rarity frame drawn in
  `_draw()`, `tooltip_text` from `item_tooltip()`. No drag yet - phase
  5 adds `_get_drag_data` / `_can_drop_data` / `_drop_data`, a
  `slot_filter` and a `mode`.
- `scripts/WeaponIcon.gd`: `configure(id, dimmed)` for weapons and
  passives, `configure_item(item)` for armour via `ARMOR_TEXTURES[slot][rarity]`
  (`assets/ui/armor_<slot>_<rarity>.tres`, `armor_gloves.tres`),
  `set_blank()`.
- `scenes/Chest.tscn` (`Chest.gd`, group `chests`, `min_rarity`,
  `open()`), `scenes/ChestReveal.tscn` (`ChestReveal.gd` +
  `ChestRevealFx.gd`; `play(item, outcome)`, `advance()`, `finish()`),
  `assets/ui/chest_frames.tres` (SpriteFrames `closed` / `open`).
- `scenes/HUD.tscn` / `HUD.gd`: `weapon_grid` (GridContainer, 6
  columns, rows: weapons, passives, worn `ItemCell`s in `worn_cells`
  by slot, backpack cells in `backpack_cells`), `chest_reveal`,
  `kills_label`, `secure_label`, `unlock_toast` via `_show_toast()`
  (queued), `game_over_panel` with `GameOverLabel` / `SurvivedLabel` /
  `DefeatedLabel` / `ItemsLabel`, `pause_panel` with Resume / Settings
  / Quit buttons (phase 6 adds a Backpack button and panel here).
- `scenes/MainMenu.tscn` / `MainMenu.gd`: panels are children shown
  one at a time with `_set_menu_visible(false)` hiding the title and
  `$MainButtons`; `ConfirmOverlay/ConfirmPanel` with `MessageLabel`,
  `CancelButton`, `ConfirmButton` (used for slot deletes);
  `assets/ui/MenuPanelTheme.tres` (32px body) sits on each panel,
  `AppTheme.tres` further up; `portrait_knight.tres` is the Knight's
  portrait.

**Verification pattern**
- Godot: `C:/Users/stela/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe`,
  run from the project root with `--headless --path . res://scenes/_Verify.tscn`
  (a Node scene whose script runs checks in `_ready()` and
  `get_tree().quit(fails)`); output through a log file and `grep`,
  since the shell hook truncates long output. Save-touching checks
  point `GameManager.active_slot` at 99, `_load_slot(99)`, and delete
  `save_slot_99.json` at the end before reloading the real slot.
- Windowed captures: same pattern without `--headless`, instancing
  `HUD.tscn` or `MainMenu.tscn`, then `await RenderingServer.frame_post_draw`
  and `get_viewport().get_texture().get_image().save_png(path)`.
- Harness files are deleted before the phase is called done; nothing
  named `_Verify*` is ever committed.
- GDScript 4 traps met so far: `value == true` throws when `value` is
  a JSON number (type-check first); the Player's `_ready()` runs
  before `Main.gd`'s `reset()`; heredocs through the shell hook can
  mangle, so files are written with the Write tool.

## Later, not now

- Content for the Key Items, Ingredients and Potions tabs (their save
  keys and pages exist from phase 5; the systems don't).
- Extract All offering to auto-equip anything that out-ranks what is
  worn, and dragging straight from the Backpack tab onto the Equip
  bar.
- Extract-or-keep-going choice once the late game runs past 15:00.
- Risk mode: equipped gear can be lost on death for a Luck bonus.
- Backpack size as a shop upgrade instead of a fixed three (decision
  7's alternative).
- Re-roll one affix for coins (a natural coin sink once the shop is
  maxed).
- Defensive affixes (damage reduction, block chance) added to the pool.
- `ARMOR_STAT_CAP` if stacked Legendaries prove too much.
- Set bonuses (all five steel, all five Legendary).
- A sixth slot (amulet or cloak) if a jewellery pack is ever imported;
  the grid row has one box spare.
- A chest pointer on the HUD (TotemPointer already does this for one
  target; generalise it to the nearest chest).
- Elite enemies with a guaranteed chest (ties into the elite-variants
  TODO).
