extends RefCounted
## Kaisuan tilan (Kaisuantie 38, kaisua.gd) tallennettava tila: peltojen ruudut, heinämäärät, paalit, koneiden
## paikat, viljat, maksetut työt ja talkoopalkat. Pysyy main.gd:ssä myös silloin, kun mökkiä ei ole rakennettu.
##
## Pelto on CELL-ruudukko pellon rajaavassa suorakaiteessa (mökin paikallinen kehys, kaisua_pelto.gd laskee rajat
## karttadatasta). Jokaisella ruudulla on tila (alla), määrä (heinää tai olkea, yksikköä) ja työsuunta (kylvörivit,
## niittojälki). Ruudut pellon ulkopuolella ovat NONE.

const CELL := 0.5  # m

## Pellot OSM-tunnisteen mukaan (assets/mokki/kartta.json): nimi, laji ja aloitustila uudessa pelissä.
const FIELDS := [
	{"id": "1074444652", "name": "Kotipelto", "kind": "heina", "start": 3},
	{"id": "1074444653", "name": "Tienvarsipelto", "kind": "vilja", "start": 15},
	{"id": "1074444678", "name": "Isopelto", "kind": "vilja", "start": 10},
	{"id": "1074444679", "name": "Ojanvarsi", "kind": "heina", "start": 2},
]

# --- Ruudun tilat ---------------------------------------------------------------------------------------------------
const NONE := 0
# Heinä (nurmi): kasvaa kolmessa vaiheessa, niitetään, karhotaan karholle ja paalataan.
const H_LYHYT := 1  # lyhyt nurmi (kasvaa)
const H_PUOLI := 2  # puolikas
const H_VALMIS := 3  # niittokypsä, timotein tähkät
const H_NIITETTY := 4  # niitetty heinä makaa sarkana
const H_KARHO := 5  # heinä karholla (paalaimen nostettavissa)
const H_SANKI := 6  # tyhjä sänki (karhottu tai paalattu)
# Vilja (ohra): sänki äestetään, kylvetään, kasvaa ja puidaan.
const V_SANKI := 10  # viime vuoden sänki
const V_AESTETTY := 11  # muokattu multa
const V_KYLVETTY := 12  # kylvetty
const V_ORAS := 13  # oras
const V_VIHREA := 14  # vihreä vilja
const V_KYPSA := 15  # puintikypsä ohra
const V_PUITU := 16  # puitu sänki
const V_OLKI := 17  # puitu sänki ja olkikarho puimurin perässä
const V_KYNNETTY := 18  # kynnetty: aura kääntänyt sängen, vaot ja palteet

## Heinää neliömetriltä niitettäessä (yksikköä): niittokypsä antaa eniten.
const HAY_PER_M2 := {H_LYHYT: 4.0, H_PUOLI: 7.0, H_VALMIS: 10.0}
const BALE_HAY := 6500.0  # yksikköä pyöröpaaliin (~650 m² niittokypsää nurmea)
const GRAIN_PER_M2 := 0.38  # kg ohraa neliömetriltä (3 800 kg/ha)
const SEED_PER_M2 := 0.02  # kg siementä neliömetrille (200 kg/ha)
const STONE_PER_M2 := 1.0 / 300.0  # kynnöstä nousevia kiviä (kevään routa nostaa uusia joka vuosi)

## Pellon ruudut: tunniste -> {"cells": PackedByteArray, "amt": PackedFloat32Array, "dir": PackedByteArray,
## "nx": int, "nz": int}. Tyhjä, kunnes pelto rakennetaan ensimmäisen kerran (kaisua_pelto.gd init_cells).
var fields := {}
## Paalit: [{"pos": Vector3 (paikallinen), "yaw": float, "field": int, "lato": bool, "kind": "sailo"}]
var bales: Array = []
## Kivet: [{"pos": Vector3 (paikallinen), "field": int, "size": float, "where": "pelto" | "karry" | "kasa"}]
var stones: Array = []
## Koneiden paikat: kone -> {"pos": Vector3, "yaw": float}. Tyhjä = kotipaikka (kaisua.gd HOME).
var machines := {}
var hitched := ""  # traktorin perässä oleva kone ("" = ei mitään)
var tank := 0.0  # puimurin viljasäiliö (kg)
var trailer := 0.0  # peräkärryn viljakuorma (kg)
var dried := 0.0  # kuivuriin kipattu vilja yhteensä (kg)
var seed := 1.0  # kylvökoneen siemensäiliö (0–1)
var fuel := {"traktori": 1.0, "puimuri": 1.0}  # diesel (0–1)
var baler_hay := 0.0  # paalaimen kammiossa (yksikköä)
## Maksetut työt kierroksen ajan: kenttä -> {työ: true}. Nollautuu, kun pellon kierros alkaa alusta.
var paid := {}
## Työkierroksen kirjanpito: kenttä -> {"karho_max": int, "baled": int, "harvested": float}
var books := {}
var earned := 0.0  # isännän maksamat palkat yhteensä (€)
var food_day := -1  # päivä, jona talkooruoka on syöty
var food_due := false  # isäntä kutsuu pirttiin (työ tehty tänään, ruoka syömättä)
var beer_due := 0  # isännän saunakaljoja odottamassa (koko ketju tehty)
var legends := {}  # ketju -> kerrat (heinatalkoot, sato, kylvot)
var legend_wait := ""  # legendaarinen hetki odottaa isännän kohtausta (esim. "kaisuan_sato": isäntä kutsui kuivurille)
var legend_day := {}  # legendaarinen hetki -> päivä, jona se koettiin (isännän muistelut seuraavina päivinä)
var talked := false  # isäntä on esitellyt hommat
var order_total := 0  # naapurin paalitilaus: paaleja yhteensä
var order_left := 0  # toimittamatta
var order_day := -1  # päivä, jona tilaus tuli (yksi tilaus päivässä)
var last_day := -1  # päivä, johon kasvu on laskettu
## Tilan pellot (maatila_paikka.gd fields) ja tallennusosio: Kaisua oletuksena, Altaan tila Saloisissa omansa.
var defs: Array = FIELDS
var section := "kaisua"


