extends Label3D
## Puhekupla (B.bubble): kiinteän kokoinen teksti hahmon yläpuolella. Jos kupla (pitkä repliikki, kamera lähellä tai
## sisätilan yläkamera) menisi ruudun yläreunan yli, sitä lasketaan kameran suunnassa alemmas, joten kupla pysyy
## kokonaan ruudulla ja hahmon pää jää sen alle. Ei käytetä, jos koodi asettaa kuplan paikan itse joka ruudulla
## (guard = false, esim. välianimaatiot).

const LINE_PX := 46.0  # yhden rivin korkeus ruudulla (BUBBLE_FONT * BUBBLE_PIXEL * ruudun skaala)
const MARGIN := 10.0

var rest := Vector3.ZERO  # kuplan paikka hahmon kehyksessä ilman siirtoa
var guard := true
var _wrap_chars := 17.0  # merkkiä riville (leveys 520 px, fontti 40)


func _process(_delta: float) -> void:
	if not guard or text == "":
		return
	position = rest
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(global_position):
		return
	var sy := cam.unproject_position(global_position).y
	var lines := minf(ceilf(float(text.length()) / _wrap_chars) + float(text.count("\n")), 8.0)
	var need := lines * LINE_PX * get_viewport().get_visible_rect().size.y / 1080.0
	if sy - need >= MARGIN:
		return
	var vp_h := get_viewport().get_visible_rect().size.y
	var dist := cam.global_position.distance_to(global_position)
	var per_px := 2.0 * dist * tan(deg_to_rad(cam.fov) / 2.0) / vp_h
	global_position -= cam.global_transform.basis.y * ((MARGIN + need - sy) * per_px)
