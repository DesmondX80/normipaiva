extends RefCounted
## Testien kuvanotto. Ruudulla sama kuin ennen (odotetaan piirto, otetaan näkymän kuva). Headless-tilassa mitään ei
## piirretä: RenderingServer.frame_post_draw ei tule koskaan (testi jäisi aikarajaan) eikä näkymällä ole kuvaa, joten
## odotus on yksi ruutu ja kuva on tyhjä samankokoinen kuva (tallennus ja rajaus toimivat, aja.sh --headless ei katso
## kuvia). Pikseleistä mittaavat testit tarkistavat piirretaan() ja tulostavat headlessissa "ei tarkistettu".
## Käyttö: const Kuva := preload("res://tools/testit/kuva.gd"); await Kuva.piirto(); Kuva.ruutu(get_viewport()).save_png(p)


static func piirretaan() -> bool:
	return DisplayServer.get_name() != "headless"


## Odottaa, että ruutu on piirretty (headlessissa seuraavan ruudun).
static func piirto() -> void:
	if piirretaan():
		await RenderingServer.frame_post_draw
	else:
		await (Engine.get_main_loop() as SceneTree).process_frame


## Näkymän (Viewport tai SubViewport) kuva. Headlessissa tyhjä kuva näkymän koossa.
static func ruutu(nakyma: Viewport) -> Image:
	if piirretaan():
		return nakyma.get_texture().get_image()
	var koko := nakyma.get_visible_rect().size
	return Image.create(maxi(int(koko.x), 1), maxi(int(koko.y), 1), false, Image.FORMAT_RGB8)
