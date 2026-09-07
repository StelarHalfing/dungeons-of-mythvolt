# The Dungeons of Mythvolt (Godot 4.3)

A Vampire Survivors–style auto-battler survival game. Move with
WASD or arrow keys. The Knight starts with the Sword (a slash at the
nearest enemy that flies on and cleaves through whatever it passes -
`starting_weapon` in `CHARACTER_DEFS`); kill Goblins to drop XP gems,
and level up to
pick from 3 weapon choices — leveling up a weapon you already own
boosts its damage/size/speed, and picking the Forcefield for the
first time unlocks it (an aura that ticks damage to enemies around
you). Don't like the three on offer? The Reroll button under them
swaps in new ones: the first reroll of a run is free, the next costs
50 coins and the price doubles with every reroll after that
(`GameManager.reroll_upgrades()`; the counter resets each run).
Once every slot is full and everything you hold is maxed, level-ups
offer two consolation picks instead of nothing: a Small Heal (25% of
max HP) or a Coin Bonus (+25 gold) - `FALLBACK_DEFS` in
`GameManager.gd`, applied by `_apply_fallback()`; rerolls and bans
don't apply to that panel.
Every 10th kill also drops a coin — coins persist across runs
(and across closing the game) and can be spent in the main menu's
Upgrades screen on permanent bonuses. Starting at 1:30 into a run, a
Minotaur — a slow, 300 HP enemy with a periodic dash attack — shows
up in place of a Goblin roughly once every 25 spawns, and drops a
red gem worth 5 XP instead of the usual green one. Survive as long
as you can.

## How to run
1. Open Godot 4.3+ (or later 4.x — should still work).
2. "Import" this folder, selecting `project.godot`.
3. Press F5 (or the Play button). `MainMenu.tscn` is set as the main scene.

## Project structure

```
scenes/
  MainMenu.tscn     - entry point: Play / Settings / Upgrades / Saves (+ Quit, Unlocks)
  RunSetup.tscn     - character select then map select (two SelectPage.tscn
                      instances of SelectCard.tscn cards), then Main.tscn
  Main.tscn        - root gameplay scene: Player + EnemySpawner + HUD
  Player.tscn       - CharacterBody2D, movement + auto-fire weapon
  Goblin.tscn       - Area2D, base enemy: chases player, contact damage
  Minotaur.tscn     - Area2D extending Goblin: 300 HP, half speed, dash attack
  Projectile.tscn   - Area2D, fired at nearest enemy
  XPGem.tscn        - Area2D, magnets to player, grants 1 XP (green)
  RedXPGem.tscn     - same script as XPGem, Minotaur's drop, grants 5 XP (red)
  CoinPickup.tscn   - Area2D, magnets to player, grants a coin
  DamageNumber.tscn - floating text popup on hit, drifts up and fades
  IconSlot.tscn     - one box in the run-collection grid: border + icon, dimmed until acquired
  HUD.tscn          - HP/XP/coin display, weapon/passive collection grid,
                       level-up panel, pause panel, game over panel
scripts/
  GameManager.gd    - autoload singleton: XP, level, run timer,
                       weapon stats (WEAPON_DEFS), kill count, coins
                       and permanent upgrades (PERMANENT_UPGRADE_DEFS),
                       save/load to disk
  MainMenu.gd, Player.gd, ForcefieldWeapon.gd, Goblin.gd, Minotaur.gd, Projectile.gd, XPGem.gd, CoinPickup.gd, DamageNumber.gd, EnemySpawner.gd, IconSlot.gd, WeaponIcon.gd, Main.gd, HUD.gd
```

