extends CharacterBody2D
class_name Firefly

## SPECIAL BEE MECHANIC!!
## Here are different modes of behaviour for the bee: 
## IDLE = floating, can be caught. GUIDE = leads you to the chest.
## SCOUT = sent with E. BURST = flying out of the chest. CAUGHT = being collected.
enum State { IDLE, GUIDE, SCOUT, BURST, CAUGHT }

## bee inventory
static var collected := 0

## what the guide firefly leads to (e.g. the chest)
@export var guide_target: NodePath
const SPEED := 45.0
const ATTACK_SPEED := 110.0
const SIGHT := 56.0
const NEAR := 40.0
const LEAD_TILES := 3
var state := State.IDLE
var home := Vector2.ZERO
var route := PackedVector2Array()
var route_age := 0.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## turns on/off collisions, based on the behaviour type
func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	home = global_position
	sprite.play("flying")
	if not guide_target.is_empty():
		state = State.GUIDE
		add_to_group("guide_fireflies")

## does whatever its state says, based on player location
func _physics_process(delta: float) -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	match state:
		State.IDLE: _idle(player, delta)
		State.GUIDE: _guide(player, delta)
		State.SCOUT: _scout(player, delta)

## gets caught if touched, dodges a little if the player is close, otherwise floats back home
func _idle(player: Player, delta: float) -> void:
	if $Area2D.overlaps_body(player):
		catch()
	elif global_position.distance_to(player.global_position) < NEAR:
		var away := global_position + (global_position - player.global_position).normalized() * 8.0
		if away.distance_to(home) < 14.0:
			_fly_to(away, SPEED * 0.6, delta)
	else:
		_fly_to(home, SPEED * 0.3, delta)

## flies toward the chest only while the player is following
func _guide(player: Player, delta: float) -> void:
	if global_position.distance_to(player.global_position) < NEAR:
		_fly_to(get_node(guide_target).global_position + Vector2(8, -6), SPEED, delta)

## attacks nearby enemies, otherwise shows the player the way to the chest or exit
func _scout(player: Player, delta: float) -> void:
	## flies at the enemy, hits it, then bounces back
	var enemy := _enemy_in_sight()
	if enemy:
		_fly_to(enemy.global_position, ATTACK_SPEED, delta)
		if global_position.distance_to(enemy.global_position) < 6.0:
			var dir := (enemy.global_position - global_position).normalized()
			enemy.hit(dir)
			global_position -= dir * 20.0
		return

	## re-plans the path every half second
	route_age -= delta
	if route_age <= 0.0:
		route_age = 0.5
		var level := Level.of(self)
		route = level.find_path(player.feet(), level.current_goal())

## returns the first living enemy within sight, or null
func _enemy_in_sight() -> Node2D:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.dead and global_position.distance_to(enemy.global_position) < SIGHT:
			return enemy
	return null

## moves toward a point and faces the way it's going
func _fly_to(point: Vector2, speed: float, delta: float) -> void:
	global_position = global_position.move_toward(point, speed * delta)
	if absf(point.x - global_position.x) > 0.5:
		sprite.flip_h = point.x < global_position.x

## becomes a normal catchable firefly that floats where it is
func release() -> void:
	state = State.IDLE
	home = global_position

## adds to the count, shows the E hint
func catch() -> void:
	state = State.CAUGHT
	collected += 1
	if collected == 1:
		get_tree().get_first_node_in_group("player").show_hint("Press E to send a firefly ahead. It lights the way and fights slimes.", 4.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
