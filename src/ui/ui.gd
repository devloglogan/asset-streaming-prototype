extends CanvasLayer

@export var log_message_lifetime := 5.0

@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var log_container: VBoxContainer = %LogContainer
@onready var filter_input: LineEdit = %FilterInput
@onready var spawned_count_label: Label = %SpawnedCountLabel
@onready var cached_count_label: Label = %CachedCountLabel

var _filter: String = ""


func _ready() -> void:
	filter_input.text_changed.connect(_on_filter_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		filter_input.release_focus()


func _on_filter_changed(text: String) -> void:
	_filter = text.to_lower()
	for child in log_container.get_children():
		child.visible = _filter.is_empty() or child.text.to_lower().contains(_filter)


func log_message(message: String) -> void:
	var label = Label.new()
	label.text = message
	label.visible = _filter.is_empty() or message.to_lower().contains(_filter)
	log_container.add_child(label)
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	await get_tree().create_timer(log_message_lifetime).timeout
	label.queue_free()


func set_spawned_count(count: int) -> void:
	spawned_count_label.text = "Currently Spawned: %s" % count


func set_cached_count(count: int) -> void:
	cached_count_label.text = "Currently Cached: %s" % count
