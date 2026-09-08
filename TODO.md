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
      damage reduction, XP-gem pickup speed, crit chance. (Luck is
      done: the Four-Leaf Clover passive + Luck upgrade, see below.)
- [ ] A way to unlock the 6th weapon and 6th passive slot (the grid
      draws 6 boxes; permanent upgrades open up to 4, survival unlocks a
      5th, nothing opens the 6th yet).

## Enemies and pacing

- [ ] Replace the 15:01 Reaper placeholder (`EnemySpawner.REAPER_TIME`)
      with a real late game: push it out as the run gets longer, add
      waves after the Slimes.
- [x] A summonable boss: the Ancient Keeper (`AncientKeeper.gd`, the
      stone golem `Fantasy Dreamland/Bosses Sprites 1/.../Boss_015.png`)
      called up by pressing E at the Boss Totem (`BossTotem.gd`) five
      minutes of walking left of spawn. 7500 HP, 2/3 Zombie speed, CC
      immune, a dodgeable rock slam every 4-5s (`RockSlam.gd`), drops a
      purple 5000 XP gem and a 2500-coin pile. The HUD points the way
      (`TotemPointer.gd`) and shows the boss's name and HP top-centre
      while it lives. Follow-up: the King Slime pack is still unused -
      a second totem/boss?
- [ ] XP gems are capped at 100 on the field (`XPGem.spawn()` folds
      further drops into the nearest gem, which re-tiers by value) -
      check the late game still feels right with fewer, bigger gems.
- [ ] Elite / variant enemies (the other zombie and skeleton colours in
      the packs are unused).
- [ ] Watch performance at 11:00+ (~27 spawns/s, `SECOND_SURGE_INTERVAL_MULT`)
      with the 500 HP Slimes - lower it if the late game chugs.

## Inventory and extraction

- [x] Permanent inventory + luck chests + 15:00 extraction: planned in
      `docs/inventory-extraction-plan.md` (five wear slots with art
      already in the packs: helmet, armor, boots, shield, gloves;
      rarity sets 1-4 random buffs drawn from every passive stat except
      projectile count, Legendary rolling 40-50%, shown by a coloured
      frame and name rather than a sprite tint; a Luck stat with a
      permanent upgrade and a Four-Leaf Clover passive that weights both
      the rarity and the value rolls; chests from kills plus one from
      the Keeper; a three-slot run-only backpack managed from the pause
      menu, so 5 worn + 3 stowed is all a run can bring out; run loot
      secured only if the run reaches 15:00, then waiting in the main
      menu's Backpack tab until Extract All). Plus the Inventory
      screen: an Inventory button on the main menu, five tabs
      (Inventory, Key Items, Ingredients, Potions, Backpack), a
      slide-in Equip bar with drag-and-drop equipping and a Salvage
      zone. Six phases; phase 1 (the GameManager data layer: defs,
      rolls, save keys, getters, equip/salvage/extract_all) and phase
      2 (the Luck upgrade, the Four-Leaf Clover passive, luck-scaled
      Magnet / Gold Dream drops, the base-94/5/1/0 to max-60/29/15/1
      rarity slide) and 3 (`Chest.tscn` from kills and the Keeper, the
      Vampire-Survivors-style paused reveal `ChestReveal.tscn`, the
      stow-or-wear rule, the run backpack ops, the HUD's worn and
      backpack rows on `ItemCell.tscn`, the armour icon slices) and 4
      (finds secured into the haul at 15:00 and deleted on an earlier
      death, the Victory / You Died panel with the items line, the
      top-right kill counter and secure note) and 5 (the Inventory
      screen: `InventoryScreen.tscn` with five tabs, `EquipBar.tscn`
      drag-and-drop equipping and Salvage, `ItemGridPage.tscn`, the
      Backpack tab's Extract All, the main menu's Inventory button and
      generic confirm dialog) and 6 (the pause menu's Backpack panel
      `RunBackpackPanel.tscn` on the same cells, the Saves panel's
      item count, the README write-up, build-branches sync) are all
      done and harness-verified. Follow-ups live in the plan's "Later,
      not now" list: content for the Key Items / Ingredients / Potions
      tabs, auto-equip on Extract All, an extract-or-keep-going choice
      once the late game passes 15:00, affix re-rolls for coins,
      defensive affixes, a per-stat armour cap, set bonuses, a chest
      pointer, elites with guaranteed chests.

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
