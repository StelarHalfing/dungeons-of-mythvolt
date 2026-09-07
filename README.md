# The Dungeons of Mythvolt (Godot 4.7)

A Vampire Survivors–style auto-battler survival game. Move with
WASD or arrow keys. The Knight starts with the Sword (a slash at the
nearest enemy that flies on and cleaves through whatever it passes -
`starting_weapon` in `CHARACTER_DEFS`); kill Zombies to drop XP gems,
and level up to pick from 3 weapon or passive choices — leveling up a
weapon you already own boosts its damage/size/speed (to a cap of level
12), picking a weapon for the first time unlocks it (the Laser Pistol,
Forcefield, Tornado, Grenade, Fireball and Mjolnir - see the weapon
notes below), and a passive (Attraction Tome, Power Emblem, Wisdom
Orb, Vitality Elixir, Lucky Coin, Hourglass, Heavy Club, Haste
Crystal) boosts a stat of yours instead. Don't like the three on
offer? The Reroll button under them swaps in new ones: the first
reroll of a run is free, the next costs 50 coins and the price doubles
with every reroll after that (`GameManager.reroll_upgrades()`; the
counter resets each run). Once every slot is full and everything you
hold is maxed, level-ups offer two consolation picks instead of
nothing: a Small Heal (25% of max HP) or a Coin Bonus (a flat 25 gold,
paid through `add_flat_coins()` so no gold multiplier changes the
number on the card) - `FALLBACK_DEFS` in `GameManager.gd`, applied by
`_apply_fallback()`; rerolls and bans don't apply to that panel.
Every 10th kill also drops a coin, and once in a thousand kills a
Gold Dream power-up (`GoldDreamPickup.tscn`, as rare as the Magnet):
pick it up and for 10 seconds every kill drops a coin and gold is
worth double (`GameManager.activate_gold_dream()`; the HUD counts it
down beside the coin total) — coins persist across runs
(and across closing the game) and can be spent in the main menu's
Upgrades screen on permanent bonuses. Starting at 1:30 into a run, a
Tank Zombie — a slow, 300 HP enemy with a periodic dash attack — takes
every 25th spawn and drops a red gem worth 5 XP instead of the usual
green one; Skeletons (60 HP, two gems) replace Zombies from 1:45 and
Slimes (500 HP, blue 3 XP gems) take over from 8:00 - see the
difficulty notes below. Survive as long as you can.

## How to run
1. Open Godot 4.7 (`project.godot` targets 4.7 with the GL Compatibility renderer).
2. "Import" this folder, selecting `project.godot`.
3. Press F5 (or the Play button). `MainMenu.tscn` is set as the main scene.

## Project structure

