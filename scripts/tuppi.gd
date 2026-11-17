extends RefCounted
## Räsytupin peliaivot (kolmiomittauksen iltakiva): tuppi on pohjoisen puoluepeli neljälle (fi.wikipedia Tuppi,
## korttipeliopas.fi/tuppi). 52 korttia, ässä korkein, 13 korttia kullekin, ei valttia, maapakko.
## Ilmoitus: etumiehestä myötäpäivään kukin näyttää ramin tai nolon; ensimmäinen rami päättää ilmoituksen (ramaaja), ja
## jos kukaan ei ramaa, pelataan nolo. Aloittaja: nolossa etumies, ramissa ramaajan edellinen pelaaja.
## Pisteet: rami 7 tikistä 4 p ja jokaisesta seuraavasta +4; jos ramaavat eivät saa seitsemää, rami ryöstetään ja
## puolustajat saavat 8 p jokaisesta tikistä seitsemännestä alkaen. Nolossa vähemmän tikkejä ottanut pari voittaa:
## kuudesta tikistä 4 p, viidestä 8 p ... nollasta 28 p.
## Räsysääntö (pelin oma): jaon hävinnyt pari riisuu kumpikin yhden vaatekappaleen (RASY). Kalsareissa istuva pari,
## joka häviää vielä kerran, on "pantu tuppeen", ja ilta päättyy.
## Paikat myötäpäivään: 0 = pelaaja (alhaalla), 1 = vasen kaveri, 2 = nainen (vastapäätä, pelaajan pari), 3 = oikea kaveri.

const MAAT := ["♠", "♥", "♦", "♣"]
const ARVOT := {11: "J", 12: "Q", 13: "K", 14: "A"}
## Riisumisen vaiheet: 0 täysissä pukeissa ... 3 kalsareissa. Neljäs häviö = pantu tuppeen.
const RASY := ["täysissä pukeissa", "sukkasillaan", "paidatta", "kalsareissa"]

var rng := RandomNumberGenerator.new()
var hands: Array = [[], [], [], []]  # paikka -> kortit (int 0..51: maa = c / 13, arvo = c % 13 + 2)
var dealer := 3  # jakaja; etumies = jakaja + 1
var mode := ""  # "rami" / "nolo"
var ramaaja := -1
var bids: Array = []  # [paikka, "rami"/"nolo"] näyttöjärjestyksessä
var leader := 0  # tikin aloittaja
var trick: Array = []  # [[paikka, kortti], ...] nykyinen tikki
var tricks := [0, 0]  # pari 0 (0+2) ja pari 1 (1+3): otetut tikit
var played: Array = []  # kaikki pelatut kortit tässä jaossa
var rasy := [0, 0]  # parin riisumisvaihe
var points := [0, 0]  # jakojen pisteet yhteensä (näytetään)
var last_trick_winner := -1


static func suit(c: int) -> int:
	return c / 13


static func rank(c: int) -> int:
	return c % 13 + 2


static func kortti(c: int) -> String:
	var r := rank(c)
	return "%s%s" % [MAAT[suit(c)], ARVOT.get(r, str(r))]


static func team(seat: int) -> int:
	return seat % 2


func new_hand() -> void:
	var deck: Array = range(52)
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	dealer = (dealer + 1) % 4
	hands = [[], [], [], []]
	for i in 52:
		hands[(dealer + 1 + i) % 4].append(deck[i])  # yksitellen myötäpäivään etumiehestä alkaen
	for h: Array in hands:
		h.sort_custom(func(a: int, b: int) -> bool: return suit(a) < suit(b) or suit(a) == suit(b) and rank(a) < rank(b))
	mode = ""
	ramaaja = -1
	bids = []
	trick = []
	tricks = [0, 0]
	played = []
	last_trick_winner = -1


func etumies() -> int:
	return (dealer + 1) % 4


## Seuraava näyttäjä tai -1, kun ilmoitus on valmis.
func next_bidder() -> int:
	if mode != "":
		return -1
	return (etumies() + bids.size()) % 4


## Näyttö: rami päättää ilmoituksen, neljäs nolo tekee nolon.
func bid(seat: int, what: String) -> void:
	bids.append([seat, what])
	if what == "rami":
		mode = "rami"
		ramaaja = seat
		leader = (seat + 3) % 4  # ramaajan edellinen pelaaja
	elif bids.size() == 4:
		mode = "nolo"
		leader = etumies()


## Käden vahvuus tikkien ottamiseen: A 4, K 3, Q 2, J 1 ja pitkät maat (yli 4 korttia) +1 kortilta.
func strength(seat: int) -> int:
	var s := 0
	var per := [0, 0, 0, 0]
	for c: int in hands[seat]:
		s += maxi(0, rank(c) - 10)
		per[suit(c)] += 1
	for n: int in per:
		s += maxi(0, n - 4)
	return s


## Tekoälyn näyttö: vahva käsi ramaa (keskiarvo on 10; kynnys 15 antaa noin 70 % rami, 30 % nolo).
func ai_bid(seat: int) -> String:
	return "rami" if strength(seat) >= 15 else "nolo"


func to_play() -> int:
	return (leader + trick.size()) % 4


func legal(seat: int) -> Array:
	var h: Array = hands[seat]
	if trick.is_empty():
		return h.duplicate()
	var led := suit(trick[0][1])
	var same := h.filter(func(c: int) -> bool: return suit(c) == led)
	return same if not same.is_empty() else h.duplicate()


