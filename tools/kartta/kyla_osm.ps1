# Kylän kartta OpenStreetMapista -> scripts/map_osm.gd (tiet, metsät, pellot, suot, vedet, purot, rakennukset).
# Hae ote ensin (ks. LUEMINUT.md), esim.
#   https://api.openstreetmap.org/api/0.6/map?bbox=24.43,64.595,24.53,64.672  ->  map.osm
# Ajo (Windows PowerShell 5.1):  powershell -File tools\kartta\kyla_osm.ps1 -Osm C:\polku\map.osm
param([Parameter(Mandatory = $true)][string]$Osm)

. "$PSScriptRoot\kehys.ps1"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
[Osm]::Load($Osm)
# Koko kartan alue: tiet, metsät, pellot, suot, vedet, purot ja rakennukset. Käsin tehdyt ovat vain laavu,
# laavupolut ja pelipaikat (map_data.gd).
[Osm]::Export("$root\scripts\map_osm.gd", -60, -960, 1700, 4100)
