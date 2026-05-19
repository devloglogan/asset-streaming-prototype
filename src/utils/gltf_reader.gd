class_name GltfReader
extends Node

signal gltf_failed(error_message: String)
signal gltf_loaded(node: Node3D, filename: String, pending: Array)

var _thread: Thread
var _queue: Array = []
var _mutex: Mutex
var _semaphore: Semaphore
var _running: bool = false


func _ready() -> void:
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_running = true
	_thread = Thread.new()
	_thread.start(_thread_loop)


func _exit_tree() -> void:
	_running = false
	_semaphore.post()
	_thread.wait_to_finish()


func request_load(gltf_bytes: PackedByteArray, filename: String, pending: Array) -> void:
	if OS.has_feature("web"):
		_process_item({"bytes": gltf_bytes, "filename": filename, "pending": pending})
		return

	_mutex.lock()
	_queue.push_back({"bytes": gltf_bytes, "filename": filename, "pending": pending})
	_mutex.unlock()
	_semaphore.post()


func _thread_loop() -> void:
	while _running:
		_semaphore.wait()

		if not _running:
			break

		_mutex.lock()
		var item = _queue.pop_front() if not _queue.is_empty() else null
		_mutex.unlock()

		if item == null:
			continue

		_process_item(item)


func _process_item(item: Dictionary) -> void:
	var gltf_doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	var error := gltf_doc.append_from_buffer(item.bytes, "", gltf_state)
	if error != OK:
		gltf_failed.emit.call_deferred("Couldn't append glTF from buffer: [%s]" % error_string(error))
		return

	var node: Node3D = gltf_doc.generate_scene(gltf_state)
	if node == null:
		gltf_failed.emit.call_deferred("Generated gltf scene is null")
		return

	gltf_loaded.emit.call_deferred(node, item.filename, item.pending)
