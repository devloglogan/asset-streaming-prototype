class_name AssetLoader
extends Node

signal index_loaded(assets: Array)
signal index_failed()
signal asset_requested(filename: String)
signal asset_bytes_ready(body: PackedByteArray, filename: String, pending: Array)
signal asset_request_failed(pending: Array)

const ASSETS_URL = "http://localhost:8080/assets/"
const INDEX_PATH = "index.json"
const MODELS_PATH = "models/"

# Used to store multiple of the same assets waiting on the same HTTP request
var pending_by_filename: Dictionary = {}


func request_index() -> void:
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.use_threads = not OS.has_feature("web")
	http_request.request_completed.connect(_on_index_completed.bind(http_request))

	var error = http_request.request(ASSETS_URL + INDEX_PATH)
	if error != OK:
		push_error("An error occurred in the HTTP request [%s]" % error_string(error))
		http_request.queue_free()
		index_failed.emit()


func _on_index_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest) -> void:
	http_request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Error on index http request completion, result code: [%s]" % result)
		index_failed.emit()
		return

	var json = JSON.new()
	var error := json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("Error parsing JSON: [%s]" % error_string(error))
		index_failed.emit()
		return

	var data = json.data.assets
	if not data is Array:
		push_error("No assets array found")
		index_failed.emit()
		return

	index_loaded.emit(data)


func request_asset(asset_data) -> void:
	var filename = asset_data.filename

	if pending_by_filename.has(filename):
		pending_by_filename[filename].append(asset_data)
		return

	pending_by_filename[filename] = [asset_data]
	asset_requested.emit(filename)

	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.use_threads = not OS.has_feature("web")
	http_request.request_completed.connect(_on_asset_completed.bind(filename, http_request))

	var error = http_request.request(ASSETS_URL + MODELS_PATH + filename)
	if error != OK:
		push_error("An error occurred in the HTTP request [%s]" % error_string(error))
		var pending: Array = pending_by_filename.get(filename, [])
		pending_by_filename.erase(filename)
		http_request.queue_free()
		asset_request_failed.emit(pending)


func _on_asset_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray, filename: String, http_request: HTTPRequest) -> void:
	http_request.queue_free()

	var pending: Array = pending_by_filename.get(filename, [])
	pending_by_filename.erase(filename)

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Error on asset http request completion, result code: [%s]" % result)
		asset_request_failed.emit(pending)
		return

	asset_bytes_ready.emit(body, filename, pending)
