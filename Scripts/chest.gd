extends Node2D
class_name Chest

const FIREFLY_SCENE := preload("res://Scenes/firefly.tscn")

@export var firefly_count: int = 10
@export var burst_radius: float = 40.0

var is_open := false


func _ready() -> void:
	add_to_group("chests")
	$AnimatedSprite2D.play("Close")


func center() -> Vector2:
	return $Area2D/CollisionShape2D.global_position


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player and not is_open:
		is_open = true
		open.call_deferred(body)


func open(player: Player) -> void:
	$AnimatedSprite2D.play("Open")
	player.show_hint("The chest bursts open! Catch the fireflies!")
	for guide in get_tree().get_nodes_in_group("guide_fireflies"):
		guide.release()
	var level := Level.of(self)
	for i in firefly_count:
		var firefly: Firefly = FIREFLY_SCENE.instantiate()
		firefly.state = Firefly.State.BURST
		level.add_child(firefly)
		firefly.global_position = center()
		var tween := firefly.create_tween()
		tween.tween_property(firefly, "global_position", _scatter_point(level, i), 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(firefly.release)


func _scatter_point(level: Level, i: int) -> Vector2:
	var angle := TAU * i / maxi(firefly_count, 1)
	for attempt in 12:
		var p := center() + Vector2.from_angle(angle + randf_range(-0.4, 0.4)) * randf_range(burst_radius * 0.4, burst_radius)
		if level.is_floor(p):
			return p
	return center()
