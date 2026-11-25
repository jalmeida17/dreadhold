<div align="center">

# DREADHOLD

**A dark-fantasy, Doom-style first-person survival game — swords, sorcery and bows, no guns.**

*The dead will not rest.*

![Title screen](docs/screenshots/title.png)

![Godot 4.6](https://img.shields.io/badge/Godot-4.6-478cbf?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-100%25-355570)
![Status](https://img.shields.io/badge/status-early%20prototype-orange)

</div>

---

Dreadhold is a retro first-person game in the spirit of the early-90s classics, crossed with the
dark high-fantasy feel of classic real-time-strategy games. You defend a fallen keep, night after night,
against an endless horde of undead. Between nights, a shady goblin sells you power for the gold of the
dead, and every fifth night you are dragged into a ritual arena to face the **Hollow King**.

**Every visual, sound and music track is generated procedurally by code in this repository**
(textures, sprites, first-person weapons, portraits, UI, sound effects, music). The only third-party
asset is the [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans) font (SIL Open Font License).

## Screenshots

| Champion selection | Fighting the night |
|---|---|
| ![Champions](docs/screenshots/champions.png) | ![Combat](docs/screenshots/combat.png) |

| The Barrow Throne | Grizzle's Black Market |
|---|---|
| ![Boss](docs/screenshots/boss.png) | ![Black market](docs/screenshots/black_market.png) |

## Features

- **Doom-style FPS feel**: fast movement, billboard sprite enemies, chunky pixel rendering
  (the 3D world renders at 640×360, while the UI stays sharp at 1280×720).
- **Three champions**, each with its own resource and kit (see below), and **weapon upgrades**: every boss
  slain grants the next weapon tier, shown in hand (Bearded Axe → Reaver Greataxe → Doomcleaver,
  Ember Staff → Moonsilver Staff → Staff of the Burning Eye, Yew Longbow → Hornbow of the Wilds → Wyrmbone Greatbow).
- **Four battlefields** to choose from:
  - *Blackstone Keep*: a moonlit courtyard;
  - *The Sunken Crypt*: a vaulted ossuary of corridors and tombs;
  - *Hollowmere*: a misty ruined village;
  - *The Defiled Cathedral*: a dark nave cut by a rood screen and walled chapels.
- **Survival mode, "The Vigil"**:
  - **Nights**: each one is a wave of ghouls, skeletons, bone archers, shadow acolytes and barrow brutes.
  - **At dawn**, *Grizzle the black-market goblin* appears. Trade with him to buy abilities and upgrades, potions or healing (and an off-hand torch for warriors), or restock his wares.
  - **Every 5th night**, you are teleported into a boss arena. The four bosses take turns, and later cycles bring them back stronger. Each boss has three phases: every shattered phylactery makes it angrier.

    | Boss | Arena | Signature attacks |
    |---|---|---|
    | The Hollow King | The Barrow Throne | raises the dead, soul volleys |
    | Mother of Rot | The Rotting Pit | acid rain that leaves toxic pools, ghoul broods |
    | The Cinder Tyrant | The Molten Forge | meteor strikes, a shockwave you must jump over |
    | Lady Rime | The Frozen Sanctum | blinks around you, ice volleys, a frost nova that slows |
- **RTS-inspired console HUD**: minimap with spawn pings, living portrait, and a command card with hotkeys and radial cooldowns. A night dial shows the night's progress, and a boss plate tracks the boss's phylacteries.
- **Score screen** on defeat, with Overview, Combat and Upgrades tabs and comparisons to your personal bests.
- **Procedural everything**: the generators live in `tools/` and can be re-run at any time.

## Champions

| Champion | Resource | Left click | Right click | E / Shift |
|---|---|---|---|---|
| **Warrior**: melee, heavy armor | Rage | Cleave | Reaving Spin | Iron Charge |
| **Mage**: ranged, glass cannon | Mana | Fireball | Frost Nova | Blink |
| **Hunter**: ranged, swift | Focus | Arrow Shot | Volley | Shadow Step |

## Controls

| Action | Key |
|---|---|
| Move | `W A S D` (physical keys, so `Z Q S D` on AZERTY) / arrows |
| Jump | `Space` |
| Primary / secondary ability | `Left` / `Right mouse` |
| Utility ability | `E` or `Shift` |
| Drink a potion | `R` |
| Talk to the goblin | `F` |
| Pick champion / battlefield | `1`–`4`, `Enter` |
| Pause menu | `Esc` |

## Getting started

1. Install **[Godot 4.6](https://godotengine.org/download/)**. The project is pure GDScript, so no .NET is required.
2. Clone the repository and open `project.godot` in Godot. The first import takes a few seconds.
3. Press **F5**.

## Regenerating the assets

All the art and audio are produced by headless Godot scripts:

```sh
tools/run_tool.sh res://tools/gen_art.gd 600    # textures, enemies, props, effects, weapons, portraits, NPCs
tools/run_tool.sh res://tools/gen_ui.gd 300     # console HUD, frames, icons, logo, cursor, boss plate
tools/run_tool.sh res://tools/gen_audio.gd 600  # sound effects and looping music (WAV)
```

`run_tool.sh` runs the script with a hard timeout. The generators also write contact sheets to
`tools/preview/` for quick visual checks (that folder is git-ignored).

## Testing hooks

The game accepts a few command-line flags (after `--`) that are used for automated checks:

```sh
godot --path . -- start class=mage demo                # start a run with a line-up of enemies
godot --headless --path . -- start bot log god wave=4   # an autopilot plays and logs every night
godot --path . -- start dawn shop gold=250              # open the black market directly
godot --path . -- start shot=out.png shot_at=3 quit_at=4
```

## Project layout

```
scripts/
  autoload/        Game (settings, input map, records, theme, cursor) and Sfx (audio)
  world/           grid-built arenas (the keep and the boss arena), the goblin, pixelated world view
  player/          first-person controller and class kits
  enemies/         data-driven enemy AI (flow-field navigation, pain states, boss phases)
  combat/          projectiles, effects, loot
  modes/           survival director (nights, dawn market, boss teleport)
  ui/              HUD widgets, menus, black market, score screen
  data/            classes, enemies, boons
tools/             procedural generators for art, UI and audio
assets/            generated assets (+ the OFL font)
docs/screenshots/  images for this README
```

## Roadmap

- [ ] Online mode with other players
- [ ] More champions and more abilities per class
- [ ] More enemy types and bosses, more arenas
- [ ] Controller support
- [ ] Settings for key rebinding and graphics

## Contributing

Development happens feature by feature, with one focused commit per feature or fix, using
[Conventional Commits](https://www.conventionalcommits.org/) prefixes (`feat:`, `fix:`, `art:`, `docs:`, `refactor:`).

## Credits & licenses

- Game code, procedural generators and all generated art, sound and music: the Dreadhold authors.
  No open-source license has been chosen for these yet, so all rights are reserved for now.
- Font: **Pixelify Sans**, © The Pixelify Sans Project Authors, licensed under the
  [SIL Open Font License 1.1](assets/fonts/ofl/PixelifySans-OFL.txt).
