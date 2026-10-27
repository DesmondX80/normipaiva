extends Node
## Asentojen tarkistus, osa E (ajoneuvot): pyörä, mopo (kuski, matkustaja, varas), mopokisa, traktori ja muskelivene.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --shot=x.png --nohud --scene=asennot --asento=e

const Asento := preload("res://tools/testit/asento.gd")
const Looks := preload("res://scripts/looks.gd")
const Mopo := preload("res://scripts/mopo.gd")
const MopoRace := preload("res://scripts/mopo_race.gd")
const Muskelivene := preload("res://scripts/muskelivene.gd")

var main: Node3D
var _cam: Camera3D
var _out := "user://asennot_e"
var _seen := {}


## Kaikki istuvat hahmot solmun alla (rekursiivisesti); vain puussa näkyvät.
func _sitters(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c.has_method("bone_position") and (String(c.get("_current")).begins_with("Sitting") or String(c.get("_current")) == "Driving") and (c as Node3D).is_visible_in_tree():
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
		await _shoot("%s_%d" % [name, k], ch, 2.2)
		k += 1
	print("ASENTO %s: %d istujaa" % [name, k])


func _wait(n := 8) -> void:
	for i in n:
		await main.get_tree().process_frame


func _node_again(node: Node, name: String) -> void:
	_seen.clear()
	await _node(node, name)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	await _wait(10)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	main.add_child(_cam)
	_cam.current = true
	var far := Vector3(0, 0, -4200)
	# Pelaajan pyörä ja mopo (kuski, matkustamaton), sitten varas satulassa molemmissa.
	var bike: Node3D = main.player
	await _wait()
	await _node_again(bike, "pyora")
	bike.set_mopo(true)
	await _wait()
	await _node_again(bike, "oma_mopo")
	bike.set_thief(Looks.RAAHEN_JATKAT[0])
	await _wait()
	await _node_again(bike, "oma_mopo_varas")
	bike.set_mopo(false)
	await _wait()
	await _node_again(bike, "pyora_varas")
	bike.set_thief({})
	# Vaalan mopo (kuski ja matkustaja).
	var mp := Mopo.new()
	mp.position = far
	main.add_child(mp)
	mp.set_physics_process(false)
	mp.set_passenger(Looks.RAAHEN_JATKAT[1])
	await _wait()
	await _node_again(mp, "mopo")
	mp.queue_free()
	# Mopokisa: pelaajan ja vastustajan mopo.
	var race := MopoRace.new()
	var tr: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, -200)]
	race.track = tr
	race.position = far + Vector3(300, 0, 0)
	main.add_child(race)
	await _wait()
	_cam.current = true
	await _node_again(race, "mopokisa")
	race.queue_free()
	# Muskelivene.
	var boat := Node3D.new()
	boat.position = far + Vector3(600, 0, 0)
	main.add_child(boat)
	Muskelivene.build(boat, true)
	await _wait()
	await _node_again(boat, "muskelivene")
	boat.queue_free()
	# Traktori: pelaaja lähelle, jotta maasto latautuu.
	var tr3: Node3D = main.tractor
	tr3.set_physics_process(false)
	main.player.global_position = tr3.global_position + Vector3(0, 1, 9)
	await _wait(30)
	_cam.current = true
	await _node_again(tr3, "traktori")
	print("ASENTO osa E kuvat: ", ProjectSettings.globalize_path(_out))
