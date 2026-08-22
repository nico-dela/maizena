extends Node2D

const TILE_SIZE := 16
## With CanvasLayer.follow_viewport_enabled, fog sorts by world z_index vs NPCs/props.
## Must sit above InteractiveObjects (typically z=1) and outliers like Spinetto.
const FOG_Z_INDEX := 4096

@onready var _sprite: Sprite2D = $FogSprite

var _discovery: Node


func _ready() -> void:
	z_as_relative = false
	z_index = FOG_Z_INDEX
	if _sprite != null:
		_sprite.z_as_relative = true
		_sprite.z_index = 0


func bind(discovery: Node) -> void:
	if _discovery != null and _discovery.has_signal("exploration_updated"):
		if _discovery.exploration_updated.is_connected(_on_exploration_updated):
			_discovery.exploration_updated.disconnect(_on_exploration_updated)
	_discovery = discovery
	if _discovery != null and _discovery.has_signal("exploration_updated"):
		_discovery.exploration_updated.connect(_on_exploration_updated)
	_refresh()


func _on_exploration_updated(_map_id: String) -> void:
	_refresh()


func _refresh() -> void:
	if _discovery == null or _sprite == null:
		visible = false
		return
	var bounds: Rect2 = _discovery.world_bounds
	if bounds.size == Vector2.ZERO:
		visible = false
		return
	var tex: Texture2D = _discovery.get_fog_texture() if _discovery.has_method("get_fog_texture") else null
	if tex == null:
		visible = false
		return
	visible = true
	z_as_relative = false
	z_index = FOG_Z_INDEX
	position = bounds.position
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	_sprite.scale = Vector2(TILE_SIZE, TILE_SIZE)
