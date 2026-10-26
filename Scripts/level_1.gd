extends Node2D

func _on_area_2d_body_entered(body) -> void:
	if body is Player:
		get_tree().change_scene_to_file("nexroompath")