`MainMenu.tscn` is the scene Godot boots into (`run/main_scene` in
`project.godot`). **Play** opens `RunSetup.tscn` (character select,
then map select - built from `CHARACTER_DEFS`/`MAP_DEFS` in
`GameManager.gd`), whose Start button loads `Main.tscn` via
`change_scene_to_file`; **Saves** opens the save-slot picker (see
below); **Settings** exposes a master volume slider,
a damage-numbers toggle, and a fullscreen toggle (also present in
the in-run pause menu's Settings); **Upgrades** lets you spend saved
coins on permanent bonuses (see below). **Quit** sits as its own
button in the bottom-left corner rather than in the main button
stack, and calls `get_tree().quit()`; **Unlocks** mirrors it in the
bottom-right corner and opens a panel listing every `UNLOCK_DEFS`
achievement (condition, reward, and Locked/Unlocked for the active
save - rows built by `MainMenu._build_unlock_rows()`).

All visuals are drawn with `_draw()` as plain colored circles
(blue = player, red = enemy, yellow = projectile, green = gem) so
there are zero external art dependencies — swap in real sprites by
replacing the `_draw()` calls with a `Sprite2D` child.

## Design notes / why it's built this way

- **Enemies and projectiles are `Area2D`, not `CharacterBody2D`.**
  They don't need physics collision *response* (nothing needs to
  physically push anything else), just overlap detection — this is
  much cheaper and scales to far more enemies on screen than
  `move_and_slide()` per enemy.
