extends CharacterBody2D
class_name Player

@export var speed: float = 100.0
## how quickly it speeds up and slows down (0-1)
@export var acceleration: float = 0.05
@export var camera_zoom: float = 4.0

## the feet are a bit below the center, used for floor checks
const FOOT_OFFSET := Vector2(0, 6)
const FIREFLY_SCENE := preload("res://Scenes/firefly.tscn")

## last direction pressed, used for hopping
var facing := Vector2i.RIGHT
var level: Level
var hint_timer: SceneTreeTimer
## so the hop hint only shows once per game
static var hop_hint_shown := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var firefly_label: Label = $HUD/FireflyCount
@onready var hint_label: Label = $HUD/Hint


## joins the player group, shows the HUD, fits the camera and shows the level's hint
func _ready() -> void:
	add_to_group("player")
	level = Level.of(self)
	$HUD.visible = true
	if level:
		_fit_camera(level.bounds())
		if not level.start_hint.is_empty():
			show_hint(level.start_hint, 5.0)


## updates the firefly counter
func _process(_delta: float) -> void:
	firefly_label.text = "Fireflies: %d" % Firefly.collected


## E sends a firefly
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		send_firefly()


## reads WASD, shows the hop hint near a gap, then hops or walks and animates
func _physics_process(_delta: float) -> void:
	var held := Vector2i(signi(int(Input.get_axis("A", "D"))), signi(int(Input.get_axis("W", "S"))))
	if held != Vector2i.ZERO:
		facing = held
	if not hop_hint_shown and level and level.hop_target(level.cell_at(feet()), facing) != level.cell_at(feet()):
		hop_hint_shown = true
		show_hint("Space: hop the gap")
	if Input.is_action_just_pressed("jump"):
		hop()
	else:
		walk(Vector2(held))
	sprite.play("walk" if held != Vector2i.ZERO else "idle")
	if held.x != 0:
		sprite.flip_h = held.x < 0


## moves, and stops you from walking off the floor by sliding along the edge
func walk(dir: Vector2) -> void:
	velocity = velocity.lerp(dir * speed, acceleration)
	var before := global_position
	move_and_slide()
	if level and not on_floor(global_position) and on_floor(before):
		for slide in [Vector2(global_position.x, before.y), Vector2(before.x, global_position.y), before]:
			if on_floor(slide):
				global_position = slide
				velocity = Vector2.ZERO
				return


## Space: jumps to the tile across the gap
func hop() -> void:
	if not level:
		return
	var cell := level.cell_at(feet())
	## which half of the tile you're on, so staggered stones pick the closer side
	var side := 1 if (feet() - level.cell_center(cell)).dot(Vector2(-facing.y, facing.x)) >= 0 else -1
	var target := level.hop_target(cell, facing, side)
	if target != cell:
		global_position = level.cell_center(target) - FOOT_OFFSET
		velocity = Vector2.ZERO


## uses one caught firefly and sends it out as a scout
func send_firefly() -> void:
	if Firefly.collected <= 0:
		show_hint("No fireflies to send. Catch some first!")
		return
	Firefly.collected -= 1
	var firefly: Firefly = FIREFLY_SCENE.instantiate()
	firefly.state = Firefly.State.SCOUT
	level.add_child(firefly)
	firefly.global_position = global_position + Vector2(0, -10)


## position of the feet
func feet() -> Vector2:
	return global_position + FOOT_OFFSET


## true if the feet would be on floor with the body here
func on_floor(body_pos: Vector2) -> bool:
	return level.is_floor(body_pos + FOOT_OFFSET)


## shows text at the bottom of the screen for a few seconds
func show_hint(text: String, seconds: float = 2.5) -> void:
	hint_label.text = text
	hint_label.visible = true
	var timer := get_tree().create_timer(seconds)
	hint_timer = timer
	## only hides it if no newer hint replaced this one
	timer.timeout.connect(func(): if hint_timer == timer: hint_label.visible = false)


## zooms in and keeps the camera inside the level, centering it if the level is smaller than the screen
func _fit_camera(area: Rect2) -> void:
	camera.zoom = Vector2.ONE * camera_zoom
	var view := get_viewport_rect().size / camera.zoom
	var rect := area
	if area.size.x < view.x:
		rect.position.x = area.get_center().x - view.x / 2
		rect.size.x = view.x
	if area.size.y < view.y:
		rect.position.y = area.get_center().y - view.y / 2
		rect.size.y = view.y
	camera.limit_left = floori(rect.position.x)
	camera.limit_top = floori(rect.position.y)
	camera.limit_right = ceili(rect.end.x)
	camera.limit_bottom = ceili(rect.end.y)
	camera.reset_smoothing()
