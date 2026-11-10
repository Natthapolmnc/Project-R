# Godot enemy combat / stance controller

Godot 4.5+ GDScript files:

- `enemy.gd` — encounter clock, action queue, stance changes, combat state and player-facing windows; uses one AnimationPlayer.
- `enemy_move.gd` — one authored attack/trick, its AnimationPlayer clip and stance transition.
- `enemy_profile.gd` — enemy personality, available moves and idle animation for each stance.
- `sequence_generator.gd` — static generator for absolute `time,action` sequence entries.
- `character_resource.gd` — HP and stability.
- `combat_effects.gd` — global particle, camera-shake and screen-flash controller.
- `combat_effect_preset.gd` — editable per-effect settings shared by player and enemy.
- `combat_fx.tscn` — ready-to-configure scene for the global `CombatFX` Autoload.
- `combat_fx_example.tscn` — example global manager with two configured effect presets.
- `example_sparks.tscn` — simple CPUParticles3D sparks used by the example presets.

## Scene setup

```text
Enemy (Node3D; enemy.gd)
├── Visual (Sprite3D, MeshInstance3D, etc.; animated by AnimationPlayer)
├── Timing (AnimationPlayer)
└── EffectOrigin (Marker3D; optional)

/root/CombatFX (global Autoload; combat_fx.tscn)
```

Assign `Timing` to **Timing Player** on the Enemy node. This is now the **only animation controller**: it plays idle, attack, trick, down and death clips. You do not need `AnimatedSprite3D`, and there is no `AnimatedSprite3D` export on Enemy. Use AnimationPlayer property tracks to animate your chosen Visual node (e.g., change Sprite3D textures, frame, pose, scale or transforms), and method tracks to control combat windows. Create and assign an `EnemyProfile` and a `CharacterResource` in the Inspector. **Idle clips should loop; attack, trick and down clips must not loop**. Optionally assign `EffectOrigin` to **Effect Origin**; otherwise the enemy's transform is used for particles.

**Required global setup:** Project → Project Settings → Globals → Autoload: add `res://enemy_combat/combat_fx.tscn` and name it **`CombatFX`**. This is shared by every player and enemy instance. Open `combat_fx.tscn` in the editor to configure reusable effect presets.

**Try the prepared example:** Instead, register `res://enemy_combat/combat_fx_example.tscn` under the same Autoload name, **`CombatFX`**. The example contains two presets—`enemy_slash` (warm impact) and `player_parry` (cool blue flash)—both using `example_sparks.tscn`. You should register only **one** CombatFX Autoload, either the blank or example scene.

The player and enemy remain stationary. Stances are visual poses, not world positions.

### Create an EnemyProfile resource

Example:

- `initial_stance = "left"`
- `idle_by_stance = { &"left": &"idle_left", &"right": &"idle_right" }`
- `sequence_pattern = Delay Before Attack` (or Random)
- `moves` contains `EnemyMove` resources, for example:
  - Attack: `from_stance = "left"`, `to_stance = "left"`, `animation_name = "slash_left"`
  - Trick: `from_stance = "left"`, `to_stance = "right"`, `animation_name = "trick_left2right"`
  - Include moves for the other stances too, or the controller will warn and skip an unavailable event.

`EnemyMove` makes the stance transition explicit. You no longer need to parse names like `trick_left2right` to deduce which idle comes next.

For compatibility, old `EnemyMove` resources with `timing_animation` or `sprite_animation` fields are still readable through hidden migration properties. **For new moves, set `animation_name`.**

### Configure AnimationPlayer timing clips

Create AnimationPlayer clips named `idle_left`, `idle_right`, `slash_left`, `trick_left2right`, etc., matching the profile's idle names and each move's `animation_name`. Put **visual property tracks and combat method tracks on the same clip**. Add a **Call Method Track** targeting the parent `Enemy` node (for the default AnimationPlayer root, track path `.`). The AnimationPlayer manages both animation playback and combat timings, so there are no separate animation lengths to synchronize.

Example real attack `slash_left` lasting 0.70 s:

| Clip time | Method on Enemy | Arguments | Purpose |
| --- | --- | --- | --- |
| 0.30 | `animation_set_parryable` | `true` | Open parry window |
| 0.46 | `animation_strike` | none | Close parry window and emit `strike_reached` |
| 0.46 | `animation_effect` | `&"enemy_slash"` | Trigger a global effect at the impact frame |

The Enemy has only three states: `PASSIVE`, `ATTACK`, and `DOWN`. `ATTACK` includes both real attacks and tricks. Parryable and attackable are **independent booleans**, controlled by animation calls. Death is queried via `enemy.is_dead()` and signaled via `enemy_died`.

