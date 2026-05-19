extends Node3D

const SPAWN_RADIUS = 10
const CACHE_FREE_DELAY_MS = 3000

class CacheEntry:
	var scene: PackedScene
	var count: int

@onready var player: CharacterBody3D = $Player
@onready var ui: CanvasLayer = $UI

var is_streaming := false
var assets: Array = [] # All asset data from index.json
var spawned_assets: Dictionary = {} # Assets currently added to the scene, null if being requested
var cache: Dictionary[String, CacheEntry] = {} # Cached scenes and ref count
var asset_filename_map: Dictionary[float, String] = {} # Ref count helper linking asset id to filename
var pending_frees: Dictionary[String, int] = {} # Assets with ref count zero scheduled to be freed

var asset_loader: AssetLoader
var gltf_reader: GltfReader


func _ready() -> void:
	asset_loader = AssetLoader.new()
	add_child(asset_loader)
	asset_loader.index_loaded.connect(_on_index_loaded)
	asset_loader.index_failed.connect(_on_index_failed)
	asset_loader.asset_bytes_ready.connect(_on_asset_bytes_ready)
	asset_loader.asset_request_failed.connect(_on_asset_request_failed)
	asset_loader.asset_requested.connect(func(filename): ui.log_message("Requesting asset from server: %s" % filename))

	gltf_reader = GltfReader.new()
	add_child(gltf_reader)
	gltf_reader.gltf_failed.connect(_on_gltf_failed)
	gltf_reader.gltf_loaded.connect(_on_gltf_loaded)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.key_label == Key.KEY_R \
				and event.pressed \
				and not is_streaming:
			is_streaming = true
			asset_loader.request_index()


func _process(_delta: float) -> void:
	if not is_streaming or assets.is_empty():
		return

	ui.set_spawned_count(spawned_assets.keys().size())
	ui.set_cached_count(cache.size())

	var now := Time.get_ticks_msec()
	for filename in pending_frees.keys():
		if now >= pending_frees[filename]:
			pending_frees.erase(filename)
			cache.erase(filename)
			ui.log_message("Freed cached asset: %s" % filename)

	for asset_data in assets:
		var asset_pos = Vector3(asset_data.position.x, asset_data.position.y, asset_data.position.z)
		if player.position.distance_to(asset_pos) < SPAWN_RADIUS \
				and not spawned_assets.has(asset_data.id):
			spawned_assets[asset_data.id] = null
			if cache.has(asset_data.filename):
				spawn_from_cache(asset_data)
			else:
				asset_loader.request_asset(asset_data)

	for asset_id in spawned_assets.keys():
		var asset_scene = spawned_assets[asset_id]
		if asset_scene == null: continue
		if player.position.distance_to(asset_scene.position) >= SPAWN_RADIUS:
			free_asset(asset_id)


func _on_index_loaded(data: Array) -> void:
	assets = data


func _on_index_failed() -> void:
	is_streaming = false


func _on_asset_bytes_ready(body: PackedByteArray, filename: String, pending: Array) -> void:
	gltf_reader.request_load(body, filename, pending)


func _on_asset_request_failed(pending: Array) -> void:
	for asset_data in pending:
		spawned_assets.erase(asset_data.id)


func _on_gltf_failed(error_message: String) -> void:
	push_error(error_message)


func _on_gltf_loaded(node: Node3D, filename: String, pending: Array) -> void:
	var packed_scene = PackedScene.new()
	packed_scene.pack(node)
	node.free()
	var entry = CacheEntry.new()
	entry.scene = packed_scene
	entry.count = 0
	cache[filename] = entry
	for asset_data in pending:
		spawn_from_cache(asset_data)


func free_asset(asset_id) -> void:
	var scene = spawned_assets[asset_id]
	if scene != null:
		scene.queue_free()
	spawned_assets.erase(asset_id)

	if asset_filename_map.has(asset_id):
		var filename = asset_filename_map[asset_id]
		asset_filename_map.erase(asset_id)
		cache[filename].count -= 1
		if cache[filename].count <= 0 and not pending_frees.has(filename):
			pending_frees[filename] = Time.get_ticks_msec() + CACHE_FREE_DELAY_MS
			ui.log_message("Scheduling cache free for: %s" % filename)


func spawn_from_cache(asset_data) -> void:
	var filename = asset_data.filename
	var scene = cache[filename].scene.instantiate()
	scene.position = Vector3(asset_data.position.x, asset_data.position.y, asset_data.position.z)

	if player.position.distance_to(scene.position) >= SPAWN_RADIUS:
		scene.free()
		spawned_assets.erase(asset_data.id)
		return

	pending_frees.erase(filename)
	ui.log_message("Spawning asset from cache: %s" % filename)
	add_child(scene)
	spawned_assets[asset_data.id] = scene
	asset_filename_map[asset_data.id] = filename
	cache[filename].count += 1