```
scenes/
  MainMenu.tscn     - entry point: Play / Settings / Upgrades / Saves (+ Quit, Unlocks)
  RunSetup.tscn     - character select then map select (two SelectPage.tscn
                      instances of SelectCard.tscn cards), then Main.tscn
  Main.tscn         - root gameplay scene: Background + BossTotem + Player + EnemySpawner + HUD
  BossTotem.tscn    - Area2D: the pillar 5 minutes' walk left of spawn; press E to
                      summon the Ancient Keeper (one-shot)
  AncientKeeper.tscn - the summonable boss (AncientKeeper.gd extends Zombie.gd):
                      7500 HP, 2/3 Zombie speed, CC-immune, rock slam attack
  RockSlam.tscn     - the slam's ground marker + eruption (RockSlam.gd)
  Player.tscn       - CharacterBody2D, movement + the Laser Pistol's auto-fire,
                      with the Forcefield and one caster node per other weapon
                      under it (SwordCaster, TornadoCaster, GrenadeCaster,
                      FireballCaster, MjolnirCaster)
  Zombie.tscn       - Area2D, base enemy: chases player, contact damage (20 HP)
  TankZombie.tscn   - Area2D extending Zombie: 300 HP, half speed, dash attack
  Skeleton.tscn     - Zombie.gd with scene-tuned stats: 60 HP, drops two gems
  Slime.tscn        - Zombie.gd again: 500 HP, slow, drops a blue gem
  Reaper.tscn       - the 15:01 finale (Reaper.gd extends Zombie.gd)
  Projectile.tscn   - Area2D, the Laser Pistol's shot
  Fireball.tscn     - Area2D, the Fireball's shot (explodes on impact)
  Grenade.tscn      - Area2D, lobbed, one blast after a fuse
  Tornado.tscn      - Area2D, wandering AoE zone that ticks damage
  MjolnirHammer.tscn - Mjolnir's thrown hammer (Area2D, MjolnirHammer.gd); its
                      lightning is code-drawn by LightningChain.gd
  XPGem.tscn        - Area2D, magnets to player, grants its xp_value (1 by default);
                      colour/size come from the value's tier (see XPGem.gd TIERS)
  RedXPGem.tscn     - XPGem.tscn inherited with xp_value 5, the Tank Zombie's drop
  BlueXPGem.tscn    - XPGem.tscn inherited with xp_value 3, the Slime's drop
  CoinPickup.tscn   - Area2D, magnets to player, grants a coin
  MagnetPickup.tscn - rare drop: pulls every gem and coin on the field in
  GoldDreamPickup.tscn - rare drop: 10 seconds of double gold and a coin per kill
  DamageNumber.tscn - floating text popup on hit, drifts up and fades (pooled)
  DeathBurst.tscn   - one-shot particle burst at a corpse
  IconSlot.tscn     - one box in the run-collection grid: border + icon, dimmed until acquired
  HUD.tscn          - HP/XP/coin display, weapon/passive collection grid,
                       level-up panel, pause panel, game over panel, the boss
                       HP bar (top centre while a boss lives) and the totem
                       pointer (TotemPointer.gd)
scripts/
  GameManager.gd    - autoload singleton: XP, level, run timer,
                       weapon stats (WEAPON_DEFS), passives (PASSIVE_DEFS),
                       kill count, coins and permanent upgrades
                       (PERMANENT_UPGRADE_DEFS), save/load to disk, and the
                       cached `player` reference everything reads
  WeaponCaster.gd   - shared base for the caster nodes: the cooldown gate
  MainMenu.gd, RunSetup.gd, SelectPage.gd, SelectCard.gd, Main.gd, Background.gd,
  Player.gd, EnemySpawner.gd, Zombie.gd, TankZombie.gd, Reaper.gd,
  BossTotem.gd, AncientKeeper.gd, RockSlam.gd, TotemPointer.gd,
  SwordCaster.gd, Slash.gd, ForcefieldWeapon.gd, TornadoCaster.gd, Tornado.gd,
  GrenadeCaster.gd, Grenade.gd, FireballCaster.gd, Fireball.gd, ExplosionFlash.gd,
  MjolnirCaster.gd, MjolnirHammer.gd, LightningChain.gd, Projectile.gd,
  XPGem.gd, CoinPickup.gd, MagnetPickup.gd, GoldDreamPickup.gd,
  DamageNumber.gd, DeathBurst.gd, IconSlot.gd, WeaponIcon.gd, HUD.gd
allassets/
  Third-party art and audio packs, one folder per pack. The original DG /
  Dungeon Gathering / Pixel Dungeon packs sit at the top level; the packs
  added 2026-09-07 are grouped by family: Fantasy Dreamland/ (with
  Reborn/ tilesets and Enemies 4 Directions/ inside it), Rogue
  Adventure/ (both ElvGames - see their License (ElvGames).txt: credit
  required, no AI/NFT/resale), Monster Factory/, Sound Effects/ (OGG
  only), Farming Game World/, Platformer World/, Item Icons/, Tilesets/,
  Extras/, and standalone packs by name (EvoMonsters, Pixel Battlers,
  Tower Defense etc. hold one subfolder per numbered pack). Zips live
  in ../../Raw assets zip and are unpacked into the staging folder
  ../../Assets first; only game-usable files are copied here - engine
  packages (Unity/GameMaker/RPG Maker/Godot-project copies),
  tool executables and the duplicate "World" bundles stay in staging.
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

Sprites come from the packs under `allassets/` (see that folder's note
in the tree above): every enemy and the player are `AnimatedSprite2D`s
with 4-direction walk cycles (`Zombie._facing_animation()` picks the
frame set from the direction to the player, with hysteresis so a
diagonal approach doesn't flicker), pickups and icons are single
frames, and the effects with no fitting art - the Tornado, Slash,
Grenade, lightning, explosion flash, Magnet and Gold Dream halos - are
still drawn in code with `_draw()`.

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
  `gain` amounts to the current stats, up to each weapon's `max_level`
  (12 for all of them), after which `_upgrade_pool()` stops offering it. Every
  weapon starts a run at `level == 0` ("not yet owned") except the
  selected character's `starting_weapon` (`CHARACTER_DEFS`; the
  Knight's is the Sword), which `_init_weapons()` sets to level 1;
  picking an unowned weapon in the level-up screen is what sets it
  to level 1 and activates it.
  - **Laser Pistol** (`Player.try_fire()`): `damage` per hit, `size`
    is the projectile's radius (collision + visuals), `speed` is
    projectile travel speed. Fire rate is a fixed 0.6s cooldown
    times `get_cooldown_mult()` (see Cooldown below). It also has a
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
    it's the one weapon `get_projectile_count()` doesn't apply to.
  - **Tornado** (`TornadoCaster.gd`, a child of Player): on a cooldown
    (`speed` is casts per second, 10s at level 1) drops a `Tornado.tscn`
    on the nearest enemy - a vortex of radius `size` that wanders in a
    slow random walk for its `duration` (2.5s, times
    `get_duration_mult()`), ticks `damage` every 0.4s to everything
    overlapping it and drags those enemies toward its centre so they
    stay caught as it drifts (Tank Zombies are too heavy to drag and are
    slowed instead - `Zombie.apply_slow()`). `projectile_count` (+1
    every 3rd level) casts on the next-nearest enemies too.
  - **Grenade** (`GrenadeCaster.gd`, a child of Player): on a long
    cooldown (15s at level 1 down to 2s at 12; `speed` is casts per
    second) lobs a `Grenade.tscn` that flies at 600 px/s, sits through a
    1s fuse and explodes once for `damage` to everything within `size`
    (35 damage at level 1, 200 at 12). Unlike every other weapon it
    doesn't aim at the nearest enemy: it asks each enemy where it will
    be when the blast goes off (`Zombie.predict_position()`, which
    `TankZombie` overrides to play its telegraph and dash out first) and
    throws at the densest cluster of those predicted positions, scored
    through a spatial hash of blast-radius cells so a late-run crowd
    doesn't cost n² distance checks per throw. `projectile_count` (+1
    every 3rd level) throws at the next-densest cluster as well.
  - **Fireball** (`FireballCaster.gd`, a child of Player): on a fixed
    1.2s cooldown launches `Fireball.tscn` at the nearest enemies, slow
    (`speed` is its travel speed, 100 px/s at level 1) and heavy: on
    touching an enemy, or after 3s, it explodes - `damage` to what it
    hit, then 60% of that to everything within 3.75x its `size`
    (`Fireball.BLAST_RADIUS_MULT`/`BLAST_DAMAGE_MULT`), with an
    `ExplosionFlash`. `projectile_count` (+1 every 3rd level) fires at
    the next-nearest enemies too.
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
    next-nearest enemy in depth. Its damage runs at half the pace of
    the other weapons (10 at level 1, 32 at 12) because every hit also
    knocks the enemy back: its `knockback` stat (40px, no per-level
    gain) times `get_knockback_mult()`, handed to
    `Zombie.apply_knockback()` as a decelerating shove along the slash
    that replaces chasing until it stops (a TankZombie is shoved in
    every state, without its telegraph/dash being cancelled).
  - **Mjolnir** (`MjolnirCaster.gd`, a child of Player): on a fixed
    1.4s cooldown hurls `MjolnirHammer.tscn` at the nearest enemies
    (one per `projectile_count`). The hammer flies at `speed`, homing
    on its target, and on touching an enemy deals `damage` and drops a
    `LightningChain.gd` there, which arcs to the nearest un-hit enemy
    within `size` (its chain range), deals `damage` again, and carries
    on from that enemy `chains` times or until nothing is in reach -
    every strike is a code-drawn fading bolt. Levels: `chains` +1 every
    3rd level (2 at level 1, 6 at 12), `projectile_count` +1 at levels
    6 and 12 only (`projectile_levels` in the def, read by
    `_gains_projectile_at()`), and damage 18 -> 40 so a maxed hammer
    with the permanent Damage upgrade and Power Emblem both maxed
    hits for exactly 120. Its level-up text uses `size_label`
    ("chain range") in place of "size".
  - **Every caster shares one loop.** `WeaponCaster.gd` is the base of
    SwordCaster/TornadoCaster/GrenadeCaster/FireballCaster/MjolnirCaster:
    it skips the level-up pause, does nothing until the weapon is owned
    (level > 0), counts the cooldown down and, when `_cast()` reports it
    fired, reloads it with `_cooldown()` (1 / `speed` unless overridden -
    Fireball and Mjolnir use a constant) times `get_cooldown_mult()`. A
    caster that finds nothing to hit returns false from `_cast()` to
    keep the cooldown ready (the Sword). The Forcefield is an `Area2D`
    that ticks rather than casts, so it keeps its own loop.
  - **Duration** is a stat like damage: `get_duration_mult()` is
    1 + the permanent Duration upgrade (+10%/level to +50%) + the
    Hourglass passive (+10%/level to +50%), ADDED like gold gain
    rather than multiplied like damage, so both maxed is exactly x2.
    It stretches everything with a duration - the sword slash's flight
    and the Tornado's lifetime.
  - **Knockback** works the same way: `get_knockback_mult()` is 1 + the
    permanent Knockback upgrade (+10%/level to +50%) + the Heavy Club
    passive (+10%/level to +50%), added, so both maxed is exactly x2
    the shove distance. Only the sword's slash has a `knockback` stat
    so far; any weapon can add one and call `apply_knockback()`.
  - **Passives** (`PASSIVE_DEFS`) sit in the same level-up pool as
    weapons but drive one player-level stat in `GameManager` each,
    `base + level * per_level_value`, five levels: **Attraction Tome**
    (`pickup_range_mult`, +30%/level: the 60px range at which gems,
    coins and the rare pickups start homing to you, read by
    `XPGem.gd`/`CoinPickup.gd`/`MagnetPickup.gd`/`GoldDreamPickup.gd`),
    **Power Emblem** (`damage_mult`, +20%/level, multiplied into
    `get_damage_mult()`), **Wisdom Orb** (`xp_mult`, +10%/level),
    **Vitality Elixir** (`regen_bonus`, +0.2 HP/sec/level), **Lucky Coin**
    (`coin_gain_bonus`, +10%/level), **Hourglass** (`duration_bonus`),
    **Heavy Club** (`knockback_bonus`) and **Haste Crystal**
    (`attack_speed_bonus`), the last four added to their permanent
    upgrade as described above. A new passive is a def entry naming an
    existing (or new) `GameManager` var plus an `ICON_TEXTURES` entry.
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
  over time. Each enemy always spawns at its scene's fixed
  base `max_hp`/`speed` — the only thing that changes with time is
  how often `EnemySpawner.gd` spawns one
  (`initial_interval - game_time * 0.01`, floored at 0.15s), and
  which: Tank Zombies take every 25th spawn from 1:30
  (`TANK_ZOMBIE_START_TIME`), Skeletons ramp in over 1:45-2:15 to
  replace Zombies as the base chaser, the surge from 6:00 halves the interval (double the rate),
  and from 8:00 Slimes (`Slime.tscn`, 500 HP, slow, reusing
  `Zombie.gd` with the Slimes Pack bounce frames for every facing)
  take over the base chaser slot entirely - Skeletons stop spawning
  by 8:30 - while the surge eases back off over the same 30 seconds:
  the spawn rate returns to its pre-6:00 level, but with far more HP
  per spawn. Tank Zombies keep their own schedule. From 10:30 a
  bigger surge ramps in (`SECOND_SURGE_INTERVAL_MULT`: a quarter of the
  plateau interval by 11:00, four times the rate and twice the first
  surge, Slimes included) and stays for the rest of the run. A Slime
  drops one blue `BlueXPGem` worth 3 XP in place of green gems. At
  15:01 (`REAPER_TIME`, one second after the 15-minute survival unlock)
  the run ends: `_summon_reaper()` frees every enemy on the field (no
  drops), spawning stops for good, and one `Reaper.tscn` (`Reaper.gd`
  extends `Zombie.gd`: the dark skeleton at 5x, a billion HP, 400
  speed, 1000 contact damage, immune to knockback and slows) runs the
  player down. It is a placeholder finale to be pushed later once
  there is more game to survive.
- **Every enemy is `Zombie.gd`.** `Zombie.gd` splits its behavior into
  small overridable pieces (`_move_toward_player()`, `_update_facing()`,
  `_update_contact_damage()`, `_drop_loot()`, `predict_position()`) so
  variants can replace just what differs. `TankZombie.gd` extends it via
  GDScript inheritance (`extends "res://scripts/Zombie.gd"`) to swap
  movement for a dash state machine (`CHASE` → `TELEGRAPH` → `DASH`,
  calling `super._ready()` to still get the base HP/group-membership
  setup), to drop a `RedXPGem` instead, and to tell the Grenade where
  the dash will put it; `Reaper.gd` extends it to refuse knockback and
  slows; Skeleton and Slime don't need a script of their own at all -
  their scenes attach `Zombie.gd` with different exported stats and
  frames. All of them reuse `take_damage()`/`die()`/contact-damage/
  damage-numbers/coin-drops unchanged. `EnemySpawner.gd` decides which
  scene to instantiate per spawn (see the difficulty notes above).
  `XPGem.gd` similarly keys everything off one `xp_value` export:
  `RedXPGem.tscn`/`BlueXPGem.tscn` are inherited scenes that only
  change that number, and the gem's colour and size follow from it.
- **The Ancient Keeper is summoned, not scheduled.** `BossTotem.tscn`
  sits in `Main.tscn` five minutes of base-speed walking
  (`WALK_MINUTES * 60 * Player.base_speed`, so 42,000px) straight left
  of the spawn point, drawn under the sprites (it comes right after
  `Background` in the tree). Walk into its ring and press E
  (`_unhandled_input`, one shot) to spawn `AncientKeeper.tscn` 260px
  away. `AncientKeeper.gd` extends `Zombie.gd`: 7500 HP, speed 40 (2/3
  of a Zombie), 35 contact damage, immune to knockback and slows like
  the Reaper, and a `CHASE` → `CHARGE` state machine for its **rock
  slam**: every 4-5s (trigger to trigger, rolled fresh each time) with
  the player within 600px it stops, tints red and charges for 1.5s
  while `RockSlam.tscn` draws a red ring on the ground at the player's
  *predicted* position (`player.global_position + player.velocity *
  1.5`) with an inner fill that grows to meet the ring as the slam
  lands; at 1.5s the floor there erupts (the background's own prop
  rocks popped up and faded) and the player takes 45 if still inside.
  The ring's radius is 55% of the ground the player can cover during
  the telegraph (`0.55 * base_speed * speed_mult * 1.5`, clamped to
  60-220px - 115px at base speed), which is what makes it a dodge
  rather than a coin flip: keep running and you arrive dead centre,
  stop or turn the instant it appears and you clear it, react late and
  it lands. `predict_position()` tells the Grenade the boss stands
  still for the rest of a charge. It drops one purple gem worth 250 XP
  and one 500-coin pile (a single `CoinPickup` at 2x with
  `coin_value = 500`, so Gold Gain/Lucky Coin apply as to any coin).
  The HUD does two things for it: `TotemPointer.gd` (a Control filling
  the HUD layer) draws an arrow orbiting the player, aimed at the
  totem, with the walk time left under it - hidden within 420px of the
  totem and for good once it's used - and a top-centre bar
  (`BossBar`/`BossLabel`, driven from `HUD._process()` off the
  `bosses` group) shows the boss's name and current / max HP while it
  is alive.
- **XP gems are capped at 100 on the field.** `XPGem.spawn()` is the
  one way enemies drop a gem (`Zombie._drop_loot()`,
  `TankZombie._drop_loot()`). Past `MAX_GEMS` it folds the new drop's
  value into the nearest existing gem (`add_value()`) instead of adding
  another node that would home and distance-check every frame - a late
  horde drops gems far faster than they get picked up. Nothing is lost:
  the receiving gem's value goes up by exactly the folded amount, and
  its look follows its value through the `TIERS` table (green 1, blue
  3, red 5, gold 15, silver 50, purple 250 - orb rows of the same
  `All Orbs anim 16x16.png` sheet, scaled up per tier), so a gem that
  has absorbed a crowd reads as the bigger prize it is. The boss drop
  is placed directly rather than through `spawn()` so the cap can't
  fold it into a stray gem.
- **The player is looked up once.** `Player._ready()` stores itself in
  `GameManager.player` (and `_exit_tree()` clears it), and every
  per-frame "where is the player" - each enemy's chase and facing, each
  pickup's homing check, the spawner, the background, the HUD's HP bar
  - reads that field instead of `get_nodes_in_group("player")`, which
  built a fresh Array per caller per frame. The `player` group still
  exists for the `is_in_group()` checks in `body_entered` handlers.
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
  loaded values are type-checked and clamped by
  `_clamped_upgrades()` (a hand-edited or half-written file can't put
  an upgrade above `max_level` or break the menu), and the Saves
  picker's per-slot summary reads through the same clamp, so it can't
  show a total the slot can't actually have. The pre-slot `user://save_data.json` is migrated into
  `settings.json` + slot 1 the first time this build runs (gated on
  `settings.json` not existing yet) and then left in place untouched
  as a backup. `PERMANENT_UPGRADE_DEFS` follows the same
  static-table-plus-live-state pattern as `WEAPON_DEFS`: each entry
  has a `costs` array (cost of each level), a `max_level`, and the
  `stat_label`/`format` keys `format_bonus()` uses to write the bonus
  ("+10%", "+0.2" or "+1", the same formatter the level-up cards use for
  passives). Every 10th kill (`Zombie.die()`, checking
  `enemies_defeated % 10` - every enemy inherits it) drops a
  `CoinPickup` — same magnet/pickup code as `XPGem`, just paying out
  `GameManager.add_coins()` instead of `add_xp()`.
  - There are twelve permanent upgrades right now, all `level *
    per_level_value` via `get_permanent_bonus(id)`. Seven are stat
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
    see the Duration note above) and Knockback (same curve and costs,
    folded into `get_knockback_mult()` next to the Heavy Club passive,
    added like Duration), and Cooldown (+10% attack speed/level: every
    weapon's seconds between attacks - the Laser Pistol's fixed
    cooldown, the casters' cooldowns, the Forcefield's tick interval -
    is multiplied by `get_cooldown_mult()` = 1 / (1 + the upgrade + the
    Haste Crystal passive), so both maxed halves every cooldown; its
    `costs` are double Damage's). Damage's, XP Gain's, Gold Gain's,
    Duration's and Knockback's `costs` are exactly double Health
    Regeneration's (`[200, 400, 1000, 2000, 5000]` vs
    `[100, 200, 500, 1000, 2500]`), and Cooldown's double those again
    (`[400, 800, 2000, 4000, 10000]`).
    Five more are whole-number perks
    (`"format": "count"`): for the level-up panel, two levels each at
    1000 then 5000 coins, Rerolls (+1 free reroll per run on top of
    the one everyone gets, via `get_free_rerolls()`) and Bans (+1 ban
    per run; there are none without it, via `get_max_bans()`); and
    for the collection grid, two levels each at 1000 then 2500 coins,
    Weapon Slots and Passive Slots (+1 open slot per run each, from 2
    up to 4, via `get_weapon_slots()`/`get_passive_slots()` - see the
    grid notes above); and the late-game Projectile Count (two levels
    at 15000 then 50000 coins, +1 projectile per volley for every
    weapon with a `projectile_count` - laser shots, tornadoes,
    grenades, fireballs, slashes, hammers - via
    `get_projectile_count(id)`, which every caster reads instead of the
    raw stat; the Forcefield has none and ignores it).
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

