extends PanelContainer
## Question + 4 answers + timer (DESIGN.md §10). After a miss it shows the
## correct answer and the one-line solution (§3.3).

signal answered(index: int)
signal continue_pressed

const STARS := {"common": "★", "uncommon": "★★", "rare": "★★★", "legendary": "★★★★"}
const TIMER_WARNING_S := 10.0
const WARNING_COLOR := Palette.ALARM

@onready var rarity_label: Label = %RarityLabel
@onready var timer_label: Label = %TimerLabel
@onready var notice_label: Label = %NoticeLabel
@onready var question_label: Label = %QuestionLabel
@onready var answers: GridContainer = %Answers
@onready var feedback: VBoxContainer = %Feedback
@onready var result_label: Label = %ResultLabel
@onready var answer_label: Label = %AnswerLabel
@onready var solution_label: Label = %SolutionLabel
@onready var solution_card: PanelContainer = %SolutionCard
@onready var continue_button: Button = %ContinueButton

var _problem := {}
var _rarity_id := ""
var _previous_answer := ""
var _result_key := ""


func _ready() -> void:
	for i in answers.get_child_count():
		answers.get_child(i).pressed.connect(func(): answered.emit(i))
	continue_button.pressed.connect(continue_pressed.emit)


func show_problem(problem: Dictionary, rarity_id: String, time_limit: float, second_chance := false) -> void:
	# On a second chance, still show what the missed problem's answer was (§3.3).
	_previous_answer = _problem.options[_problem.answer_index] if second_chance and not _problem.is_empty() else ""
	_problem = problem
	_rarity_id = rarity_id
	rarity_label.add_theme_color_override("font_color", Color(GameData.rarity(rarity_id).color))
	timer_label.visible = time_limit > 0.0
	if time_limit > 0.0:
		set_time_left(time_limit)
	for i in answers.get_child_count():
		var button: Button = answers.get_child(i)
		button.text = problem.options[i]
	question_label.show()
	answers.show()
	feedback.hide()
	_refresh_text()
	show()
	# No auto-focus on an answer: a stray Space press must never pick option 0.
	get_viewport().gui_release_focus()


func set_time_left(seconds: float) -> void:
	timer_label.text = tr("UI_TIMER_S").format({"n": ceili(seconds)})
	if seconds <= TIMER_WARNING_S:
		timer_label.add_theme_color_override("font_color", WARNING_COLOR)
	else:
		timer_label.remove_theme_color_override("font_color")


## After a wrong answer or timeout: correct answer + solution.
func show_miss(reason: FishingLoop.Escape) -> void:
	_result_key = "UI_TIME_UP" if reason == FishingLoop.Escape.TIMEOUT else "UI_WRONG"
	timer_label.hide()
	answers.hide()
	answer_label.show()
	solution_card.show()
	_show_feedback()


## After the fish slips off during reeling: no math to explain.
func show_reel_escape() -> void:
	_result_key = "UI_ESCAPED"
	timer_label.hide()
	notice_label.hide()
	question_label.hide()
	answers.hide()
	answer_label.hide()
	solution_card.hide()
	_show_feedback()


func _show_feedback() -> void:
	feedback.show()
	_refresh_text()
	show()
	continue_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


func _refresh_text() -> void:
	if _problem.is_empty():
		return
	var rarity := GameData.rarity(_rarity_id)
	rarity_label.text = "%s %s · %s" % [STARS[_rarity_id], tr(rarity.name_key), tr("UI_BITE")]
	notice_label.visible = _previous_answer != ""
	notice_label.text = "%s (%s: %s)" % [tr("UI_SECOND_CHANCE"), tr("UI_CORRECT_ANSWER"), _previous_answer]
	question_label.text = ProblemBank.text(_problem.question)
	result_label.text = tr(_result_key) if _result_key else ""
	answer_label.text = "%s: %s" % [tr("UI_CORRECT_ANSWER"), _problem.options[_problem.answer_index]]
	solution_label.text = "%s: %s" % [tr("UI_SOLUTION"), ProblemBank.text(_problem.solution)]
