extends KinematicBody2D
class_name Player

var is_main_player = true
var following_target = null
var distance_from_target = 120

const SPEED = 700

var active = true

var max_hit_points = 4
var hit_points = 4

# todo add pushbox physic
var pushboxes = []

var latest_direction = Vector2.DOWN
var movement_direction = Vector2.ZERO
var shooting_direction = Vector2.DOWN

var is_reloading : bool = false

export (PackedScene) var bullet_reference
export (PackedScene) var death_effect

var current_state = "Idle"

var is_invulnerable : bool = false

var target_gun_rotation = 0

var anim = null

signal create_bullet(bullet_instance, start_direction, direction)

func _ready():
	randomize()

func set_anim(anim_scene):
	var new_anim_scene = anim_scene.instance()
	$Sprites.add_child(new_anim_scene)
	$Gun.texture = new_anim_scene.gun_skin
	$Gun.position = new_anim_scene.get_gun_position()
	anim = new_anim_scene

func _process(delta):
	movement_direction = Vector2.ZERO
	shooting_direction = Vector2.ZERO
	
	if active:
		
		if is_main_player:
			
			if Input.is_action_pressed("move_up"):
				movement_direction.y = -1
				latest_direction = Vector2.UP
			if Input.is_action_pressed("move_down"):
				movement_direction.y = 1
				latest_direction = Vector2.DOWN
			if Input.is_action_pressed("move_left"):
				movement_direction.x = -1
				latest_direction = Vector2.LEFT
			if Input.is_action_pressed("move_right"):
				movement_direction.x = 1
				latest_direction = Vector2.RIGHT
		elif following_target != null && weakref(following_target).get_ref():
			if (global_position - following_target.global_position).length() > distance_from_target:
				movement_direction = (following_target.global_position - global_position).normalized()
		
		
		if Input.is_action_pressed("shoot_up"):
			shooting_direction.y = -1
		if Input.is_action_pressed("shoot_down"):
			shooting_direction.y = 1
		if Input.is_action_pressed("shoot_right"):
			shooting_direction.x = 1
		if Input.is_action_pressed("shoot_left"):
			shooting_direction.x = -1
		if Input.is_action_pressed("shoot_up") || Input.is_action_pressed("shoot_down") || Input.is_action_pressed("shoot_right") || Input.is_action_pressed("shoot_left"):
			if !is_reloading:
				is_reloading = true
				shoot()
		
		if shooting_direction != Vector2.ZERO:
			if shooting_direction.x > 0:
				$Sprites.scale.x = 1
			elif shooting_direction.x < 0:
				$Sprites.scale.x = -1
		elif movement_direction != Vector2.ZERO:
			if movement_direction.x > 0:
				$Sprites.scale.x = 1
			elif movement_direction.x < 0:
				$Sprites.scale.x = -1
		
		if Input.is_action_pressed("move_up") || Input.is_action_pressed("move_down") || Input.is_action_pressed("move_left") || Input.is_action_pressed("move_right"):
			set_state("Move")
		else:
			set_state("Idle")
	
	var push_force = Vector2.ZERO
	for pushbox in pushboxes:
		push_force += (global_position - pushbox.global_position).normalized() * 10
	
	move_and_slide(movement_direction.normalized() * SPEED + push_force)
	
	set_gun_sprite()

func set_state(new_state):
	match(new_state):
		"Idle":
			if anim != null && anim is AnimationHandler:
				anim.play_anim("Idle")
		"Move":
			if anim != null && anim is AnimationHandler:
				anim.play_anim("RunForward")
		"Death":
			pass
	if new_state != current_state:
		current_state = new_state

func set_gun_sprite():
	match (shooting_direction):
		Vector2.DOWN:
			target_gun_rotation = PI / 2.0
		Vector2.UP:
			target_gun_rotation = PI * 3.0 / 2.0
		Vector2.RIGHT:
			target_gun_rotation = 0
		Vector2.LEFT:
			target_gun_rotation = PI
		Vector2.RIGHT + Vector2.UP:
			target_gun_rotation =  PI * 7.0 / 4.0
		Vector2.RIGHT + Vector2.DOWN:
			target_gun_rotation = PI / 4.0
		Vector2.LEFT + Vector2.DOWN:
			target_gun_rotation = PI * 3.0 / 4.0
		Vector2.LEFT + Vector2.UP:
			target_gun_rotation =  PI * 5.0 / 4.0
	
	$Gun.rotation = lerp_angle($Gun.rotation, target_gun_rotation, .8)
	
	$Gun.flip_v = cos($Gun.rotation) < 0.0

func shoot():
	if bullet_reference != null:
		var bullet_direction = ($Gun/BulletOrigin.global_position - $Gun.global_position).normalized()
		bullet_direction += shooting_direction * 4
		EventBus.emit_signal("create_bullet", bullet_reference.instance(), 
				$Gun/BulletOrigin.global_position, bullet_direction.normalized())
	EventBus.emit_signal("start_screenshake", 5)
	$Sounds/ShootSound.pitch_scale = 0.4 + randf()
	$Sounds/ShootSound.play()
	$Timers/ReloadTimer.start()

func _on_ReloadTimer_timeout():
	is_reloading = false

func hurt(damage):
	if !is_invulnerable:
		hit_points = max(0, hit_points - damage)
		EventBus.emit_signal("player_health_update", hit_points, max_hit_points)
		if hit_points == 0:
			set_state("Death")
			active = false
			EventBus.emit_signal("player_death")
			EventBus.emit_signal("create_effect", death_effect.instance(), global_position)
			yield(get_tree().create_timer(.1), "timeout")
			queue_free()
		else:
			# $AnimTree.set("parameters/BlinkOneShot/active", 1)
			$Timers/IFrames.start()
			is_invulnerable = true

func _on_HitBox_area_entered(area):
	if area is EnemyHurtBox:
		hurt(area.damage)

func _on_IFrames_timeout():
	is_invulnerable = false