func field_def(i: int) -> Dictionary:
	return defs[i]


func cells_of(i: int) -> Dictionary:
	return fields.get(defs[i].id, {})


## Pellon ruudukon alustus (kaisua_pelto.gd): mask = aloitustila pellon sisällä, NONE muualla. Vanha tallennus
## pidetään, jos koko täsmää.
func init_cells(i: int, nx: int, nz: int, mask: PackedByteArray) -> Dictionary:
	var id: String = defs[i].id
	var f: Dictionary = fields.get(id, {})
	if not f.is_empty() and int(f.nx) == nx and int(f.nz) == nz and (f.cells as PackedByteArray).size() == nx * nz:
		return f
	var amt := PackedFloat32Array()
	amt.resize(nx * nz)
	var dirs := PackedByteArray()
	dirs.resize(nx * nz)
	f = {"cells": mask, "amt": amt, "dir": dirs, "nx": nx, "nz": nz}
	fields[id] = f
	return f


## Päivien kasvu: nurmi kasvaa sängestä niittokypsäksi kolmessa päivässä ja kylvetty ohra puintikypsäksi kolmessa.
## Sadepäivä: noin joka kolmas päivä (ei ensimmäisenä) sataa 3–7 tuntia klo 8–14 alkaen. Palauttaa [alku, loppu]
## minuutteina keskiyöstä, tai (-1, -1) poutapäivänä. Sateella paalaus ja puinti odottavat (märkä heinä ja vilja).
static func rain_window(day: int, offset := 0) -> Vector2:
	if day <= 1:
		return Vector2(-1, -1)
	var h := ((day + offset * 101) * 2654435761 + 97) & 0x7fffffff  # offset: eri tiloilla eri sadepäivät
	if h % 100 >= 32:
		return Vector2(-1, -1)
	var start := 8 * 60 + (h / 100) % 7 * 60
	return Vector2(start, start + 180 + (h / 1000) % 5 * 60)


func advance_to(day: int) -> void:
	if last_day < 0:
		last_day = day
		return
	var n := clampi(day - last_day, 0, 6)
	last_day = maxi(last_day, day)
	for _d in n:
		for id in fields:
			var f: Dictionary = fields[id]
			var cells: PackedByteArray = f.cells
			for k in cells.size():
				var s := cells[k]
				match s:
					H_SANKI:
						cells[k] = H_LYHYT
					H_LYHYT:
						cells[k] = H_PUOLI
					H_PUOLI:
						cells[k] = H_VALMIS
					V_KYLVETTY:
						cells[k] = V_ORAS
					V_ORAS:
						cells[k] = V_VIHREA
					V_VIHREA:
						cells[k] = V_KYPSA
			f.cells = cells


## Pellon ruutujen määrät tiloittain: tila -> ruutuja.
func census(i: int) -> Dictionary:
	var out := {}
	var f := cells_of(i)
	if f.is_empty():
		return out
	for s in (f.cells as PackedByteArray):
		if s != NONE:
			out[s] = int(out.get(s, 0)) + 1
	return out


func book(i: int) -> Dictionary:
	var id: String = defs[i].id
	if not books.has(id):
		books[id] = {"karho_max": 0, "baled": 0, "harvested": 0.0}
	return books[id]


func is_paid(i: int, job: String) -> bool:
	return (paid.get(defs[i].id, {}) as Dictionary).has(job)


func set_paid(i: int, job: String) -> void:
	var id: String = defs[i].id
	if not paid.has(id):
		paid[id] = {}
	paid[id][job] = true


