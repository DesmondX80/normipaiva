extends Resource
## Laskettujen meshien levyvälimuisti (user://cache): esim. maastolaatat lasketaan GDScriptillä sekunteja, mutta
## valmiin binääriresurssin lataus vie murto-osan. key kertoo, mistä syötteistä meshit on laskettu; jos se ei
## täsmää (korkeusmalli, kartta tai laskentatapa muuttui), lasketaan uudelleen.

const DIR := "user://cache"
## Itse skripti (ei class_namea: projekti lataa skriptit preloadilla, ja class_name vaatii editorin luokkalistan).
const MeshBundle := preload("res://scripts/mesh_bundle.gd")

@export var key := ""
@export var meshes: Array[ArrayMesh] = []
@export var by_key := {}  # syötteen tiiviste -> ArrayMesh (load_dict / save_dict)


## Avaimella key tallennettu sanakirja (tiiviste -> mesh) tai tyhjä, jos avain ei täsmää.
static func load_dict(name: String, key: String) -> Dictionary:
	var path := "%s/%s.res" % [DIR, name]
	if ResourceLoader.exists(path):
		var b := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MeshBundle
		if b != null and b.key == key:
			return b.by_key
	return {}


static func save_dict(name: String, key: String, dict: Dictionary) -> void:
	var nb := MeshBundle.new()
	nb.key = key
	nb.by_key = dict
	DirAccess.make_dir_recursive_absolute(DIR)
	var err := ResourceSaver.save(nb, "%s/%s.res" % [DIR, name], ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_warning("Välimuistiin tallennus epäonnistui (%s): %d" % [name, err])


## Meshit välimuistista avaimella key, tai make.call() (palauttaa Array[ArrayMesh]) ja tallennus.
static func get_or_make(name: String, key: String, make: Callable) -> Array[ArrayMesh]:
	var path := "%s/%s.res" % [DIR, name]
	if ResourceLoader.exists(path):
		var b := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MeshBundle
		if b != null and b.key == key and not b.meshes.is_empty():
			return b.meshes
	var out: Array[ArrayMesh] = make.call()
	var nb := MeshBundle.new()
	nb.key = key
	nb.meshes = out
	DirAccess.make_dir_recursive_absolute(DIR)
	var err := ResourceSaver.save(nb, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_warning("Välimuistiin tallennus epäonnistui (%s): %d" % [path, err])
	return out
