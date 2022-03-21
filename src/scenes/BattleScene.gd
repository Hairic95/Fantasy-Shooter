extends Node2D

var self_reference = load("res://src/scenes/BattleScene.tscn")
var player_reference = load("res://src/entities/player/Player.tscn")

export (Vector2) var arena_center = Vector2(160, 115)
export (Rect2) var arena_borders

var latest_player_position : Vector2 = Vector2.ZERO

var wave_index = 0

var players = []

var shake_latest_force = 0

var battle_waves = [
	"wave_eyeball_01",
	"wave_specter_02",
	"wave_mixed_01"
]

func _ready():
	
	
	EventBus.connect("create_bullet", self, "create_bullet")
	EventBus.connect("create_effect", self, "create_effect")
	
	EventBus.connect("start_screenshake", self, "start_screenshake")
	
	EventBus.connect("player_death", self, "player_death")
	EventBus.connect("enemy_death", self, "enemy_death")
	
	var player1 = player_reference.instance()
	players.append(player1)
	player1.global_position = $Arena.global_position
	var player2 = player_reference.instance()
	players.append(player2)
	player2.is_main_player = false
	player2.following_target = player1
	var player3 = player_reference.instance()
	players.append(player3)
	player3.is_main_player = false
	player3.following_target = player2
	var player4 = player_reference.instance()
	players.append(player4)
	player4.is_main_player = false
	player4.following_target = player3
	
	$Entities.add_child(player1)
	player1.set_anim(load("res://assets/textures/battle/characters/Soldier/SoldierAnim.tscn"))
	player2.global_position = player1.global_position + Vector2(-120, 0)
	$Entities.add_child(player2)
	player2.set_anim(load("res://assets/textures/battle/characters/Rogue/RogueAnim.tscn"))
	player3.global_position = player2.global_position + Vector2(-120, 0)
	$Entities.add_child(player3)
	player3.set_anim(load("res://assets/textures/battle/characters/Mage/MageAnim.tscn"))
	player4.global_position = player3.global_position + Vector2(-120, 0)
	$Entities.add_child(player4)
	player4.set_anim(load("res://assets/textures/battle/characters/Healer/HealerAnim.tscn"))
	latest_player_position = player1.global_position
	
	# create_wave(battle_waves[0])

func _input(event):
	if Input.is_action_pressed("reset"):
		EventBus.emit_signal("create_scene", self_reference)
	elif Input.is_action_just_pressed("ui_cancel"):
		EventBus.emit_signal("change_scene", "level_select")

func create_bullet(bullet_instance, start_pos, direction):
	bullet_instance.global_position = start_pos
	bullet_instance.direction = direction.normalized()
	$Bullets.add_child(bullet_instance)

func create_effect(effect_instance, start_pos):
	effect_instance.global_position = start_pos
	$Effects.add_child(effect_instance)

func _process(delta):
	if get_first_player() != null && weakref( get_first_player()).get_ref():
		latest_player_position =  get_first_player().global_position
		var new_camera_pos =  lerp($CameraHandler.global_position, get_first_player().global_position, .6)
		$CameraHandler.global_position = new_camera_pos

func create_wave(wave_code):
	var wave_data = WaveCreator.get_wave(wave_code)
	if wave_data != null:
		wave_index += 1
		for enemy_data in wave_data:
			for i in enemy_data.quantity:
				var enemy_instance = enemy_data.reference.instance()
				enemy_instance.player =  get_first_player()
				enemy_instance.arena_borders = arena_borders
				enemy_instance.latest_player_position = latest_player_position
				#if enemy_instance is SpecterEnemy:
				var starting_angle = 2 * PI / enemy_data.quantity * i
				enemy_instance.global_position = arena_center + Vector2(cos(starting_angle), sin(starting_angle)) * 50
				$Entities.add_child(enemy_instance)
				if enemy_instance is SpecterEnemy:
					update_specter_enemies()

func enemy_death(position, enemy_type):
	yield(get_tree().create_timer(.001), "timeout")
	var remaining_enemy = 0
	for child in $Entities.get_children():
		if child is Enemy:
			remaining_enemy += 1
	if remaining_enemy == 0:
		check_next_wave()
	if enemy_type == "specter":
		update_specter_enemies()

func update_specter_enemies():
	var specter_remaining = 0
	for child in $Entities.get_children():
		if child is SpecterEnemy:
			specter_remaining += 1
	if specter_remaining < 2:
		return
	
	var i = 0
	
	for child in $Entities.get_children():
		if child is SpecterEnemy:
			child.movement_rotation = 2 * PI / specter_remaining * i
			child.reset_timer()
			i += 1

func check_next_wave():
	if wave_index >= battle_waves.size():
		# TODO: Go to next level
		pass
	else:
		create_wave(battle_waves[wave_index])

func get_first_player():
	for p in players:
		if weakref(p).get_ref():
			return p
	return null

func player_death():
	for player in players:
		if !weakref(player).get_ref() || !player.active:
			players.erase(player)
	var new_enemy_target = null
	if players.size() != 0:
		for i in players.size():
			if i == 0:
				players[i].is_main_player = true
				players[i].following_target = null
				new_enemy_target = players[i]
			else:
				players[i].following_target = players[i - 1]
	
	for entity in $Entities.get_children():
		if entity is Enemy:
			entity.player = new_enemy_target


func start_screenshake(force):
	shake_latest_force = force
	shake_camera(force)
	$CameraHandler/ShakeFrequency.start()
	$CameraHandler/ShakeDuration.start()

func shake_camera(force):
	var offset = Vector2(rand_range(-force, force), rand_range(-force, force))
	$CameraHandler/Tween.interpolate_property($CameraHandler/Camera2D, "offset", $CameraHandler/Camera2D.offset, 
			offset, $CameraHandler/ShakeFrequency.wait_time, 
			Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	$CameraHandler/Tween.start()



func _on_ShakeFrequency_timeout():
	shake_camera(shake_latest_force)


func _on_ShakeDuration_timeout():
	$CameraHandler/ShakeFrequency.stop()
	shake_latest_force = 0
	$CameraHandler/Tween.interpolate_property($CameraHandler/Camera2D, "offset", $CameraHandler/Camera2D.offset, 
			Vector2(0, 0), $CameraHandler/ShakeFrequency.wait_time)
	$CameraHandler/Tween.start()