## Pellon kierros alkaa alusta (niitto tai äestys): maksut ja kirjanpito nollaan.
func new_cycle(i: int) -> void:
	paid.erase(defs[i].id)
	books.erase(defs[i].id)


## Pellolla keräämättä olevat kivet.
func stones_left(field: int) -> int:
	return stones.filter(func(st: Dictionary) -> bool: return int(st.field) == field and st.where == "pelto").size()


func bales_in_lato() -> int:
	return bales.filter(func(b: Dictionary) -> bool: return b.lato and not b.get("sold", false)).size()


func save_to(cfg: ConfigFile) -> void:
	var fs := {}
	for id in fields:
		var f: Dictionary = fields[id]
		fs[id] = {"cells": Marshalls.raw_to_base64((f.cells as PackedByteArray).compress(FileAccess.COMPRESSION_DEFLATE)),
			"amt": Marshalls.raw_to_base64((f.amt as PackedFloat32Array).to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE)),
			"dir": Marshalls.raw_to_base64((f.dir as PackedByteArray).compress(FileAccess.COMPRESSION_DEFLATE)),
			"nx": f.nx, "nz": f.nz}
	cfg.set_value(section, "pellot", fs)
	cfg.set_value(section, "paalit", bales)
	cfg.set_value(section, "kivet", stones)
	cfg.set_value(section, "koneet", machines)
	cfg.set_value(section, "kytketty", hitched)
	cfg.set_value(section, "sailio", tank)
	cfg.set_value(section, "perakarry", trailer)
	cfg.set_value(section, "kuivuri", dried)
	cfg.set_value(section, "siemen", seed)
	cfg.set_value(section, "diesel", fuel)
	cfg.set_value(section, "paalain", baler_hay)
	cfg.set_value(section, "maksettu", paid)
	cfg.set_value(section, "kirjanpito", books)
	cfg.set_value(section, "ansiot", earned)
	cfg.set_value(section, "ruoka_paiva", food_day)
	cfg.set_value(section, "ruoka", food_due)
	cfg.set_value(section, "kaljat", beer_due)
	cfg.set_value(section, "legendat", legends)
	cfg.set_value(section, "legenda_odottaa", legend_wait)
	cfg.set_value(section, "legenda_paiva", legend_day)
	cfg.set_value(section, "esitelty", talked)
	cfg.set_value(section, "tilaus", [order_total, order_left, order_day])
	cfg.set_value(section, "paiva", last_day)


func load_from(cfg: ConfigFile) -> void:
	fields = {}
	var fs: Dictionary = cfg.get_value(section, "pellot", {})
	for id in fs:
		var e: Dictionary = fs[id]
		var nx: int = e.nx
		var nz: int = e.nz
		var n := nx * nz
		var cells := Marshalls.base64_to_raw(e.cells).decompress(n, FileAccess.COMPRESSION_DEFLATE)
		var amt := Marshalls.base64_to_raw(e.amt).decompress(n * 4, FileAccess.COMPRESSION_DEFLATE).to_float32_array()
		var dirs := Marshalls.base64_to_raw(e.dir).decompress(n, FileAccess.COMPRESSION_DEFLATE)
		if cells.size() == n and amt.size() == n and dirs.size() == n:
			fields[id] = {"cells": cells, "amt": amt, "dir": dirs, "nx": nx, "nz": nz}
	bales = cfg.get_value(section, "paalit", [])
	stones = cfg.get_value(section, "kivet", [])
	machines = cfg.get_value(section, "koneet", {})
	hitched = cfg.get_value(section, "kytketty", "")
	tank = cfg.get_value(section, "sailio", 0.0)
	trailer = cfg.get_value(section, "perakarry", 0.0)
	dried = cfg.get_value(section, "kuivuri", 0.0)
	seed = cfg.get_value(section, "siemen", 1.0)
	fuel = cfg.get_value(section, "diesel", {"traktori": 1.0, "puimuri": 1.0})
	baler_hay = cfg.get_value(section, "paalain", 0.0)
	paid = cfg.get_value(section, "maksettu", {})
	books = cfg.get_value(section, "kirjanpito", {})
	earned = cfg.get_value(section, "ansiot", 0.0)
	food_day = cfg.get_value(section, "ruoka_paiva", -1)
	food_due = cfg.get_value(section, "ruoka", false)
	beer_due = cfg.get_value(section, "kaljat", 0)
	legends = cfg.get_value(section, "legendat", {})
	legend_wait = cfg.get_value(section, "legenda_odottaa", "")
	legend_day = cfg.get_value(section, "legenda_paiva", {})
	talked = cfg.get_value(section, "esitelty", false)
	var o: Array = cfg.get_value(section, "tilaus", [0, 0, -1])
	order_total = o[0]
	order_left = o[1]
	order_day = o[2]
	last_day = cfg.get_value(section, "paiva", -1)
