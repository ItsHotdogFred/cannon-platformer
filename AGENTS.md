# AGENTS.md — Cannon Platformer

> **This file is the source of truth for AI agents (and humans) working in this
> workspace. It must be kept up to date as the project evolves.**
> **If you change something about the project — controls, scene layout, a new
> mechanic, the level count, autoloads, build steps, or anything else documented
> here — update this file in the same change.**

---

## Workspace Reference (AFFiNE)

This project has an AFFiNE workspace. Before answering design / level-design /
narrative questions, or when the user asks you to "check the docs", look in
AFFiNE for design notes, level plans, art direction, and any in-progress
brainstorms. Design intent lives in AFFiNE; the implementation lives here in
this Godot project. When the two diverge, fix this file and/or the AFFiNE doc
so they agree.

---

## Project Snapshot

- **Engine:** Godot **4.7**, GL Compatibility renderer, 2D project.
- **Physics:** 3D physics engine is set to **Jolt Physics** (unused — this is a
  2D project; the setting is leftover/forward-looking and can be ignored for
  gameplay work).
- **Main scene:** `main.tscn` (uid `uid://df1tjmqe6msdq`).
- **Display:** 320×180 internal viewport with `canvas_items` stretch mode
  (no window-size override). Pixel snapping is on for both transforms and
  vertices — treat the pixel grid as authoritative.
- **Autoloads:**
  - `Gamemanager` — game state singleton.
  - `_mcp_game_helper` — provided by the `godot_ai` editor plugin; do not
    touch.
- **Editor plugin enabled:** `res://addons/godot_ai/plugin.cfg` (the Godot AI
  MCP server). Write operations from MCP tools require an active editor
  session — call `session_activate` / `session_manage(op="list")` first.

### Core gameplay identity

A 2D **cannon-style platformer**: the player has no walk input. **All motion
comes from cannon recoil** — clicking fires the player opposite the cursor and
adds an impulse to a persistent `momentum` vector. The player can also fire a
short-range **grappling hook** (Space / right-click) to swing off surfaces.
Levels are short single-screen-or-multi-screen rooms strung together in
`main.tscn`.

---

## Current State of the Project

### Levels
- **10 levels** shipped: `Level_01.tscn` … `Level_10.tscn`. Levels are combined
  inside `main.tscn` (the world is a big level container, not a level-select
  screen). The most recent additions are `Level_08.tscn`, `Level_09.tscn`, and
  `Level_10.tscn`.
- The world uses a **screen-by-screen camera** (see Camera below), so each
  level is sized as one or more 320×180 rooms. Use this grid when placing
  geometry — the camera snaps to room centers.

### Mechanic: player subsystems
`player.gd` is a thin orchestrator (~107 lines). The real work lives in
three sibling `Node`s that are `add_child`'d in `_ready` and `bind`-ed
to the player:
- `res://player/movement.gd` — cannon recoil (`speed`),
  `friction_air` / `friction_ground`, `gravity_scale * gravity`, the
  `set_active` deferral rule, and `momentum`. Owns `_can_shoot` + the
  `ShootTime` timer signal.
- `res://player/grapple_controller.gd` — raycast aim, range check,
  hook instantiation, `cancel` / `clear` lifecycle. Fires
  `on_attach` / `on_release` so movement can disable / re-enable
  physics.
- `res://player/death_sequence.gd` — the entire `die()` cascade
  (hitstop → burst → hold → respawn → reappearance). `start()` and
  `reset()` are its public surface.

Tunables for each subsystem are exported on the subsystem itself, not
on `player.gd` (except `noclip_speed`, which is a player-level debug
toggle).

Public surface that other systems (spikes, hook) call on the player:
`die()`, `respawn()`, `set_active(active)` (proxies to movement),
`momentum` (getter/setter that proxies to movement), and
`clear_grappling_hook(hook)`. Don't add new public methods on
`player.gd` without checking — extend the subsystem instead.

### Mechanic: arcade death sequence
The player no longer instant-teleports on death. On hitting a spike (or any
death trigger) the game plays:
1. **Hitstop** (~0.12 s) while the death burst begins.
2. **Particle burst** at the death position (`death_burst.tscn`).
3. **Hold** (~0.35 s) with the sprite hidden.
4. **Soft respawn** at the checkpoint / `starting_pos` (with camera
   re-focus if the checkpoint is on a different screen).
5. **Immediate reappearance** at normal size, opacity, and brightness.
Tunables live in `player.gd` under the **Death** export group:
`death_hitstop` and `death_hold`.

### Mechanic: grappling hook
- Range: `max_grapple_distance` (default **72 px**, on
  `player/grapple_controller.gd`).
- Triggered by the `interaction` action (Space / right-click). Aims along the
  cursor via a `RayCast2D` child of the player; capped so out-of-range hits
  don't attach.
- The grapple physics hook stays in the gameplay physics tree, while its rope
  `Line2D` is reparented under `ScreenCamera` and positioned in camera-local
  coordinates for rendering, including while screen transitions pause physics.
- The `SubViewportContainer` follows `ScreenCamera` so the overlay remains
  aligned as the player crosses room boundaries.
