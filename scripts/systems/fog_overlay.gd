extends Node2D

const TILE_SIZE := 16
const LIGHT_RADIUS := 240.0
const LIGHT_SOFT := 48.0
const FogShader := preload("res://scripts/systems/fog_light.gdshader")
## With CanvasLayer.follow_viewport_enabled, fog sorts by world z_index vs NPCs/props.
## Must sit above InteractiveObjects (typically z=1) and outliers like Spinetto.
const FOG_Z_INDEX := 4096

@onready var _sprite: Sprite2D = $FogSprite

var _discovery: Node
var _light_material: ShaderMaterial


func _ready() -> void:
	z_as_relative = false
	z_index = FOG_Z_INDEX
	if _sprite != null:
		_sprite.z_as_relative = true
		_sprite.z_index = 0
		_light_material = ShaderMaterial.new()
		_light_material.shader = FogShader
		_sprite.material = _light_material


func bind(discovery: Node) -> void:
	_discovery = discovery
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
	_sync_light_radius()


func _process(_delta: float) -> void:
	_sync_light()


func _sync_light_radius() -> void:
	if _light_material == null or _sprite == null:
		return
	var scale_x := maxf(_sprite.scale.x, 0.001)
	_light_material.set_shader_parameter("light_radius", LIGHT_RADIUS / scale_x)
	_light_material.set_shader_parameter("light_soft", LIGHT_SOFT / scale_x)


func _sync_light() -> void:
	if _light_material == null or _sprite == null:
		return
	var hi := get_tree().get_first_node_in_group("hi_follower") as Node2D
	var active := hi != null and is_instance_valid(hi)
	_light_material.set_shader_parameter("light_active", active)
	if not active:
		return
	_light_material.set_shader_parameter("light_local", _sprite.to_local(hi.global_position))
