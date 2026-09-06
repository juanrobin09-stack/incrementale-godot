extends Node
## Incrementable — runtime audio/display settings. Autoloaded as
## `GameSettings`, after `GameState` (needs GameState.state.settings ready
## to apply persisted values on startup). Deliberately its own autoload
## rather than folded into GameState: GameState's own header already lists
## "notifications/sound" as out of its scope — this owns actually driving
## AudioServer/DisplayServer, while GameState still owns persisting the
## chosen values (same save file, same JSON, just two more settings keys —
## see GameState.create_default_state()'s "settings" dict).
##
## No sound effect or music playback exists anywhere in this project yet
## (nothing here ever creates an AudioStreamPlayer) — but moving
## OptionsMenu's sliders has a real, immediate effect on real AudioServer
## bus volumes today, ready for whichever future AudioStreamPlayer routes
## its own `bus` property to "SFX" or "Music". Resolution goes through
## Godot's own Window/DisplayServer APIs end to end, no invented scaling
## system.

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

## Ordinary desktop resolutions, filtered at query time to whatever
## actually fits the real screen this session is running on — see
## get_available_resolutions().
const CANDIDATE_RESOLUTIONS := [
	Vector2i(1024, 576), Vector2i(1152, 648), Vector2i(1280, 720),
	Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

func _ready() -> void:
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	_apply_bus_volume(SFX_BUS, get_sfx_volume())
	_apply_bus_volume(MUSIC_BUS, get_music_volume())

	var w: int = GameState.state.settings.get("resolution_w", 0)
	var h: int = GameState.state.settings.get("resolution_h", 0)
	if w > 0 and h > 0:
		get_window().size = Vector2i(w, h)

## Idempotent — safe to call every launch. There is no default_bus_layout
## resource in this project (none existed before this file), so the SFX/
## Music buses are recreated in code on every startup rather than relying
## on a saved layout this environment has no editor to author/verify.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func get_sfx_volume() -> float:
	return GameState.state.settings.get("sfx_volume", 1.0)

func set_sfx_volume(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	GameState.state.settings.sfx_volume = v
	_apply_bus_volume(SFX_BUS, v)
	GameState.save_game()

func get_music_volume() -> float:
	return GameState.state.settings.get("music_volume", 1.0)

func set_music_volume(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	GameState.state.settings.music_volume = v
	_apply_bus_volume(MUSIC_BUS, v)
	GameState.save_game()

func _apply_bus_volume(bus_name: String, v: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, v <= 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(v, 0.0001)))

func get_available_resolutions() -> Array:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var out: Array = []
	for res in CANDIDATE_RESOLUTIONS:
		if res.x <= screen_size.x and res.y <= screen_size.y:
			out.append(res)
	if out.is_empty():
		out.append(get_current_resolution())
	return out

func get_current_resolution() -> Vector2i:
	return get_window().size

func set_resolution(size: Vector2i) -> void:
	get_window().size = size
	GameState.state.settings.resolution_w = size.x
	GameState.state.settings.resolution_h = size.y
	GameState.save_game()
