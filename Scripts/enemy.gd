extends CharacterBody2D

@export var chase_divisor: float = 30.0
@export var health: int = 3
var player: Player = null
var dead := false
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## adds enemies to a group to make fireflies attack
func _ready() -> void:
	add_to_group("enemies")

## chases the player every frame
func _physics_process(_delta: float) -> void:
	if dead:
		return

	if player:
		position += (player.global_position - global_position) / chase_divisor
		sprite.play("default")

	else:
		sprite.stop()
		sprite.frame = 0


## called when a firefly hits it
func hit(direction: Vector2) -> void:
	if dead:
		return

	## loses health and gets knocked back
	health -= 1
	position += direction * 6.0

	## dies: turns off collision, squashes and fades out, then deletes itself
	if health <= 0:
		dead = true
		$CollisionShape2D.set_deferred("disabled", true)
		var tween := create_tween().set_parallel()
		tween.tween_property(self, "scale", Vector2(1.4, 0.2), 0.3)
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(queue_free)


## starts chasing when the player gets close
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		player = body


## stops chasing when the player gets away
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		player = null