## Tikin tämänhetkinen voittaja: suurin kortti aloitetusta maasta.
func winning() -> Array:
	var best: Array = trick[0]
	for p: Array in trick:
		if suit(p[1]) == suit(best[1]) and rank(p[1]) > rank(best[1]):
			best = p
	return best


## Pelaa kortin. Palauttaa tikin voittajan, kun neljäs kortti tuli, muuten -1.
func play(seat: int, c: int) -> int:
	assert(seat == to_play() and c in legal(seat))
	hands[seat].erase(c)
	trick.append([seat, c])
	played.append(c)
	if trick.size() < 4:
		return -1
	var w: int = winning()[0]
	tricks[team(w)] += 1
	leader = w
	last_trick_winner = w
	trick = []
	return w


func hand_over() -> bool:
	return hands[0].is_empty() and trick.is_empty()


## Tekoälyn kortti: ramissa ramaajapari yrittää tikkejä ja puolustajat estää ne; nolossa kaikki välttävät tikkejä.
func ai_card(seat: int) -> int:
	var ok := legal(seat)
	ok.sort_custom(func(a: int, b: int) -> bool: return rank(a) < rank(b))
	var low: int = ok[0]
	var high: int = ok[-1]
	if trick.is_empty():
		if mode == "nolo":
			return low
		# Ramissa: johda vahvimmalla, jos se on maansa korkein jäljellä oleva; muuten pienin.
		for i in range(ok.size() - 1, -1, -1):
			if _top_left(ok[i]):
				return ok[i]
		return low
	var w: Array = winning()
	var led := suit(trick[0][1])
	var follows := suit(low) == led
	var partner_wins: bool = team(w[0]) == team(seat)
	if mode == "nolo":
		if not follows:
			return high  # maa loppui: pois iso kortti
		var under := ok.filter(func(c: int) -> bool: return rank(c) < rank(w[1]))
		return under[-1] if not under.is_empty() else (high if trick.size() == 3 else low)
	if not follows:
		return low  # ramissa maa loppui: pois pienin
	if partner_wins:
		return low
	var over := ok.filter(func(c: int) -> bool: return rank(c) > rank(w[1]))
	return over[0] if not over.is_empty() else low


## Onko kortti maansa suurin jäljellä oleva (kaikki suuremmat jo pelattu)?
func _top_left(c: int) -> bool:
	for r in range(rank(c) + 1, 15):
		if not (suit(c) * 13 + r - 2) in played:
			return false
	return true


## Jaon tulos: {"voittaja": pari, "pisteet": p, "ryosto": bool, "selitys": teksti}. Hävinnyt pari riisuu (rasy).
func settle() -> Dictionary:
	var out := {}
	if mode == "rami":
		var rt := team(ramaaja)
		if tricks[rt] >= 7:
			out = {"voittaja": rt, "pisteet": 4 * (tricks[rt] - 6), "ryosto": false}
		else:
			var dt := 1 - rt
			out = {"voittaja": dt, "pisteet": 8 * (tricks[dt] - 6), "ryosto": true}
	else:
		var wt := 0 if tricks[0] < tricks[1] else 1
		out = {"voittaja": wt, "pisteet": 4 * (7 - tricks[wt]), "ryosto": false}
	points[out.voittaja] += out.pisteet
	var lt: int = 1 - int(out.voittaja)
	out["haviaja"] = lt
	out["tuppeen"] = rasy[lt] >= RASY.size() - 1
	if not out.tuppeen:
		rasy[lt] += 1
	return out


## Logiikkatesti ilman grafiikkaa: koko ilta tekoälyllä kaikilla paikoilla; tulostaa rivit, palauttaa vikojen määrän.
static func testi(seed: int, prints := true) -> int:
	var t := new()
	t.rng.seed = seed
	var viat := 0
	var jaot := 0
	while jaot < 30:
		jaot += 1
		t.new_hand()
		var n := 0
		for h: Array in t.hands:
			n += h.size()
		if n != 52:
			viat += 1
			print("TESTI VIKA jaossa %d korttia" % n)
		while t.next_bidder() >= 0:
			var b := t.next_bidder()
			t.bid(b, t.ai_bid(b))
		while not t.hand_over():
			var s := t.to_play()
			var c := t.ai_card(s)
			if not c in t.legal(s):
				viat += 1
				print("TESTI VIKA laiton kortti %s paikalta %d" % [kortti(c), s])
			t.play(s, c)
		if t.tricks[0] + t.tricks[1] != 13:
			viat += 1
			print("TESTI VIKA tikkejä %d" % (t.tricks[0] + t.tricks[1]))
		var r := t.settle()
		if prints:
			print("TUPPI jako %d: %s%s, tikit %s, pari %d voitti %d p%s, räsy %s" % [jaot, t.mode,
				" (ramaaja %d)" % t.ramaaja if t.mode == "rami" else "", t.tricks, r.voittaja, r.pisteet,
				" (ryöstö)" if r.ryosto else "", t.rasy])
		if r.tuppeen:
			if prints:
				print("TUPPI pari %d pantu tuppeen %d jaon jälkeen" % [r.haviaja, jaot])
			return viat
	print("TESTI VIKA ilta ei päättynyt 30 jaossa")
	return viat + 1
