class_name WorldViewportHost
extends Control
## Hosts the world scene in a SubViewport rendered at a low logical
## resolution, then displays it scaled up with nearest-neighbor
## filtering — this "low-res canvas blitted up hard" is what render.js
## explicitly relies on for its chunky pixel-art look (see its header
## comment: "reads as pixel art rather than modern shapes with a
## pixelated filter"). Drawing the same shapes directly at full display
## resolution would lose that on purpose, so it's ported too, via
## SubViewport + a nearest-filtered TextureRect. Logical resolution
## follows the original's resize(): pixelSize = clamp(round(w/480),2,5).

var _sub_viewport: SubViewport
var _texture_rect: TextureRect
var _world: WorldScene
var _last_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	UiUtil.fill_parent(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_sub_viewport = SubViewport.new()
	_sub_viewport.transparent_bg = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub_viewport)

	_world = WorldScene.new()
	_sub_viewport.add_child(_world)

	_texture_rect = TextureRect.new()
	UiUtil.fill_parent(_texture_rect)
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.texture = _sub_viewport.get_texture()
	add_child(_texture_rect)

# _last_size starts at ZERO precisely so the first call here (whatever
# frame `size` actually resolves to something real — see the same
# Container-timing lesson from the Chaos Tree viewport) always counts
# as a change and builds the world at least once.
func _process(_delta: float) -> void:
	var display_size: Vector2 = size
	if display_size.x < 1.0 or display_size.y < 1.0:
		return
	if display_size.is_equal_approx(_last_size):
		return
	_last_size = display_size

	var pixel_size: int = clampi(int(round(display_size.x / 480.0)), 2, 5)
	var logical_w: float = max(160.0, ceil(display_size.x / pixel_size))
	var logical_h: float = max(100.0, ceil(display_size.y / pixel_size))

	_sub_viewport.size = Vector2i(int(logical_w), int(logical_h))
	_world.build(logical_w, logical_h)
