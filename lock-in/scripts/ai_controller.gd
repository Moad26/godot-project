extends AIController2D

var move: float = 0.0
var attack := false
var dodge := false

@onready var player: AIPlayer = get_parent() as AIPlayer
@onready var boss: Boss = get_node("/root/Game/Boss") as Boss


func get_obs() -> Dictionary:
	if player == null or boss == null:
		return {"obs": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}
	
	return {
		"obs": [
			player.position.distance_to(boss.position) / 500.0,
			float(boss.current_health) / boss.MAX_HEALTH,
			float(player.current_health) / player.MAX_HEALTH,
			float(int(boss.is_attacking)),
			float(int(boss.is_dodging)),
			float(int(player.is_attacking)),
			float(int(player.is_dodging)),
			float(int(player.successful_dodge_this_frame)),
			float(int(player.took_damage_this_frame)),
			float(int(player.is_close_to_boss)),
			clamp(player.last_attack_time / player.ATTACK_COOLDOWN, 0.0, 1.0),  # Attack cooldown progress
			clamp(player.last_dodge_time / player.DODGE_COOLDOWN, 0.0, 1.0),   # Dodge cooldown progress
		]
	}

func get_action_space() -> Dictionary:
	return {
		"move": {"size": 1, "action_type": "continuous"},
		"attack": {"size": 1, "action_type": "discrete"},
		"dodge": {"size": 1, "action_type": "discrete"}
	}

func set_action(action):
	move = action["move"][0]
	attack = (action["attack"] > 0.7) and player.last_attack_time >= player.ATTACK_COOLDOWN
	dodge = (action["dodge"] > 0.7) and player.last_dodge_time >= player.DODGE_COOLDOWN
	
	if attack:
		player.last_attack_time = 0.0
	if dodge:
		player.last_dodge_time = 0.0

func get_reward() -> float:
	var reward := 0.0
	
	if boss == null or player == null:
		push_error("Cannot calculate reward: Boss or Player is null")
		return 0.0
		
	var optimal_range = 50.0
	var current_dist = player.position.distance_to(boss.position)
	var position_reward = 1.0 - clamp(current_dist/optimal_range, 0.0, 1.0)
	
	# --- Combat Rewards ---
	if boss.hit_boss_this_frame:
		var base_reward = 20.0
		if boss.is_attacking:
			base_reward *= 1.5  # Counter-attack bonus
		reward += base_reward
		boss.hit_boss_this_frame = false
	
	# --- Defense Rewards ---
	if player.successful_dodge_this_frame:
		if boss.is_attacking:
			reward += 15.0  # Reward dodging attacks
		else:
			reward -= 20.0  # Penalize unnecessary dodges (higher penalty)
	
	# --- Attack Penalties ---
	if player.is_attacking:
		if current_dist > optimal_range:
			reward -= 15.0  # Penalize attacking from too far
		else:
			reward += 5.0  # Small reward for attacking in range
	
	# --- Damage Penalties ---
	if player.took_damage_this_frame:
		reward -= 30.0  # Strong penalty for getting hit
	
	# --- Time Penalty (Encourage Decisiveness) ---
	reward -= 0.2
	
	# --- Death/Victory Conditions ---
	if player.current_health <= 0:
		reward -= 100.0
	if boss.current_health <= 0:
		reward += 150.0
	
	return reward

func reset() -> void:
	# Called when episode resets
	move = 0.0
	attack = false
	dodge = false
