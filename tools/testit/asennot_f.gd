extends Node
## Asentojen tarkistus, osa F (Vaala ja mökki): lavan ulkopöytä, lavan yleisö, nuotiopiiri, pihabileet, Santtu kannolla ja laiturilla.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --shot=x.png --nohud --scene=asennot --asento=f

const Asento := preload("res://tools/testit/asento.gd")

var main: Node3D
var _cam: Camera3D
var _out := "user://asennot_f"
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


func _wait(n := 8) -> void:
	for i in n:
		await main.get_tree().process_frame


func run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	await _wait(10)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	main.add_child(_cam)
	_cam.current = true
	# Mökki: Santtu kannolla ja laiturilla (onkimassa).
	main.mokki.ensure_built()
	await _wait(20)
	var sa: Node3D = main.mokki.santtu
	main.player.global_position = sa.global_position + Vector3(0, 1, 8)
	await _wait(30)
	_cam.current = true
	await _node(main.mokki, "mokki_kanto")
	_seen.clear()
	main.mokki.puuhat.debug_start("onki")
	await _wait(20)
	await _node(main.mokki, "mokki_laituri")
	# Vaala: kaikki istujat (lavan ulkopöytä, yleisö, nuotio, pihabileet); piilotetut ryhmät näkyviin.
	main._ensure_mopo_trip()
	main.mopo_trip.ensure_built()
	var vl: Node3D = main.mopo_trip.vaala
	vl.set_lava_live(true)  # bändi, yleisö ja pihan väki rakennetaan vasta tanssien alkaessa
	for n in ["_lava_outside", "_lava_crowd", "_kokko_people", "_kokko"]:
		var g: Node3D = vl.get(n)
		if g != null:
			g.visible = true
			g.process_mode = Node.PROCESS_MODE_INHERIT
	_seen.clear()
	await _wait(10)
	var found := []
	_sitters(vl, found)
	print("ASENTO vaala: %d istujaa" % found.size())
	for ch in found:
		await _wait(6)
		_cam.current = true
		await _node_one(ch, "vaala_%d" % _seen.size())
	print("ASENTO osa F kuvat: ", ProjectSettings.globalize_path(_out))


func _node_one(ch: Node3D, name: String) -> void:
	_seen[ch.get_instance_id()] = true
	await _shoot(name, ch)