`TODO.md` is the live queue. The structural notes:

- **More weapons**: add an entry to `WEAPON_DEFS` in `GameManager.gd`,
  a caster script extending `WeaponCaster.gd` (set `weapon_id` in
  `_init()`, implement `_cast()`, override `_cooldown()` if the rate
  isn't the `speed` stat) as a child node of `Player.tscn`, and an
  `ICON_TEXTURES` entry in `WeaponIcon.gd`. The level-up pool and the
  collection grid scale to any number of weapons on their own; give
  it a `projectile_count` base stat and `get_projectile_count()` (the
  every-3rd-level bonus plus the permanent upgrade) applies to it too.
- **Weapon evolutions**: every weapon caps at `max_level` 12 but
  nothing happens at the cap yet (unlike VS's weapon evolutions) - a
  weapon-plus-passive-at-max evolved form is the standard hook.
- **More enemy types**: a scene attaching `Zombie.gd` with tuned
  `speed`/`max_hp`/`contact_damage`/`xp_gem_count` (the Skeleton and
  Slime pattern), or a script `extends "res://scripts/Zombie.gd"`
  overriding whatever's different (the Tank Zombie pattern; override
  `predict_position()` too if it doesn't just walk at the player).
  `EnemySpawner.gd` picks the scene per spawn with hand-written time
  conditions; with many more types a weighted/unlock-over-time pool
  would read better than more `if`s.
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
  manual broad-phase collision (e.g. a spatial hash grid like the
  one `GrenadeCaster._pick_cluster_targets()` already uses).
- **Sound and music**: nothing is wired up; the Master Volume slider
  only sets the bus. `allassets/Sound Effects/` has OGGs.
