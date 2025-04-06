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
	attack = (action["attack"] > 0.5)
	dodge = (action["dodge"] > 0.5)

func get_reward() -> float:
	var reward := 0.0
	
	# Safety checks
	if boss == null or player == null:
		push_error("Cannot calculate reward: Boss or Player is null")
		return 0.0
		
	var optimal_range = 50.0  # Reduced from 150 for melee focus
	var current_dist = player.position.distance_to(boss.position)
	
	# Continuous position reward (more aggressive curve)
	var position_reward = 1.0 - clamp(current_dist/optimal_range, 0.0, 1.0)
	reward += 15.0 * pow(position_reward, 2)  # Quadratic scaling
	
	# Combat rewards
	# --- Combat Phase Rewards ---
	if boss.hit_boss_this_frame:
		var base_reward = 20.0
		if boss.is_attacking:
			base_reward *= 1.5  # Counter-attack bonus
		reward += base_reward
		boss.hit_boss_this_frame = false  # Reset flag after processing
	
	# Sticking close to boss reward
	if player.is_close_to_boss:
		reward += 0.1
	
	# Defense rewards
	if player.successful_dodge_this_frame:
		if boss.is_attacking:
			var dodge_reward = 15.0  # Perfect dodge reward
			reward += dodge_reward
		else:
			reward -= 10.0  # Stronger penalty for unnecessary dodges
	
	# Survival penalties
	# --- Damage Penalties ---
	if player.took_damage_this_frame:
		var damage_penalty = -25.0
		if player.is_attacking:
			damage_penalty *= 1.2  # Extra penalty for reckless attacks
		reward += damage_penalty
	
	# --- Action Economy ---
	if player.is_attacking:
		reward -= 5.0 * (1.0 - position_reward)  # Worse penalty when attacking from bad positions
		
	if player.is_dodging:
		reward -= 8.0 * (1.0 - position_reward)
	
	# Time penalty (encourage decisive actions)
	reward -= 0.1
	
	# Death penalty
	if player.current_health <= 0:
		reward -= 50.0
	
	# Victory bonus
	if boss.current_health <= 0:
		reward += 100.0
	
	return reward

func reset() -> void:
	# Called when episode resets
	move = 0.0
	attack = false
	dodge = false
