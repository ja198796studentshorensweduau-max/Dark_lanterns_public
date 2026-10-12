
extends Node

enum State {
	SPAWNING,
	IDLE,
	PURSUING,
	SEARCHING,
	ATTACKING,
	DYING
}

var current_state: State = State.SPAWNING

signal state_changed(new_state: State, old_state: State)


func transition_to(new_state: State) -> void:
	if current_state == new_state:
		return

	if current_state == State.DYING:
		return

	var old_state := current_state
	current_state = new_state
	state_changed.emit(new_state, old_state)


func is_state(state: State) -> bool:
	return current_state == state