- Cancels safely on death (`cancel_grappling_hook(reactivate_player: false)`)
  and on entering noclip.
- `set_active(false)` (disables physics + collision) runs **deferred** because
  death fires from `Area2D.body_entered` — inline `disabled = true` is ignored
  inside physics callbacks. Keep this in mind for any new physics-trigger
  deaths.

### Mechanic: camera
`screen_camera.gd` is a metroidvania-style **screen-locked camera**:
- One camera = one room; moving off the current 320×180 cell triggers a
  **screen transition**.
- During the transition the whole `SceneTree` is paused
  (`get_tree().paused = true`) so the player can't fall into the next room
  mid-pan. The camera itself runs at `PROCESS_MODE_ALWAYS` so the tween
  finishes.
- Has a `shake(duration, intensity)` helper used by future impacts.
- The root-level `background.tscn` stays outside the gameplay `SubViewport`;
  `background.gd` mirrors the SubViewport camera position so its `Parallax2D`
  layers still scroll during gameplay and camera transitions.
- A `.backup` of an older version sits next to the script — it's stale, leave
  it alone unless explicitly asked to clean up.

### Mechanic: noclip
- Toggle with **F** (`noclip` action). Disables collision, gravity, and cannon
  physics; free-fly with WASD/arrows at `noclip_speed` (200).
- Sprite modulates to 50% alpha while noclipping.
- Cancels any active grappling hook on toggle.

### Other systems in place
- **Cursor indicator** (`player/cursor_indicator.tscn` / `.gd`) — screen-space reload
  wheel parented under `ScreenCamera` and positioned in camera-local screen
  coordinates, so it stays pinned during room transitions. Its exported player
  reference supplies the shoot timer.
- **Checkpoints** (`checkpoint.gd` / `.tscn`) — sets `player.starting_pos`.
- **Stars / collectibles** (`star.gd` / `.tscn`).
- **Spikes** (`spike.gd` / `.tscn`) — Area2D that calls `player.die()`.
- **Icy block** (`icy_block.gd` / `.tscn` + `icy_block_spriteframes.tres`) —
  a **falling** platform: when the player steps on it, it falls. Most recent
  feature (see latest commit `e42d335`).
- **Moving platform** (`world/hazards/moving_platform.tscn` +
  `moving_platform_controller.gd`) — a moving platform hazard.
- **Fragment particles** (`fragment.gd`) — a fragment can map shared
  `GPUParticles2D` nodes to string identifiers. The active `Level`'s
  `FragmentParticles` identifiers control which shared effects emit as the
  screen camera changes rooms.
- **Sound** (`sound.gd`) — autoload-style helper + a UI mute toggle wired
  into the HUD. The "shoot" and other SFX route through the `AudioStreamPlayer2D`
  on the player. The script respects the "ignore clicks on Controls when
  firing" rule so UI buttons don't trigger cannon shots.

### Input map (project.godot)
| Action         | Binding                          |
|----------------|----------------------------------|
| `shoot`        | Left mouse button                |
| `interaction`  | Space, Right mouse button        |
| `left`         | A, Left arrow                    |
| `right`        | D, Right arrow                   |
| `up`           | W, Up arrow                      |
| `down`         | S, Down arrow                    |
| `noclip`       | F (debug)                        |

---

## What the User Is Currently Working On

The user is **iterating on level design and adding new mechanics**. Recent
trajectory (read from `git log` + uncommitted changes):

1. **Building out later levels** — Levels 6–9 are recent. Expect to keep
   adding rooms that use the screen-locked camera, the grappling hook, and
   the falling icy block.
2. **Polishing death feel** — the arcade burst replaced instant teleport;
   expect further tweaks to hitstop, hold, and respawn timing.
3. **Adding new platforming mechanics** — the falling icy block and the
   moving platform are both in flight. Treat these as **active WIP**:
   - `icy_block.gd` / `icy_block.tscn` are modified but not committed.
   - `moving_platform*` files are entirely untracked.
4. **UI polish** — mute toggle is in; clicks are now ignored when the mouse
   is over a Control. Expect more HUD work.

### Conventions to follow
- **All motion = cannon recoil.** Don't add WASD walking. If a new mechanic
  needs movement, it should compose with `momentum` (add/subtract), not
  overwrite it.
- **Friction dampens horizontal momentum only.** Vertical is left alone so
  cannon arcs feel right. `friction_air` is 50, `friction_ground` is 500
  (both exports on `player.gd`).
- **Pixel grid is sacred.** Vertex + transform snapping is on. Place
  geometry on integer coordinates.
- **Death must go through `player.die()`.** New spikes/hazards: Area2D
  with `body_entered` → `player.die()`. Don't teleport the player directly.
- **Death burst rebuild:** `world/props/death_burst.tscn` emits the player
  image mask at the death position, then its pixels travel individually to
  the live checkpoint and rebuild the player there. The respawn sequence must
  pass the checkpoint target to `DeathBurst.play_at()`; do not add a separate
  respawn puff that duplicates this effect.