- **Weapons live in `GameManager.weapons`**, not on the Player.
  `WEAPON_DEFS` is a static table (base stats + per-level flat
  gains); `weapons[id]` holds the *live* stats for an owned weapon
  (`level`, `damage`, `size`, `speed`). Leveling up just adds the
  `gain` amounts to the current stats — no min/max caps yet. Every
  weapon starts a run at `level == 0` ("not yet owned") except the
  selected character's `starting_weapon` (`CHARACTER_DEFS`; the
  Knight's is the Sword), which `_init_weapons()` sets to level 1;
  picking an unowned weapon in the level-up screen is what sets it
  to level 1 and activates it.
  - **Laser Pistol** (`Player.try_fire()`): `damage` per hit, `size`
    is the projectile's radius (collision + visuals), `speed` is
    projectile travel speed. Fire rate is a fixed 0.6s cooldown —
    nothing currently upgrades attack speed. It also has a
    `projectile_count` stat (not in `gain` - handled as a special
    case in `level_up_weapon()`) that goes up by 1 every 3rd level
    (3, 6, 9, ...). Each shot targets a *different* nearby enemy:
    `try_fire()` sorts enemies by distance and fires one projectile
    per target, up to `projectile_count` (fewer if there aren't that
    many enemies around).
  - **Forcefield** (`ForcefieldWeapon.gd`, a child `Area2D` of
    Player): `damage` per tick to everything overlapping it,
    `size` is the ring's radius, `speed` is ticks-per-second
    (`1.0 / speed` = seconds between ticks). No projectile count -
    the every-3-levels bonus is exclusive to the Laser Pistol.
  - **Sword** (`SwordCaster.gd`, a child of Player): once its
    cooldown is up it waits for the nearest enemy to come within the
    slash's depth (`size`, its reach, plus its flight), then spawns a
    `Slash.gd` into the world aimed at it: a 110-degree crescent that
    sweeps open, flies forward for its `duration` stat (seconds, at
    450 px/s, times `get_duration_mult()`) and fades, damaging each
    enemy inside its fan once as it passes (a geometric check against
    the enemies group, like Fireball's blast) - so it cleaves through
    a line of enemies, ~150px deep at level 1 and ~350px at 12 before
    any Duration bonus. `speed` is swings per second, and
    `projectile_count` (+1 every 3rd level) adds a slash at the
    next-nearest enemy in depth.
  - **Duration** is a stat like damage: `get_duration_mult()` is
    1 + the permanent Duration upgrade (+10%/level to +50%) + the
    Hourglass passive (+10%/level to +50%), ADDED like gold gain
    rather than multiplied like damage, so both maxed is exactly x2.
    It stretches everything with a duration - the sword slash's flight
    and the Tornado's lifetime.
- **Icons come from one script.** `WeaponIcon.gd` is a `Control`
  keyed by an `icon_id` string (the exact keys used in
  `GameManager.weapons`/`.passives`): ids in its `ICON_TEXTURES`
  table draw that sprite (every weapon and passive except Tornado,
  which has no fitting art and keeps a drawn glyph), `""` or an
  unknown id draws the lock glyph, and `set_blank()` draws nothing.
  It is reused as the icon inside each level-up choice button
  (`HBoxContainer` wrapping an `Icon` + the wrapped-text `Label`,
  same click-through `mouse_filter = 2` trick as the label itself)
  and inside `IconSlot.tscn` for the collection grid below.
- **The collection grid** (`WeaponGrid` in `HUD.tscn`) is built by
  `HUD._build_collection_grid()`: `GameManager.GRID_SLOTS_PER_ROW`
  (6) `IconSlot.tscn` boxes per row. On the top row the first
  `get_weapon_slots()` boxes are open and the rest locked; the bottom
  row is the same for passives. Open boxes show the run's pickups in
  the order they were taken (`GameManager.weapon_order` /
  `passive_order`, refreshed every frame by
  `_refresh_collection_grid()`); a box past the last pickup is just
  empty - a free slot. Locked boxes use the darker `IconSlotLocked`
  frame and the lock glyph. Runs start with
  `BASE_WEAPON_SLOTS`/`BASE_PASSIVE_SLOTS` (2 each, so four locks per
  row) and each level of the permanent Weapon Slots / Passive Slots
  upgrades opens one more, to four; the boxes beyond that come from
  `UNLOCK_DEFS`, earned in play and saved with the slot - today a
  fifth weapon slot for surviving 10:00 in a single run and a fifth
  passive slot for 15:00
  (`_check_unlocks()` awards each the moment the clock gets there, the
  HUD rebuilds the grid so the lock vanishes mid-run and shows a
  banner under the timer, and `_save_slot()` writes it at once). A slot is a
  real cap: `_upgrade_pool()` only offers a weapon or passive you
  don't own yet while a slot is free for it, so with two base slots a
  run holds the Laser Pistol plus one more weapon until the upgrades
  are bought. Adding a weapon or passive is a def entry plus an
  `ICON_TEXTURES` entry.
- **No custom Input Map actions** — movement reads raw key state
  (`Input.is_key_pressed`) so there's nothing to misconfigure in
  Project Settings. If you want gamepad support, this is the first
  place to add it.
- **Difficulty ramps via spawn rate**, not per-enemy stats scaling
  over time. Each Goblin/Minotaur always spawns at its scene's fixed
  base `max_hp`/`speed` — the only thing that changes with time is
  how often `EnemySpawner.gd` spawns one
  (`initial_interval - game_time * 0.01`, floored at 0.15s).
- **Minotaur extends Goblin via GDScript inheritance**
  (`extends "res://scripts/Goblin.gd"`), not a from-scratch script.
  `Goblin.gd` splits its behavior into small overridable pieces
  (`_move_toward_player()`, `_update_contact_damage()`,
  `_drop_loot()`) specifically so `Minotaur.gd` can replace movement
  with a dash state machine (`CHASE` → `TELEGRAPH` → `DASH`, calling
  `super._ready()` to still get the base HP/group-membership setup)
  and replace `_drop_loot()` to spawn a `RedXPGem` instead, while
  reusing `take_damage()`/`die()`/contact-damage/damage-numbers/coin-
  drops unchanged. `EnemySpawner.gd` decides which scene to
  instantiate per spawn: Goblin by default, Minotaur once
  `game_time >= 90.0` (1:30) and `enemies_spawned % 25 == 0`.
  `XPGem.gd` similarly got `gem_color`/`gem_radius` exports so
  `RedXPGem.tscn` could reuse the exact same script instead of a
  near-duplicate one.
- **Coins and permanent upgrades are real save data**, not just
  in-memory state. `GameManager.coins`, `.permanent_upgrades`,
  `.show_damage_numbers`, `.is_fullscreen` and `.fps_cap` are
  deliberately left untouched by `reset()` (unlike XP/level/weapons,
  which are per-run) and persist across launches as JSON (via
  `FileAccess` + `JSON.stringify`), split into two kinds of file:
  preferences plus the active slot number in `user://settings.json`,
  and progression (coins, upgrade levels, earned unlocks) in one file per save slot,
  `user://save_slot_N.json` (N = 1..`SLOT_COUNT`, 3 slots). Settings
  are written the moment they change - through setters like
  `set_fullscreen()`/`set_show_damage_numbers()`, not direct field
  assignment, so the save actually happens. Coins only mark the slot
  dirty (`add_coins()`), and the slot is written at most once a second
  plus on death, run start, slot switch/delete, purchase and quit, so a
  Magnet pulling in dozens of coins in one tick doesn't do dozens of
  file writes. Everything is reloaded once in `GameManager._ready()`;
  loaded values are type-checked and clamped (a hand-edited or
  half-written file can't put an upgrade above `max_level` or break
  the menu). The pre-slot `user://save_data.json` is migrated into
  `settings.json` + slot 1 the first time this build runs (gated on
  `settings.json` not existing yet) and then left in place untouched
  as a backup. `PERMANENT_UPGRADE_DEFS` follows the same
  static-table-plus-live-state pattern as `WEAPON_DEFS`: each entry
  has a `costs` array (cost of each level), a `max_level`, and the
  `stat_label`/`format` keys `format_bonus()` uses to write the bonus
  ("+10%", "+0.2" or "+1", the same formatter the level-up cards use for
  passives). Every 10th kill (`Goblin.gd`, checking
  `enemies_defeated % 10` - Minotaur inherits this unchanged) drops a
  `CoinPickup` — same magnet/pickup code as `XPGem`, just paying out
  `GameManager.add_coins()` instead of `add_xp()`.
  - There are nine permanent upgrades right now, all `level *
    per_level_value` via `get_permanent_bonus(id)`. Five are stat
    bonuses: Health
    Regeneration (+0.2 HP/sec/level, applied in `Player.gd`'s
    `_physics_process()` via `get_health_regen_rate()`, which also adds
    the run-only Vitality Elixir passive), Damage (+10%/level, flat/
    additive not compounding, capped at +50% at level 5 - folded into
    `get_damage_mult()`, the one multiplier every weapon applies),
    XP Gain (same +10%/level curve, folded into `get_xp_mult()` next to
    the Wisdom Orb passive) and Gold Gain (same curve again, folded
    into `get_coin_mult()` next to the Lucky Coin passive - but those
    two ADD rather than multiply, so both maxed is exactly x2: two
    gold per coin, applied in `add_coins()` with the same integer
    hundredths carry `add_xp()` uses), and Duration (same curve,
    folded into `get_duration_mult()` next to the Hourglass passive -
    see the Duration note above). Damage's, XP Gain's, Gold Gain's
    and Duration's `costs` are exactly double Health Regeneration's
    (`[200, 400, 1000, 2000, 5000]` vs `[100, 200, 500, 1000, 2500]`).
    Four more are whole-number perks
    (`"format": "count"`): for the level-up panel, two levels each at
    1000 then 5000 coins, Rerolls (+1 free reroll per run on top of
    the one everyone gets, via `get_free_rerolls()`) and Bans (+1 ban
    per run; there are none without it, via `get_max_bans()`); and
    for the collection grid, two levels each at 1000 then 2500 coins,
    Weapon Slots and Passive Slots (+1 open slot per run each, from 2
    up to 4, via `get_weapon_slots()`/`get_passive_slots()` - see the
    grid notes above).
  - **Bans**: the Ban button beside Reroll on the level-up panel is a
    mode - press it, the title switches to "Choose an upgrade to
    ban:", and clicking a choice removes that weapon/passive from the
    run's level-up pool for good (`GameManager.ban_upgrade()` adds it
    to `banned_ids`, which `_upgrade_pool()` filters out) and swaps a
    fresh option into its slot. Press Ban again to cancel. The button
    is greyed out with no bans left or when a ban would leave the
    panel with nothing to show.
  - The **Saves** button on the main menu opens a picker with one
    column per slot (built in `MainMenu._build_slot_columns()` from
    `GameManager.SLOT_COUNT`): the slot button shows coins and total
    upgrade levels and a check mark on the active slot, and the Delete
    button under it wipes that slot's file after a full-screen
    confirmation (`ConfirmOverlay` blocks every click behind it until
    you answer). Selecting a slot only records the choice in
    `settings.json`; a slot's file is first created when it earns
    coins, so unused slots keep reading "Empty".
  - `MainMenu._build_upgrade_rows()` creates one info `Label` + buy
    `Button` pair per `PERMANENT_UPGRADE_DEFS` entry (in table order)
    and keeps them in `upgrade_rows`, so `_refresh_upgrade_row()` and
    the purchase handler work for any number of upgrades without
    per-upgrade code or `.tscn` edits - a new permanent upgrade is a
    table entry only. The row list is inside a `ScrollContainer` for
    the same reason as the level-up panel (see below) - more upgrades
    than fit on screen scroll instead of overflowing the panel.
  - To wipe a save during testing, use Saves > Delete Save on the
    main menu, or delete `user://save_slot_N.json` by hand (and
    `user://settings.json` to reset preferences) — the actual on-disk
    path depends on OS (Godot's docs page "File paths in Godot
    projects" has the exact location per platform), or just call
    `OS.shell_open(OS.get_user_data_dir())` from a debug script to
    open the folder.
- **Display/fullscreen setup**: `project.godot`'s `[display]` section
  sets a 1280x720 base viewport with
  `window/stretch/mode="canvas_items"` and
  `window/stretch/aspect="expand"` - without this, switching to
  fullscreen would just show the fixed-size viewport small in the
  corner of the screen instead of filling it. `"canvas_items"` keeps
  UI elements crisp (not blurry-upscaled) while `"expand"` uses the
  extra space on wider/taller monitors instead of adding black bars.
  Toggling Fullscreen in Settings calls `GameManager.set_fullscreen()`,
  which flips `DisplayServer.window_set_mode()` between
  `WINDOW_MODE_FULLSCREEN` and `WINDOW_MODE_WINDOWED` immediately and
  saves the choice for next launch.

## Where to go from here

- **More weapons**: add an entry to `WEAPON_DEFS` in `GameManager.gd`
  plus the actual firing/damage behavior (a new script, similar to
  `ForcefieldWeapon.gd` or `Player.try_fire()`), a case in
  `WeaponIcon.gd`, and point one of the empty `WeaponSlot3-6` nodes
  in `HUD.tscn` at its id. The level-up pool already scales to any
  number of weapons — it always offers up to 3 random ones.
- **Weapon caps / evolutions**: right now weapons level up forever
  with no cap and no "evolved form" at max level (unlike VS's weapon
  evolutions). Add a `max_level` to `WEAPON_DEFS` and filter it out
  of `offer_upgrades()` once reached.
- **More enemy types**: follow the Minotaur pattern - a new script
  `extends "res://scripts/Goblin.gd"` overriding whatever's
  different, plus a scene with tuned `speed`/`max_hp`. Right now
  `EnemySpawner.gd` has Minotaur's spawn condition hardcoded
  (`game_time >= 90.0 and enemies_spawned % 25 == 0`); with 3+ enemy
  types you'll likely want a weighted/unlock-over-time pool instead
  of hardcoded per-type conditions.
- **Game feel**: hit-flash (swap `modulate` briefly on
  `take_damage`), screen shake on player hit, a particle burst on
  enemy death.
- **More permanent upgrades**: add an entry to
  `PERMANENT_UPGRADE_DEFS` in `GameManager.gd` (display info,
  `stat_label` and, unless it's a percentage, `"format": "flat"` or
  `"count"`, per-level value, `max_level`, `costs`), then apply
  `get_permanent_bonus("your_id")` wherever the effect actually
  matters (see `get_health_regen_rate()`, `get_damage_mult()` and
  `get_max_bans()`). That's it: the shop row and its text come from
  the def automatically (`MainMenu._build_upgrade_rows()`), and slot
  files pick up the new key on their next save.
- **Scaling past a few hundred enemies**: at that point, moving
  every enemy in `_process` with a real node each frame becomes the
  bottleneck. The next step is `MultiMeshInstance2D` for rendering
  and a flat array (no per-enemy nodes) for position/health, with
  manual broad-phase collision (e.g. a spatial hash grid).
- **Background**: currently just black. A simple repeating
  `TextureRect`/`ParallaxBackground` or `TileMapLayer` under the
  action goes a long way visually.
