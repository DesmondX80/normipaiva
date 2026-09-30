# Kylän kartan kehys: karttapikseli (map_data.gd) <-> ETRS-TM35FIN. Koko kartta on yhdessä kehyksessä, jonka määräävät
# kaksi OpenStreetMapin risteystä: J_K (Ketunperäntie / Tarpiontie) = px (195, 765) ja J_PATO (Ketunperäntie / Patotie)
# = px (1304, 3778). Mittakaava n. 1,22 m/px, kierto n. 0,47°. Pelissä 1 px = 1 m (map_data.SCALE), eli kylä on
# vaakasuunnassa hieman tiivistetty (bake_terrain.gd V_SCALE pitää rinteet luontevina).
# Käyttö muista skripteistä:  . "$PSScriptRoot\kehys.ps1"   (lataa C#-apurit ja määrittelee Px2Tm / Tm2Px)

[System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
Add-Type -Path "$PSScriptRoot\tiff.cs", "$PSScriptRoot\tm35.cs", "$PSScriptRoot\mosaic.cs", "$PSScriptRoot\osm.cs" `
	-ReferencedAssemblies System.Xml, System.Core -ErrorAction SilentlyContinue

$script:JK = [Tm35]::Fwd(64.6471763, 24.4603302)     # J_K
$script:JP = [Tm35]::Fwd(64.6145888, 24.4910525)     # J_PATO
$dpx = 1304 - 195; $dpy = 3778 - 765; $dmx = $JP[0] - $JK[0]; $dmy = -($JP[1] - $JK[1])
$script:SC = [math]::Sqrt(($dmx * $dmx + $dmy * $dmy) / ($dpx * $dpx + $dpy * $dpy))
$script:ROT = [math]::Atan2($dmy, $dmx) - [math]::Atan2($dpy, $dpx)

function Px2Tm([double]$x, [double]$y) {
	$dx = $x - 195; $dy = $y - 765; $c = [math]::Cos($ROT); $s = [math]::Sin($ROT)
	return @(($JK[0] + $SC * ($dx * $c - $dy * $s)), ($JK[1] - $SC * ($dx * $s + $dy * $c)))
}

function Tm2Px([double]$e, [double]$n) {
	$mx = $e - $JK[0]; $my = $JK[1] - $n; $c = [math]::Cos($ROT); $s = [math]::Sin($ROT)
	return @((195 + ($mx * $c + $my * $s) / $SC), (765 + (-$mx * $s + $my * $c) / $SC))
}

[Osm]::Frame($JK[0], $JK[1], $SC, $ROT)
