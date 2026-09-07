# To-do

Ideas queued for the next sessions, roughly in the order they came up.
Design conventions to keep: new weapons/passives/upgrades are table
entries in `GameManager.gd` (`WEAPON_DEFS` / `PASSIVE_DEFS` /
`PERMANENT_UPGRADE_DEFS`) plus a caster or icon; run-only passives and
permanent upgrades that share a stat ADD together so both maxed is
exactly x2 (gold, duration, knockback, attack speed); every feature
gets an in-engine harness pass before it is committed.

## Weapons

- [ ] **Frost Sword** - a second blade that slows what it cuts (reuse
      `Zombie.apply_slow()`, the Tornado's slow) and perhaps freezes
      solid at max level. Decide whether it is its own weapon or an
      evolution of the Sword.
- [ ] More weapons in general: candidates with sprites already in the
      packs - a bow (`Bow.png` / `Bow 2.png`, arrows in the pixel
      dungeon pack), the axes on the item sheet (a boomerang axe?), the
      `Double sword.png`, the orbs (an orbiting orb weapon), `Banner.png`
      (an aura/buff totem).
- [ ] Weapon evolutions / synergies (weapon + passive at max = upgraded
      form), the standard survivors hook.

## Passives

- [ ] More passives. Free stat hooks already exist in `GameManager.gd`:
      `speed_mult` (move speed - boots on the item sheet) and
      `max_hp_bonus` (max HP - the heart at (136,456)). Others: armour /
      damage reduction, XP-gem pickup speed, crit chance, luck (drop
      rates for Magnet / Gold Dream).
- [ ] A way to unlock the 6th weapon and 6th passive slot (the grid
      draws 6 boxes; permanent upgrades open up to 4, survival unlocks a
      5th, nothing opens the 6th yet).

## Enemies and pacing

- [ ] Replace the 15:01 Reaper placeholder (`EnemySpawner.REAPER_TIME`)
      with a real late game: push it out as the run gets longer, add
      waves after the Slimes.
- [ ] King Slime boss (sprites in `DG Monsters Expansion/King Slime
      Pack`), maybe at 10:00 or as the 15:00 finale instead of the
      Reaper.
- [ ] Elite / variant enemies (the other zombie and skeleton colours in
      the packs are unused).
- [ ] Watch performance at 11:00+ (~27 spawns/s, `SECOND_SURGE_INTERVAL_MULT`)
      with the 500 HP Slimes - lower it if the late game chugs.

## Meta and UI

- [ ] Best survival time / run stats on the game-over panel and the
      Saves panel (kills, coins earned, weapons used).
- [ ] More characters and maps: the select screens are data-driven
      (`CHARACTER_DEFS` / `MAP_DEFS`) but only the Knight and one map
      exist; the character sprites exist in the Knight pack (other
      colours) and the map traits list is hand-written.
- [ ] Sound and music (nothing is wired up; the Master Volume slider
      only sets the bus).
- [ ] Larger in-game text option for small screens (the HUD, level-up
      panel and character sheet still use 24px body text; the main menu
      already runs 32px in its panels).

## Housekeeping

- [ ] Keep the per-session `_Verify.gd`/`_Verify.tscn` harness out of the
      repo (it is written, run and deleted within a session - nothing is
      committed today).
- [ ] README: keep the weapon/passive/upgrade lists in step with the
      defs (it documents every system as of this session).
