## Istumapaikan kuvaus: kaluste kertoo, mihin voi istua, mitä se tukee ja mihin kädet voi laittaa. Pose.sit ja Contact
## lukevat tämän, joten istujan asento lasketaan kalusteen mitoista eikä käsin kirjoitetuista luvuista.
## Kaikki vektorit ovat kalusteen (node) paikallisessa avaruudessa. Käyttö:
##   const Seat := preload("res://scripts/seat.gd")
##   Seat.spot(penkki, {"seat": Vector3(0, 0.45, 0), "front": Vector3(0, 0, 1), "solids": Seat.collect(penkki)})
##   Pose.sit(hahmo, penkki, Pose.JAYKKA)
## Kentät: seat (pinnan piste), n (pinnan normaali, oletus ylös), front (vaakasuunta, johon polvet osoittavat),
## depth, width (mitat), back {"p": selkänojan pintapiste, "n": normaali istujaa kohti}, solids (lista
## [Transform3D, "box"|"cyl", koko], koko box = Vector3, cyl = Vector3(säde, korkeus, 0)), ground (maan korkeus, jos
## tukea ei löydy kappaleista), hands {nimi: Transform3D (origin = ote, basis.y = pinnan normaali)}.

const META := "istuin"
## Kaikki rekisteröidyt istumapaikat (läpimenotesti käy ne läpi).
static var registry: Array = []


static func spot(node: Node3D, d: Dictionary) -> Dictionary:
	if not d.has("n"):
		d["n"] = Vector3.UP
	d["front"] = Vector3(d.front.x, 0, d.front.z).normalized()
	if not d.has("solids"):
		d["solids"] = collect(node)
	node.set_meta(META, d)
	registry = registry.filter(func(n: Variant) -> bool: return is_instance_valid(n))
	registry.append(node)
	return d


static func of(node: Node) -> Dictionary:
	return node.get_meta(META) if node.has_meta(META) else {}


## Kerää solmun alla olevien laatikko- ja lieriömeshien muodot (Transform3D solmun avaruudessa). Aja ennen
## B.merge_static-kutsua, sen jälkeen erilliset primitiivit ovat poissa.
static func collect(node: Node3D) -> Array:
	var out := []
	_collect(node, Transform3D.IDENTITY, out)
	return out


static func _collect(n: Node3D, xf: Transform3D, out: Array) -> void:
	for c in n.get_children():
		if not c is Node3D or c.has_method("refresh_pose"):  # hahmot eivät ole kalustetta
			continue
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D:
			var m: Mesh = (c as MeshInstance3D).mesh
			if m is BoxMesh:
				out.append([cx, "box", (m as BoxMesh).size])
			elif m is CylinderMesh:
				out.append([cx, "cyl", Vector3((m as CylinderMesh).top_radius, (m as CylinderMesh).height, 0)])
		_collect(c, cx, out)
