extends CharacterBody2D

var speed = 50
var player_avoid:bool = false
var player: Node2D = null
var inventory: int = 0

func _physics_process(delta):
	if player_avoid:
		position += (player.global_position+ global_position)/speed
		$AnimatedSprite2D.play("flying")
	else:
		pass

func _on_area_2d_2_body_entered(body: Node2D) -> void:
	player = body
	player_avoid = true


func _on_area_2d_2_body_exited(body: Node2D) -> void:
	player = body
	player_avoid = false


func _on_area_2d_body_entered(body: Node2D) -> void:
	# Collection UI
	inventory += 1
	$AnimatedSprite2D.play("pop")
	$AnimatedSprite2D.stop()
	$AnimatedSprite2D.frame = 0
