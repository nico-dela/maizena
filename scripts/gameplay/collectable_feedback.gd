extends RefCounted

## Bob y brillo mientras el objeto espera. Al recogerlo, sube y se apaga.

const IDLE_LIFT := 3.0
const IDLE_HALF_SEC := 0.55
const GLOW := Color(1.22, 1.16, 0.82, 1.0)
const PICKUP_SEC := 0.34
const PICKUP_LIFT := 12.0
const PICKUP_SCALE := 1.4

const _TWEEN_META := "collectable_tweens"


static func start_idle(sprite: Node2D) -> void:
	if sprite == null:
		return
	stop_idle(sprite)
	var base_y: float = sprite.position.y
	var bob := sprite.create_tween().set_loops()
	bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(sprite, "position:y", base_y - IDLE_LIFT, IDLE_HALF_SEC)
	bob.tween_property(sprite, "position:y", base_y, IDLE_HALF_SEC)
	var glow := sprite.create_tween().set_loops()
	glow.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow.tween_property(sprite, "modulate", GLOW, 0.7)
	glow.tween_property(sprite, "modulate", Color.WHITE, 0.7)
	sprite.set_meta(_TWEEN_META, [bob, glow])


static func play_pickup(sprite: Node2D, on_done: Callable) -> void:
	stop_idle(sprite)
	if sprite == null:
		_call_done(on_done)
		return
	var tw := sprite.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", sprite.scale * PICKUP_SCALE, PICKUP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", sprite.position.y - PICKUP_LIFT, PICKUP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 0.0, PICKUP_SEC)
	tw.chain().tween_callback(_call_done.bind(on_done))


static func stop_idle(sprite: Node2D) -> void:
	if sprite == null or not sprite.has_meta(_TWEEN_META):
		return
	for entry in sprite.get_meta(_TWEEN_META):
		if entry is Tween and (entry as Tween).is_valid():
			(entry as Tween).kill()
	sprite.remove_meta(_TWEEN_META)


static func _call_done(on_done: Callable) -> void:
	if on_done.is_valid():
		on_done.call()
