extends Node
## Asentojen tarkistus, osa C (sisätilat): Kapteenin Kulma, Siitari, asema, kirppis ja kota; kuvat jokaisesta istujasta.
## "$(tools/testit/godot.sh)" --path . --resolution 1280x720 -- --shot=x.png --nohud --scene=asennot --asento=c

const Asento := preload("res://tools/testit/asento.gd")

var main: Node3D
var _cam: Camera3D
var _out := "user://asennot_c"
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


func run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 10:
		await main.get_tree().process_frame
	_cam = Camera3D.new()
	_cam.fov = 40.0
	main.add_child(_cam)
	_cam.current = true
	main._ensure_raahe()
	await _node(main.raahe_int, "raahe")
	main.siitari_int.ensure_built()
	await _node(main.siitari_int, "siitari")
	main.asema_int.ensure_built()
	await _node(main.asema_int, "asema")
	var modes := {}
	for p in main.kirppis_int.PEOPLE:
		for m in p.modes:
			modes[m] = true
	for m in modes:
		main.kirppis_int.mode = m
		main.kirppis_int._apply_mode()
		for i in 3:
			await main.get_tree().process_frame
		await _node(main.kirppis_int, "kirppis_" + m)
	var kota: Node3D = main.world.kota
	main.player.global_position = kota.global_position + Vector3(0, 1, 8)
	for i in 20:
		await main.get_tree().process_frame
	await _node(kota, "kota")
	print("ASENTO osa C kuvat: ", ProjectSettings.globalize_path(_out))