- **Camera transitions pause the tree.** New physics that runs during a
  transition must use `PROCESS_MODE_ALWAYS` or be deferred to after the
  pan finishes.
- **Defer collision shape changes from physics callbacks** (see
  `set_active` in `player.gd`).
- **Respect UI input** — when adding click-to-fire logic, gate it with
  `get_viewport().gui_get_hovered_control() == null`.
- **Autoloads:** don't add new singletons without checking with the user;
  the world state should keep flowing through `Gamemanager` and `player`.

---

## File Map (quick reference)

Top-level layout is **by domain**, not by file type. Scripts and scenes
for a feature live together.

| Path                              | Role                                    |
|-----------------------------------|-----------------------------------------|
| `project.godot`                   | Project config, input map, autoloads    |
| `main.tscn` / `main.gd`           | World root, contains all level sub-scenes |
| `background.tscn` / `background.gd` | Root-level parallax background synced to the SubViewport camera |
| `assets/jumpstart/Jumpstart Legacy/` | Third-party asset pack (CC0 Jumpstart) |
| `audio/sfx/`                      | Sound effects                           |
| `audio/music/`                    | Music tracks                            |
| `fonts/silkscreen/`               | Silkscreen pixel font                   |
| `icons/`                          | UI icons                                |
| `core/`                           | Autoloads (singletons)                  |
| `core/gamemanager.gd`             | Game-state singleton                    |
| `ui/`                             | UI scripts attached to main scene HUD   |
| `ui/sound.gd`                     | Sound helper / mute toggle              |
| `ui/label.gd`                     | UI label helper                         |
| `world/player/`                   | Player subsystems (cannon, grapple, death) |
| `world/player/player.gd/.tscn`    | Player: input dispatch + delegates     |
| `world/player/movement.gd`        | Cannon recoil, friction, gravity, collision, momentum |
| `world/player/grapple_controller.gd` | Grapple raycast + hook lifecycle     |
| `world/player/death_sequence.gd`  | Arcade death cascade (hitstop → burst → respawn → reappearance) |
| `world/player/cursor_indicator.tscn` / `.gd` | Screen-space mouse cursor and reload wheel; instanced in `main.tscn` |
| `world/camera/screen_camera.gd`   | Screen-locked camera + shake            |
| `world/hazards/`                  | Anything that hurts the player          |
| `world/hazards/spike.gd/.tscn`    | Death hazard (Area2D)                   |
| `world/hazards/icy_block.gd/.tscn` | Falling platform (WIP)                 |
| `world/hazards/moving_platform.tscn` + `moving_platform_controller.gd` | Moving platform (WIP) |
| `world/props/`                    | Interactive world objects               |
| `world/props/checkpoint.gd/.tscn` | Checkpoint trigger                      |
| `world/props/star.gd/.tscn`       | Collectible                             |
| `world/props/death_burst.gd/.tscn` | Particle burst on death / respawn    |
| `world/props/grappling_hook.gd/.tscn` | Grapple projectile / swing         |
| `world/levels/fragment.gd` / `fragment.tscn` | Shared particle effect controller |
| `world/levels/fragment_container.tscn` | Combined level container and shared particle nodes |
| `world/levels/background_particle.gd` | Shared level background particle behavior |
| `world/levels/Level_01.tscn` … `Level_10.tscn` | Individual level rooms    |
| `addons/godot_ai/`                | Godot AI MCP plugin (managed)           |

**Adding a new hazard / prop / level**: drop the `.gd` + `.tscn` pair
into the matching `world/hazards/`, `world/props/`, or `world/levels/`
folder. No path rewriting needed for the move — just write relative
`res://` paths from where the new file lives.

---

## Working With This Repo (for agents)

- **Read this file first** whenever you start a new session. If something
  here is wrong or stale, fix it before doing the task.
- **Use the Godot AI MCP server** for live edits — `session_activate` →
  `scene_get_hierarchy` / `node_get_properties` before mutating. Avoid
  editing `.tscn` files by hand unless you have to.
- **Tests:** there is no test suite yet. Verify changes by running the
  project (`project_run` with `mode="main"` or `"current"` for the level
  you touched) and checking `logs_read(source="game")` +
  `editor_screenshot`.
- **Backup files:** none. Don't create new `.backup` files — use git
  instead.
- **Uncommitted work is real work.** Check `git status` before tidying
  the working tree.

---

## Update Policy for This File

Whenever any of the following changes, **update this file in the same
commit / change**:

- A new level is added or one is removed.
- A new mechanic is added (new `.gd`/`.tscn` pair, new input action, new
  autoload).
- The death sequence timing, grapple range, movement model, or friction
  values change.
- The camera behavior changes (transition duration, pause model, room
  size).
- The input map in `project.godot` changes.
- The main scene, autoloads, display resolution, or renderer settings
  change.
- A new file becomes a meaningful part of the project (move it from
  "untracked WIP" into the File Map and describe it).
- The user shifts focus to a new area of work — update "What the User Is
  Currently Working On" so the next agent knows where to pick up.

**Keep this file the single source of truth for "how this project works
right now."** Stale docs are worse than no docs.
