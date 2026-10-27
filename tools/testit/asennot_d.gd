extends Node
## Asentojen tarkistus, osa D (3D-minipelit): baari, bingo, huutokauppa, piirakka, kalastus, keinu ja lavabändin rumpali.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --shot=x.png --nohud --scene=asennot --asento=d

const Asento := preload("res://tools/testit/asento.gd")
const BarGame := preload("res://scripts/bar_game.gd")
const BingoGame := preload("res://scripts/bingo_game.gd")
const AuctionGame := preload("res://scripts/auction_game.gd")
const PiirakkaGame := preload("res://scripts/piirakka_game.gd")
const FishGame := preload("res://scripts/fish_game.gd")
const KeinuGame := preload("res://scripts/keinu_game.gd")
const HumppaBand := preload("res://scripts/humppa_band.gd")

var main: Node3D
var _cam: Camera3D
var _out := "user://asennot_d"
var _seen := {}


## Kaikki istuvat hahmot solmun alla (rekursiivisesti); vain puussa näkyvät.
func _sitters(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c.has_method("bone_position") and String(c.get("_current")).begins_with("Sitting") and (c as Node3D).is_visible_in_tree():
			out.append(c)
		_sitters(c, out)


func _shoot(name: String, ch: Node3D, size := 1.8) -> void:
	var front: Vector3 = -ch.global_basis.z
	front.y = 0
	front = front.normalized()
	var pel: Vector3 = ch.to_global(ch.bone_position("pelvis"))
	print("ASENTO %s: %s, juuri %s, lantio %s, jalka %s" % [name, ch.get("_current"), ch.global_position, pel, ch.to_global(ch.bone_position("foot_l"))])
	await Asento.views(_cam, _out, name, ch.global_position + Vector3(0, 0.6, 0), size, front)


func _node(node: Node, name: String) -> void:
	var found := []
	_sitters(node, found)
	var k := 0
	for ch in found:
		if _seen.has(ch.get_instance_id()):
			continue
		_seen[ch.get_instance_id()] = true
		await _shoot("%s_%d" % [name, k], ch)
		k += 1
	print("ASENTO %s: %d istujaa" % [name, k])


## Lisää minipelin kauas kartasta (oma paikkansa), kuvaa istujat ja poistaa pelin.
func _game(name: String, g: Node3D, at: Vector3, parent: Node = null, setup := Callable()) -> void:
	g.position = at
	(parent if parent != null else main).add_child(g)
	for i in 12:
		await main.get_tree().process_frame
	_cam.current = true
	if setup.is_valid():
		setup.call(g)
		for i in 6:
			await main.get_tree().process_frame
	await _node(g, name)
	g.queue_free()
	for i in 3:
		await main.get_tree().process_frame


func run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 10:
		await main.get_tree().process_frame
	_cam = Camera3D.new()
	_cam.fov = 40.0
	main.add_child(_cam)
	_cam.current = true
	var far := Vector3(0, 0, -4200)
	await _game("baari", BarGame.new(), far)
	var g1 := BarGame.new()
	await _game("baari_puhe", g1, far, null, func(g: Node3D) -> void:
		g._tero.play("Sitting_Talking", 0.0))
	var bingo := BingoGame.new()
	bingo.interior = main.kirppis_int
	main.kirppis_int.mode = "bingo"
	main.kirppis_int._apply_mode()
	await _game("bingo", bingo, Vector3.ZERO, main.kirppis_int)
	var auc := AuctionGame.new()
	auc.interior = main.kirppis_int
	await _game("huutokauppa", auc, Vector3.ZERO, main.kirppis_int)
	var pk := PiirakkaGame.new()
	await _game("piirakka", pk, far + Vector3(300, 0, 0))
	var fish := FishGame.new()
	fish.dock = main.mokki.north_dock
	fish.dock_dir = main.mokki.north_dock_dir
	await _game("kalastus", fish, Vector3.ZERO)
	await _game("keinu", KeinuGame.new(), far + Vector3(600, 0, 0))
	var band := HumppaBand.new()
	band.speaker = false
	main.add_child(band)
	band.position = far + Vector3(900, 0, 0)
	band.build()
	for i in 12:
		await main.get_tree().process_frame
	_cam.current = true
	await _node(band, "humppa_band")
	print("ASENTO osa D kuvat: ", ProjectSettings.globalize_path(_out))
