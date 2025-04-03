extends Node2D
class_name AIController2D

# Reference to the player character
var player: AIPlayer
var boss: Node2D
var move: float
var attack := false
var dodge := false


func init(player_node: AIPlayer):
	player = player_node
	boss = get_tree().get_first_node_in_group("boss")  # Make sure your boss is in a "boss" group

func get_obs() -> Dictionary:
	return {
		"obs": [
			player.position.distance_to(boss.position) / 500.0,
			float(boss.current_health) / boss.MAX_HEALTH,
			float(player.current_health) / player.MAX_HEALTH,
			float(int(boss.is_attacking)),
			float(int(boss.is_dodging))
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
	if action["attack"][0] > 0.5:
		attack = true
	if action["dodge"][0] > 0.5:
		dodge = true

func process_movement(current_velocity: Vector2, delta: float) -> Vector2:
	# Helper method called by the player script
	return current_velocity

func get_reward() -> float:
	var reward = -0.01
	# Add your reward logic here
	return reward
