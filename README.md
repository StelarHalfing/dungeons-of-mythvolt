# The Dungeons of Mythvolt (Godot 4.3)

A Vampire Survivors–style auto-battler survival game. Move with
WASD or arrow keys. You start with the Laser Pistol (auto-fires at
the nearest enemy); kill Goblins to drop XP gems, and level up to
pick from 3 weapon choices — leveling up a weapon you already own
boosts its damage/size/speed, and picking the Forcefield for the
first time unlocks it (an aura that ticks damage to enemies around
you). Every 10th kill also drops a coin — coins persist across runs
(and across closing the game) and can be spent in the main menu's
Upgrades screen on permanent bonuses. Starting at 1:30 into a run, a
Minotaur — a slow, 300 HP enemy with a periodic dash attack — shows
up in place of a Goblin roughly once every 25 spawns, and drops a
red gem worth 5 XP instead of the usual green one. Survive as long
as you can.

## How to run
1. Open Godot 4.3+ (or later 4.x — should still work).
2. "Import" this folder, selecting `project.godot`.
3. Press F5 (or the Play button). `Main.tscn` is set as the main scene.

## Project structure

```
scenes/
  MainMenu.tscn     - entry point: Play / Settings / Upgrades (+ Quit)
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
`project.godot`). **Play** loads `Main.tscn` via
`change_scene_to_file`; **Settings** exposes a master volume slider,
a damage-numbers toggle, and a fullscreen toggle (also present in
the in-run pause menu's Settings); **Upgrades** lets you spend saved
coins on permanent bonuses (see below). **Quit** sits as its own
button in the bottom-left corner rather than in the main button
stack, and calls `get_tree().quit()`.

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
  `gain` amounts to the current stats — no min/max caps yet. A
  weapon with `level == 0` (currently only Forcefield at the start)
  is "not yet owned"; picking it in the level-up screen is what sets
  it to level 1 and activates it.
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
- **Icons are drawn in code, not image files**, same philosophy as
  every other visual in the project. `WeaponIcon.gd` is a `Control`
  whose `_draw()` switches on an `icon_id` string (currently
  `"laser_pistol"` and `"forcefield"`, which double as the exact
  keys already used in `GameManager.weapons` - no separate icon
  registry to keep in sync) and falls back to a generic lock glyph
  for anything else, including `""`. That one script is reused in
  two places: as the icon inside each level-up choice button
  (`HBoxContainer` wrapping an `Icon` + the wrapped-text `Label`,
  same click-through `mouse_filter = 2` trick as the label itself),
  and inside `IconSlot.tscn` for the collection grid below. Both
  call `icon.configure(id, dimmed)`, which just sets two vars and
  calls `queue_redraw()`.
- **The 2×6 collection grid** (`WeaponGrid` in `HUD.tscn`, a
  `GridContainer` with `columns = 6`) always shows all 12 possible
  slots — 6 weapons then 6 passives, in that order since
  `GridContainer` wraps children automatically every N columns. Only
  `laser_pistol` and `forcefield` are real today; the other 4 weapon
  slots and all 6 passive slots are instanced with `icon_id = ""`,
  which always renders the locked glyph, dimmed, since there's
  nothing to acquire there yet (passives as a level-up category
  don't exist at all currently - these slots are pure placeholders
  for future content). Each slot is an `IconSlot.tscn` instance;
  `IconSlot.gd` checks `GameManager.weapons[icon_id]["level"] > 0`
  every frame (cheap boolean check on 12 static nodes, same polling
  pattern `HUD.gd` already uses elsewhere) and dims/undims the icon
  accordingly - `is_weapon = false` slots are hardcoded to never
  read as acquired, since there's no passives dictionary yet to
  check against.
  - To add a real weapon into an empty slot: give it an entry in
    `WEAPON_DEFS`, a case in `WeaponIcon._draw()`/`_base_color()`,
    and set that slot's `icon_id` in `HUD.tscn` (`WeaponSlot3`
    onward). To add passives as an actual level-up category (not
    just placeholder slots) is a bigger change — `GameManager` would
    need a parallel `PASSIVE_DEFS`/`passives` dict alongside
    `weapons`, `offer_upgrades()` would need to pull candidates from
    both pools, and `IconSlot.gd`'s `is_weapon` check would switch to
    reading that new dict instead of always resolving to "locked."
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
  `.show_damage_numbers`, and `.is_fullscreen` are deliberately left
  untouched by `reset()` (unlike XP/level/weapons, which are per-run)
  and are written to `user://save_data.json` (via `FileAccess` +
  `JSON.stringify`) every time they change - through setters like
  `set_fullscreen()`/`set_show_damage_numbers()`, not direct field
  assignment, so the save actually happens - then reloaded once in
  `GameManager._ready()` at startup. `PERMANENT_UPGRADE_DEFS` follows
  the same static-table-plus-live-state pattern as `WEAPON_DEFS`:
  each entry has a `costs` array (cost of each level) and a
  `max_level`. Every 10th kill (`Goblin.gd`, checking
  `enemies_defeated % 10` - Minotaur inherits this unchanged) drops a
  `CoinPickup` — same magnet/pickup code as `XPGem`, just paying out
  `GameManager.add_coins()` instead of `add_xp()`.
  - There are two permanent upgrades right now: Health Regeneration
    (+0.2 HP/sec/level, applied in `Player.gd`'s `_physics_process()`
    via `get_health_regen_rate()`) and Damage (+10%/level, flat/
    additive not compounding, capped at +50% at level 5 - applied via
    `get_permanent_damage_mult()` everywhere weapon damage is dealt:
    `Player.try_fire()` for the Laser Pistol and
    `ForcefieldWeapon._process()` for the Forcefield tick). Damage's
    `costs` are exactly double Health Regeneration's
    (`[200, 400, 1000, 2000, 5000]` vs `[100, 200, 500, 1000, 2500]`).
  - `MainMenu.gd`'s `upgrade_rows` dictionary maps an upgrade id to
    its info `Label`/buy `Button` node pair, so `_refresh_upgrade_row()`
    and the purchase handler work for any number of upgrades without
    per-upgrade code - adding a third permanent upgrade is a new
    `PERMANENT_UPGRADE_DEFS` entry, two new nodes under
    `UpgradesPanel/VBoxContainer/ScrollContainer/UpgradeList` in the
    `.tscn`, and one new entry in `upgrade_rows`. The row list is
    inside a `ScrollContainer` for the same reason as the level-up
    panel (see below) - more upgrades than fit on screen scroll
    instead of overflowing the panel.
  - To wipe your save during testing, delete
    `user://save_data.json` — its actual on-disk path depends on OS
    (Godot's docs page "File paths in Godot projects" has the exact
    location per platform), or just call
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
  `PERMANENT_UPGRADE_DEFS` in `GameManager.gd` (display info, per-
  level value, `max_level`, `costs`), a `get_..._rate()`/
  `get_..._mult()`-style accessor if the effect needs computing (see
  `get_health_regen_rate()` and `get_permanent_damage_mult()`), plus
  wherever that effect actually applies. Then add the two nodes
  (info `Label` + buy `Button`) under `UpgradeList` in
  `MainMenu.tscn` and one entry in `MainMenu.gd`'s `upgrade_rows`
  dictionary — `_refresh_upgrade_row()` and the purchase handler
  already work for any number of upgrades, no per-upgrade code
  needed beyond that.
- **Scaling past a few hundred enemies**: at that point, moving
  every enemy in `_process` with a real node each frame becomes the
  bottleneck. The next step is `MultiMeshInstance2D` for rendering
  and a flat array (no per-enemy nodes) for position/health, with
  manual broad-phase collision (e.g. a spatial hash grid).
