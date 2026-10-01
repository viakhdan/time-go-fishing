class_name FishingLoop
extends Node
## Core loop state machine (DESIGN.md §3.1). Pure logic: the Zone scene listens
## to the signals and calls cast() / submit_answer() / reel_result() / acknowledge().
## Timers run in advance() so tests can drive the loop without waiting.
##
## Boss fight: challenge_boss() starts a run of tier-3 problems. Each correct
## answer takes a heart; when the hearts run out the boss is reeled in. Each
## miss shows the solution (BOSS_MISS) and the fight goes on until max_misses,
## when the boss escapes. Rules come from fish.json "boss_fight".

enum State { IDLE, WAITING, BITE, PROBLEM, REEL, CAUGHT, ESCAPED, BOSS_MISS }
enum Escape { WRONG, TIMEOUT, REEL }

signal state_changed(state: State)
## time_limit is 0 for untimed problems. second_chance is true for a strong-line retry.
signal problem_started(problem: Dictionary, time_limit: float, second_chance: bool)
signal reel_started(zone_fraction: float, retry: bool)
signal caught(result: Dictionary)
signal escaped(reason: Escape, problem: Dictionary)
## Boss status after the fight starts, after each hit (hit = true) and each miss.
signal boss_updated(hearts: int, misses_left: int, hit: bool)
## A miss that doesn't end the fight: show the solution, then acknowledge().
signal boss_missed(reason: Escape, problem: Dictionary)

var zone_id := "lake"
var state := State.IDLE
var fish_id := ""
var problem := {}
## Seconds left on the problem timer; only meaningful when time_limit > 0.
var time_left := 0.0
var time_limit := 0.0
var rng := RandomNumberGenerator.new()
var boss_fight := false
var boss_hearts := 0
var boss_misses := 0

var _wait_left := 0.0
var _reel_attempts_left := 0


func _ready() -> void:
	rng.randomize()


func _process(delta: float) -> void:
	advance(delta)


func can_cast() -> bool:
	return state == State.IDLE and not GameState.is_hold_full()


func cast() -> void:
	if not can_cast():
		return
	var wait: Array = GameData.fishing.bite_wait_s
	_wait_left = rng.randf_range(wait[0], wait[1])
	_set_state(State.WAITING)


func can_challenge_boss() -> bool:
	return state == State.IDLE and not GameState.is_hold_full() and GameData.is_boss_available(zone_id)


func challenge_boss() -> void:
	if not can_challenge_boss():
		return
	fish_id = GameData.zone(zone_id).boss
	boss_fight = true
	boss_hearts = int(GameData.boss_fight.hearts)
	boss_misses = 0
	boss_updated.emit(boss_hearts, boss_misses_left(), false)
	_start_problem(false)


func boss_misses_left() -> int:
	return int(GameData.boss_fight.max_misses) - boss_misses


func advance(delta: float) -> void:
	match state:
		State.WAITING:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_bite()
		State.BITE:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_start_problem(false)
		State.PROBLEM:
			if time_limit > 0.0:
				time_left = maxf(0.0, time_left - delta)
				if time_left == 0.0:
					_fail(Escape.TIMEOUT)


func submit_answer(index: int) -> void:
	if state != State.PROBLEM:
		return
	if index != problem.answer_index:
		_fail(Escape.WRONG)
		return
	if boss_fight:
		boss_hearts -= 1
		boss_updated.emit(boss_hearts, boss_misses_left(), true)
		if boss_hearts > 0:
			_start_problem(false)
			return
	var attempts: int = GameData.boss_fight.reel_attempts if boss_fight else GameData.fishing.reel_attempts
	_reel_attempts_left = attempts
	_set_state(State.REEL)
	reel_started.emit(reel_zone_fraction(), false)


## Green zone width as a fraction of the bar, widened by the rod (§5.2).
func reel_zone_fraction() -> float:
	var base: float = GameData.fishing.reel_zone
	return minf(0.9, base * (1.0 + GameData.upgrade_effect("rod", "reel_zone_bonus")))


func reel_result(hit: bool) -> void:
	if state != State.REEL:
		return
	if hit:
		_catch()
		return
	_reel_attempts_left -= 1
	if _reel_attempts_left > 0:
		reel_started.emit(reel_zone_fraction(), true)
	else:
		_escape(Escape.REEL)


## Closes the catch card or escape message and returns to IDLE; after a boss
## miss it moves on to the next problem of the fight.
func acknowledge() -> void:
	if state == State.BOSS_MISS:
		_start_problem(false)
	elif state in [State.CAUGHT, State.ESCAPED]:
		_set_state(State.IDLE)


func _bite() -> void:
	fish_id = FishTable.roll(zone_id, rng)
	_wait_left = GameData.fishing.bite_delay_s
	_set_state(State.BITE)


func _start_problem(second_chance: bool) -> void:
	var rarity := GameData.rarity_of(fish_id)
	var topic: String = GameData.zone(zone_id).topic
	problem = ProblemBank.draw(topic, int(rarity.tier), problem.get("id", ""))
	var base_timer: float = rarity.timer_s
	# The rod adds time only to problems that have a timer (§3.3, §5.2).
	time_limit = base_timer + GameData.upgrade_effect("rod", "timer_bonus_s") if base_timer > 0.0 else 0.0
	time_left = time_limit
	_set_state(State.PROBLEM)
	problem_started.emit(problem, time_limit, second_chance)


func _fail(reason: Escape) -> void:
	if boss_fight:
		_boss_miss(reason)
	elif GameState.trip_second_chances > 0:
		GameState.trip_second_chances -= 1
		GameState.save_game()
		_start_problem(true)
	else:
		_escape(reason)


func _boss_miss(reason: Escape) -> void:
	boss_misses += 1
	if boss_misses_left() <= 0:
		_escape(reason)
		return
	boss_updated.emit(boss_hearts, boss_misses_left(), false)
	_set_state(State.BOSS_MISS)
	boss_missed.emit(reason, problem)


func _escape(reason: Escape) -> void:
	boss_fight = false
	_set_state(State.ESCAPED)
	escaped.emit(reason, problem)


func _catch() -> void:
	var size := FishTable.roll_size(fish_id, rng)
	var result := GameState.record_catch(fish_id, size, Economy.sell_price(fish_id, size))
	boss_fight = false
	_set_state(State.CAUGHT)
	caught.emit(result)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)