For a trick clip, **do not open a parry window**. At its reveal frame, call `animation_reveal_trick()`. You can open a player attack window on any move by calling `animation_set_attackable(true)` and close it later with `false`.

You no longer need `animation_set_phase()` keys. The method remains as a no-op for compatibility with existing animations. The controller automatically returns to PASSIVE when the non-looping AnimationPlayer move clip finishes.

**Timing warning:** An AnimationPlayer clip that loops will not produce the `animation_finished` event needed for stance changes. Make only your idle clips loop. Set `SequenceGenerator.MIN_GAP` to a safe interval for the authored moves; overdue sequence events wait until the active move ends.

### Player interactions

```gdscript
if enemy.can_be_parried():
	var success := enemy.receive_parry()

if enemy.can_be_attacked():
	var success := enemy.receive_hit()

enemy.strike_reached.connect(_on_enemy_strike)
enemy.trick_revealed.connect(_on_enemy_trick)
enemy.vulnerability_changed.connect(_on_enemy_windows_changed)
```

`receive_parry()` accepts a parry only during a real attack's animation-defined parry window. An accepted parry cancels the current action and reduces stability. At zero stability, the enemy enters DOWN and is attackable. When the non-looping `down` AnimationPlayer clip finishes, stability resets and the enemy resumes its idle stance. A successful attack during DOWN reduces HP.

`strike_reached` is the point where your **player/combat system** should resolve an unblocked hit. This package does not decide player HP or parry input timing for you. A trick has no strike event.

### Sequence timing

`SequenceGenerator.generate(level, duration, pattern)` returns a pattern name and timestamped action codes (`a`/`t`). The timestamps are **absolute seconds since encounter start**, not per-action waits. Enemy uses `elapsed_time` to schedule them.

`EnemyProfile.sequence_pattern` chooses the rhythm profile: Random, Balanced, Rush Then Slow, Delay Before Attack, Burst Pause, Slow Then Rush, Bait And Strike, or Chaotic. `cur_level` chooses the number of attacks and tricks, and `sequence_duration` sets the encounter's overall length.

**Generated versus manual sequence:** On the Enemy Inspector, enable **Auto Generate Sequence** (default) to use the generator. Disable it to use **Manual Sequence**, an editable `Array[String]` such as:

```gdscript
["1.0,t", "3.5,a", "6.0,t", "8.5,a"]
```

`a` means real attack; `t` means trick. Numbers are **absolute seconds after encounter start**, not delays between actions. Manual entries are sorted automatically. Invalid actions or timestamps outside `[0, sequence_duration)` are warned about and skipped. `start_sequence()` reloads the currently selected mode.

`enemy_timeout` emits only once when the countdown reaches zero. The countdown still runs while the enemy is DOWN; change `_process()` if your game should pause it during a finishing opportunity.

### Particle and screen effects

Effects are now **global**, not children of Player or Enemy. Register `combat_fx.tscn` as the `CombatFX` Autoload as described above, then add `CombatEffectPreset` resources to its **Presets** array. Each preset provides:

- **Id:** A name such as `"enemy_slash"` or `"player_parry"`.
- **Particle Scene:** Optional `PackedScene` with `GPUParticles3D` or `CPUParticles3D` (root or descendants).
- **Cleanup Seconds:** Lifetime of the spawned effect scene.
- **Shake Strength / Duration:** Optional camera shake.
- **Flash Color / Duration:** Optional screen flash (alpha 0 disables it).

From Enemy's AnimationPlayer, make a **Call Method Track** targeting Enemy (the existing `.` track). At an impact/reveal frame, call:

```gdscript
animation_effect(&"enemy_slash")
```

The enemy hook forwards to the singleton at `/root/CombatFX`. Add a corresponding hook to your Player script, or call the singleton directly:

```gdscript
# Player.gd, for example after a successful parry:
get_node("/root/CombatFX").trigger(&"player_parry", self)

# Direct global screen effects (from any script after Autoload setup):
get_node("/root/CombatFX").shake_screen(0.08, 0.20)
get_node("/root/CombatFX").flash_screen(Color(1.0, 1.0, 1.0, 0.6), 0.15)
```

`CombatFX` creates one full-screen overlay and chooses the active viewport camera automatically. Particle instances are added to the current level at the caller's world transform, then cleaned up. Screen shake changes only camera view offsets, never Player/Enemy world positions. If you remove the old per-enemy `Effects` child from your scene, you won't have duplicate overlays.

### CharacterResource and compatibility

Each Enemy duplicates its `CharacterResource` when ready so runtime HP/stability isn't shared between enemies. `CharacterResource.on_start()` resets both values. Existing calls to `enemy.got_parried()` still work (they call `receive_parry()`), but you can now inspect the returned success boolean from `receive_parry()` directly.
