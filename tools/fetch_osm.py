"""Download the OpenStreetMap data the map is drawn from into tools/osm/.

    python -X utf8 tools/fetch_osm.py           # fetch whatever is missing
    python -X utf8 tools/fetch_osm.py --force   # fetch again

One-off: the game itself never goes online. Data (c) OpenStreetMap contributors,
ODbL. Public Overpass servers are often busy, so each query is tried on several
mirrors in turn.
"""

import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

OUT = pathlib.Path(__file__).resolve().parent / "osm"
MIRRORS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]
AGENT = "ValenciaSpanishGame/1.0 (personal offline language-learning project)"

# south, west, north, east -- a little wider than what each view shows
CITY = "39.430,-0.425,39.506,-0.305"
CENTRE = "39.4635,-0.3905,39.4835,-0.3625"

QUERIES = {
    "city": f"""[out:json][timeout:120][bbox:{CITY}];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary|motorway_link|trunk_link|primary_link)$"];
  way["natural"="coastline"];
  way["natural"="beach"];
  way["leisure"~"^(park|garden)$"];
  relation["leisure"~"^(park|garden)$"];
  way["natural"="water"];
  relation["natural"="water"];
  way["railway"~"^(subway|tram|light_rail)$"];
  node["railway"~"^(station|tram_stop)$"];
  node["place"~"^(suburb|neighbourhood|quarter)$"];
  relation["boundary"="administrative"]["name"="Ciutat Vella"];
);
out geom;""",
    "centre": f"""[out:json][timeout:120][bbox:{CENTRE}];
(
  way["highway"]["highway"!~"^(footway|steps|cycleway|path|service|construction|proposed|corridor|elevator)$"];
  way["highway"="footway"]["area"="yes"];
  way["highway"="pedestrian"];
  relation["highway"="pedestrian"];
  way["leisure"~"^(park|garden)$"];
  relation["leisure"~"^(park|garden)$"];
  way["building"]["name"];
  relation["building"]["name"];
  way["railway"~"^(subway|tram|light_rail)$"];
  node["railway"~"^(station|tram_stop)$"];
);
out geom;""",
    # exact positions for the pins, looked up by name rather than trusted from memory
    "places": f"""[out:json][timeout:60][bbox:{CITY}];
(
  nwr["name"~"^(Mercat Central|Mercado Central)$"];
  nwr["name"~"Catedral de (València|Valencia)"];
  nwr["name"~"^(El Micalet|Micalet|Torre del Micalet|El Miguelete)$"];
  nwr["name"~"Llotja de la Seda|Lonja de la Seda"];
  nwr["name"~"Santa Catalina"]["amenity"];
  nwr["name"~"^(Plaça de Santa Caterina|Plaza de Santa Catalina)$"];
  node["railway"="station"]["name"~"^(Xàtiva|Facultats|Facultats - Manuel Broseta|Colón|Alameda|Benimaclet)"];
  nwr["name"~"^(L'Hemisfèric|Hemisfèric|L'Oceanogràfic|Palau de les Arts Reina Sofia|Museu de les Ciències)"];
  nwr["name"~"^(Mercat de Russafa|Mercado de Ruzafa)$"];
  nwr["name"~"Facultat de Filologia"];
  nwr["name"~"^(Carrer de la Pau|Calle de la Paz)$"];
  nwr["name"~"^(Torres de Serrans|Torres de Serranos|Torres de Quart|Estació del Nord|Plaça de Bous de València|Plaza de Toros de Valencia)$"];
  nwr["name"~"^(Platja de la Malva-rosa|Playa de la Malvarrosa)$"];
  nwr["name"~"^(Plaça del Tossal|Plaza del Tossal|Plaça del Carme|Plaza del Carmen)$"];
);
out center tags;""",
}


def fetch(name, query):
    body = urllib.parse.urlencode({"data": query}).encode("utf-8")
    for attempt in range(3):
        for url in MIRRORS:
            req = urllib.request.Request(url, data=body, headers={"User-Agent": AGENT})
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    raw = r.read()
                data = json.loads(raw.decode("utf-8"))
            except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
                print(f"  {name}: {url.split('/')[2]} failed ({str(exc)[:70]})", flush=True)
                continue
            if data.get("elements"):
                (OUT / f"{name}.json").write_bytes(raw)
                print(f"  {name}: {len(data['elements'])} elements, {len(raw) // 1024} KB "
                      f"from {url.split('/')[2]}", flush=True)
                return True
            print(f"  {name}: {url.split('/')[2]} returned nothing "
                  f"({data.get('remark', '')[:70]})", flush=True)
        time.sleep(20)
    return False


def main():
    OUT.mkdir(exist_ok=True)
    ok = True
    for name, query in QUERIES.items():
        if (OUT / f"{name}.json").exists() and "--force" not in sys.argv:
            print(f"  {name}: already downloaded")
            continue
        ok = fetch(name, query) and ok
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
