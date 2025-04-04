extends AIController2D


var move: float = 0.0
var attack := false
var dodge := false

@onready var player: AIPlayer = get_parent() as AIPlayer
@onready var boss: Boss = get_node("Boss") as Boss




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
	if boss == null:
		print("Boss is not assigned!")
		return reward

	# Combat rewards
	if boss.hit_boss_this_frame:
		reward += 1.0  # Reward for successful hit
		if boss.is_attacking:
			reward += 0.5  # Bonus for hitting during boss attack (counter)

	# Defense rewards
	if player.successful_dodge_this_frame:
		reward += 0.7  # Reward for well-timed dodge
		if boss.is_attacking:
			reward += 0.3  # Bonus for dodging an actual attack

	# Survival penalties
	if player.took_damage_this_frame:
		reward -= 1.2  # Penalty for getting hit
		if player.is_attacking:
			reward -= 0.5  # Additional penalty for trading hits

	# Aggression bonus (encourage staying close)
	var distance_norm = player.position.distance_to(boss.position) / 500.0
	reward += 0.05 * (1.0 - distance_norm)  # Closer = better

	# Time penalty (encourage decisive actions)
	reward -= 0.01

	# Death penalty
	if player.current_health <= 0:
		reward -= 5.0

	# Victory bonus
	if boss.current_health <= 0:
		reward += 10.0

	# Discourage spamming
	if player.is_attacking:
		reward -= 0.02  # Small penalty per attack frame
	if player.is_dodging:
		reward -= 0.01  # Tiny penalty per dodge frame

	return reward

func reset() -> void:
	# Called when episode resets
	move = 0.0
	attack = false
	dodge = false
