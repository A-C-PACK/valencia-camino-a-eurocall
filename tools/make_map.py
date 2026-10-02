"""Draw the game's two maps from OpenStreetMap data (tools/osm/, see fetch_osm.py):

    game/art/map_city.png      the whole city, old town to the sea
    game/art/map_centre.png    Ciutat Vella, street by street
    game/art/pin_<place>.png   round thumbnails of each place's illustration
    game/data/map.json         the projection, so the game can turn lat/lon into pixels

    python -X utf8 tools/make_map.py

Both maps are 860x720 game pixels, drawn at twice that so they stay sharp when
the window is enlarged. Map data (c) OpenStreetMap contributors, ODbL.
"""

import json
import math
import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OSM = ROOT / "tools" / "osm"
ART = ROOT / "game" / "art"
W, H, SS = 860, 720, 2
KX = 111.32 * math.cos(math.radians(39.47))    # km per degree of longitude here
KY = 111.2

LAND = "#F3E6C6"
OLD_TOWN = "#ECD6A8"
BLOCK = "#EAD8B2"
PARK = "#B7D69C"
PARK_EDGE = "#9CC383"
WATER = "#9FD0DD"
BEACH = "#F8E2A4"
ROAD = "#FFFDF6"
ROAD_EDGE = "#D9C49A"
BIG_ROAD = "#F7D58E"
PLAZA = "#FFF4D8"
BUILDING = "#DDBE8E"
BUILDING_EDGE = "#B6935A"
INK = "#1F3A4D"
MUTED = "#8A7A55"
METRO = "#B8402A"
TRAM = "#2E6F8E"

FONT_DIR = ROOT / "game" / "fonts"          # the game's own open-licence fonts
FONTS = {"regular": ("SourceSans3.ttf", 400), "bold": ("SourceSans3.ttf", 700),
         "italic": ("SourceSans3-Italic.ttf", 400)}

VIEWS = {
    "city": {"lat0": 39.4680, "lon0": -0.3570, "scale": 105.0},
    "centre": {"lat0": 39.4730, "lon0": -0.3768, "scale": 430.0},
}

SHORT = [("Avinguda ", "Av. "), ("Carrer ", "C. "), ("Passeig ", "Pg. "), ("Plaça ", "Pl. ")]


def font(kind, size):
    name, weight = FONTS[kind]
    f = ImageFont.truetype(str(FONT_DIR / name), int(size * SS * 1.06))
    f.set_variation_by_axes([weight])
    return f


class View:
    def __init__(self, name):
        self.name = name
        self.lat0, self.lon0, self.scale = (VIEWS[name][k] for k in ("lat0", "lon0", "scale"))
        self.img = Image.new("RGB", (W * SS, H * SS), LAND)
        self.d = ImageDraw.Draw(self.img)
        self.boxes = []      # label bounding boxes already used

    def xy(self, lat, lon):
        return ((W / 2 + (lon - self.lon0) * KX * self.scale) * SS,
                (H / 2 - (lat - self.lat0) * KY * self.scale) * SS)

    def pts(self, geometry):
        return [self.xy(p["lat"], p["lon"]) for p in geometry]

    def inside(self, p, margin=0):
        return -margin <= p[0] <= W * SS + margin and -margin <= p[1] <= H * SS + margin

    def polygon(self, geometry, fill, outline=None, width=1):
        pts = self.pts(geometry)
        if len(pts) >= 3:
            self.d.polygon(pts, fill=fill, outline=outline, width=int(width * SS))

    def line(self, pts, fill, width):
        if len(pts) >= 2:
            self.d.line(pts, fill=fill, width=max(1, int(round(width * SS))), joint="curve")

    def dashed(self, pts, fill, width, dash=7, gap=5):
        dash, gap = dash * SS, gap * SS
        on, left = True, dash
        for a, b in zip(pts, pts[1:]):
            seg = math.dist(a, b)
            pos = 0.0
            while pos < seg:
                step = min(left, seg - pos)
                if on:
                    t0, t1 = pos / seg, (pos + step) / seg
                    self.d.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                                 (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)],
                                fill=fill, width=int(width * SS))
                pos += step
                left -= step
                if left <= 0:
                    on = not on
                    left = dash if on else gap

    def label(self, xy, text, size, fill, kind="regular", angle=0.0, halo=LAND, force=False,
              spacing=0):
        """Draw text centred on xy, optionally rotated. Skips it (returns False)
        if it would sit on top of an earlier label, unless forced."""
        f = font(kind, size)
        if spacing:
            text = (" " * spacing).join(text)
        l, t, r, b = f.getbbox(text, stroke_width=2 * SS)
        tile = Image.new("RGBA", (r - l + 8, b - t + 8), (0, 0, 0, 0))
        ImageDraw.Draw(tile).text((4 - l, 4 - t), text, font=f, fill=fill,
                                  stroke_width=int(1.5 * SS), stroke_fill=halo)
        if angle:
            tile = tile.rotate(angle, expand=True, resample=Image.BICUBIC)
        x, y = int(xy[0] - tile.width / 2), int(xy[1] - tile.height / 2)
        box = (x, y, x + tile.width, y + tile.height)
        if not force:
            pad = 6 * SS
            for o in self.boxes:
                if box[0] < o[2] + pad and box[2] > o[0] - pad and box[1] < o[3] + pad \
                        and box[3] > o[1] - pad:
                    return False
            if box[0] < 0 or box[1] < 0 or box[2] > W * SS or box[3] > H * SS:
                return False
        self.img.paste(tile, (x, y), tile)
        self.boxes.append(box)
        return True

    def save(self, path):
        self.img.save(path, optimize=True)


def load(name):
    return json.loads((OSM / f"{name}.json").read_text(encoding="utf-8"))["elements"]


def stitch(ways):
    """Join way geometries end to end into the longest chains they form."""
    key = lambda p: (round(p["lat"], 7), round(p["lon"], 7))
    left = [list(w) for w in ways if len(w) >= 2]
    chains = []
    while left:
        chain = left.pop()
        grew = True
        while grew:
            grew = False
            for i, w in enumerate(left):
                if key(w[0]) == key(chain[-1]):
                    chain += w[1:]
                elif key(w[-1]) == key(chain[-1]):
                    chain += w[-2::-1]
                elif key(w[-1]) == key(chain[0]):
                    chain = w[:-1] + chain
                elif key(w[0]) == key(chain[0]):
                    chain = w[::-1][:-1] + chain
                else:
                    continue
                left.pop(i)
                grew = True
                break
        chains.append(chain)
    return chains


def areas(elements, test):
    """Closed outlines of every way/relation whose tags pass `test`."""
    out = []
    for e in elements:
        if not test(e.get("tags", {})):
            continue
        if e["type"] == "way" and "geometry" in e:
            out.append(e["geometry"])
        elif e["type"] == "relation":
            outer = [m["geometry"] for m in e.get("members", [])
                     if m["type"] == "way" and m.get("role") != "inner" and m.get("geometry")]
            out += stitch(outer)
    return out


def road_label_spots(view, elements, classes, limit, min_size=9.5):
    """Pick the longest on-screen stretch of each named street for its label."""
    best = {}
    for e in elements:
        t = e.get("tags", {})
        if e["type"] != "way" or t.get("highway") not in classes or "name" not in t:
            continue
        pts = [p for p in view.pts(e["geometry"]) if view.inside(p, -30 * SS)]
        if len(pts) < 2:
            continue
        length = sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))
        cur = best.get(t["name"])
        total = (cur[0] if cur else 0) + length
        if cur is None or length > cur[1]:
            best[t["name"]] = (total, length, pts)
        else:
            best[t["name"]] = (total, cur[1], cur[2])
    ranked = sorted(best.items(), key=lambda kv: -kv[1][0])[:limit]
    for name, (_, length, pts) in ranked:
        for a, b in SHORT:
            name = name.replace(a, b)
        # the point half-way along, and the direction of the street there
        half, run = length / 2, 0.0
        for a, b in zip(pts, pts[1:]):
            seg = math.dist(a, b)
            if run + seg >= half:
                t = (half - run) / seg if seg else 0
                mid = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                break
            run += seg
        a, b = pts[0], pts[-1]
        angle = -math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
        if angle > 90:
            angle -= 180
        if angle < -90:
            angle += 180
        width = font("regular", min_size).getlength(name)
        if width < length * 1.15:
            view.label(mid, name, min_size, MUTED, "regular", angle)


def credit(view):
    view.label((W * SS - 118 * SS, H * SS - 12 * SS), "© colaboradores de OpenStreetMap", 9.5,
               MUTED, "italic", force=True)


# ----------------------------------------------------------------------- city

def draw_city():
    v = View("city")
    els = load("city")
    tag = lambda **kw: (lambda t: all(t.get(k) in (val if isinstance(val, tuple) else (val,))
                                      for k, val in kw.items()))

    boundary = [e for e in els if e["type"] == "relation"
                and e.get("tags", {}).get("boundary") == "administrative"]
    old_town = areas(boundary, lambda t: True)
    for ring in old_town:
        v.polygon(ring, OLD_TOWN)
    for ring in areas(els, tag(leisure=("park", "garden"))):
        v.polygon(ring, PARK)
    for ring in areas(els, tag(natural="beach")):
        v.polygon(ring, BEACH)
    for ring in areas(els, tag(natural="water")):
        v.polygon(ring, WATER)

    # The sea: draw the coastline on a mask and flood-fill from open water.
    mask = Image.new("L", v.img.size, 0)
    md = ImageDraw.Draw(mask)
    for e in els:
        if e.get("tags", {}).get("natural") == "coastline":
            md.line(v.pts(e["geometry"]), fill=128, width=3)
    # Two seeds: the port's breakwater runs off the east edge and splits the sea.
    ImageDraw.floodfill(mask, (W * SS - 3, H * SS // 3), 255)
    ImageDraw.floodfill(mask, (W * SS - 3, H * SS - 3), 255)
    sea = mask.point(lambda p: 255 if p == 255 else 0)
    v.img.paste(WATER, (0, 0), sea)
    v.d = ImageDraw.Draw(v.img)

    widths = {"tertiary": 1.4, "secondary": 2.2, "primary": 3.0, "primary_link": 1.6,
              "trunk": 3.4, "trunk_link": 1.8, "motorway": 3.8, "motorway_link": 2.0}
    roads = [e for e in els if e["type"] == "way" and e.get("tags", {}).get("highway") in widths]
    for casing in (True, False):
        for cls in widths:
            for e in roads:
                if e["tags"]["highway"] != cls:
                    continue
                big = cls.startswith(("trunk", "motorway"))
                if casing:
                    v.line(v.pts(e["geometry"]), ROAD_EDGE, widths[cls] + 1.4)
                else:
                    v.line(v.pts(e["geometry"]), BIG_ROAD if big else ROAD, widths[cls])

    for ring in old_town:
        v.line(v.pts(ring) + v.pts(ring[:1]), "#C9A86A", 1.6)

    for e in els:
        kind = e.get("tags", {}).get("railway")
        if e["type"] == "way" and kind in ("subway", "light_rail"):
            v.dashed(v.pts(e["geometry"]), METRO, 1.6)
        elif e["type"] == "way" and kind == "tram":
            v.dashed(v.pts(e["geometry"]), TRAM, 1.6)

    # Labels, most important first: they claim their space before street names.
    v.label(v.xy(39.4700, -0.3165), "MAR MEDITERRANI", 12, "#4F8FA3", "bold", angle=-90,
            halo=WATER, spacing=1)
    v.label(v.xy(39.4745, -0.3768), "CIUTAT VELLA", 10.5, "#8A6A2F", "bold", halo=OLD_TOWN)
    for name, lat, lon in [("RUSSAFA", 39.4605, -0.3725), ("EL CABANYAL", 39.4690, -0.3300),
                           ("BENIMACLET", 39.4850, -0.3600), ("LA MALVA-ROSA", 39.4810, -0.3285),
                           ("EL GRAU", 39.4590, -0.3345), ("CAMPANAR", 39.4830, -0.3960),
                           ("L'EIXAMPLE", 39.4660, -0.3680), ("EXTRAMURS", 39.4700, -0.3880),
                           ("PORT", 39.4520, -0.3230)]:
        v.label(v.xy(lat, lon), name, 9.5, "#8A7A55", "bold", spacing=0)
    v.label(v.xy(39.4788, -0.3690), "Jardí del Túria", 10, "#3C6B33", "italic", angle=-18,
            halo=PARK)
    v.label(v.xy(39.4625, -0.3560), "Jardí del Túria", 10, "#3C6B33", "italic", angle=-40,
            halo=PARK)

    stations = {"Xàtiva": (39.4673, -0.3773)}
    for e in els:
        t = e.get("tags", {})
        if e["type"] == "node" and t.get("railway") == "station" and "name" in t:
            stations[t["name"].split(" - ")[0]] = (e["lat"], e["lon"])
    for name in ["Xàtiva", "Colón", "Alameda", "Facultats", "Benimaclet", "Marítim"]:
        if name in stations:
            x, y = v.xy(*stations[name])
            r = 3.2 * SS
            v.d.ellipse((x - r, y - r, x + r, y + r), fill="white", outline=METRO, width=SS)

    road_label_spots(v, els, ("primary", "secondary", "trunk"), 26, 9)
    credit(v)

    # Legend
    x0, y0 = 12 * SS, (H - 62) * SS
    v.d.rounded_rectangle((x0, y0, x0 + 196 * SS, y0 + 50 * SS), 6 * SS, fill="#FFFAF0",
                          outline=ROAD_EDGE, width=SS)
    v.dashed([(x0 + 12 * SS, y0 + 16 * SS), (x0 + 52 * SS, y0 + 16 * SS)], METRO, 2)
    v.dashed([(x0 + 12 * SS, y0 + 35 * SS), (x0 + 52 * SS, y0 + 35 * SS)], TRAM, 2)
    f = font("regular", 11)
    v.d.text((x0 + 62 * SS, y0 + 8 * SS), "Metro", font=f, fill=INK)
    v.d.text((x0 + 62 * SS, y0 + 27 * SS), "Tranvía", font=f, fill=INK)
    v.save(ART / "map_city.png")
    return v


# --------------------------------------------------------------------- centre

def draw_centre():
    v = View("centre")
    v.img.paste(BLOCK, (0, 0, W * SS, H * SS))
    els = load("centre")
    tags = lambda e: e.get("tags", {})

    for ring in areas(els, lambda t: t.get("leisure") in ("park", "garden")):
        v.polygon(ring, PARK)

    # squares and pedestrian areas are surfaces, not lines
    for ring in areas(els, lambda t: t.get("highway") in ("pedestrian", "footway")
                      and t.get("area") == "yes"):
        v.polygon(ring, PLAZA)
    for e in els:
        if e["type"] == "relation" and tags(e).get("highway") == "pedestrian":
            for ring in areas([e], lambda t: True):
                v.polygon(ring, PLAZA)

    widths = {"living_street": 3.0, "pedestrian": 3.0, "residential": 3.6, "unclassified": 3.6,
              "tertiary": 5.0, "tertiary_link": 3.0, "secondary": 6.5, "secondary_link": 3.5,
              "primary": 8.0, "primary_link": 4.0, "busway": 3.0}
    roads = [e for e in els if e["type"] == "way" and tags(e).get("highway") in widths
             and tags(e).get("area") != "yes"]
    for casing in (True, False):
        for cls in widths:
            for e in roads:
                if tags(e)["highway"] != cls:
                    continue
                if casing:
                    v.line(v.pts(e["geometry"]), ROAD_EDGE, widths[cls] + 1.6)
                else:
                    v.line(v.pts(e["geometry"]), PLAZA if cls in ("pedestrian", "living_street")
                           else ROAD, widths[cls])

    for ring in areas(els, lambda t: "building" in t):
        v.polygon(ring, BUILDING, BUILDING_EDGE, 0.5)

    for e in els:
        kind = tags(e).get("railway")
        if e["type"] == "way" and kind in ("subway", "light_rail"):
            v.dashed(v.pts(e["geometry"]), METRO, 2.2, 9, 6)
        elif e["type"] == "way" and kind == "tram":
            v.dashed(v.pts(e["geometry"]), TRAM, 2.2, 9, 6)

    landmarks = {"Mercat Central": "Mercat Central", "Llotja de la Seda": "La Llotja",
                 "Catedral de València": "Catedral", "Estació del Nord": "Estació del Nord",
                 "Plaça de Bous de València": "Plaça de Bous",
                 "Torres de Serrans": "Torres de Serrans", "Torres de Quart": "Torres de Quart",
                 "Ajuntament de València": "Ajuntament"}
    for e in els:
        name = tags(e).get("name")
        if name in landmarks and "building" in tags(e):
            rings = areas([e], lambda t: True)
            if not rings:
                continue
            for ring in rings:
                v.polygon(ring, "#CFA56A", "#8A6A2F", 1)
            pts = v.pts(max(rings, key=len))
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            v.label((cx, cy), landmarks[name], 10.5, "#5B3A29", "bold", halo="#F4E4C2")

    v.label(v.xy(39.4776, -0.3812), "EL CARME", 11, "#8A6A2F", "bold", halo=BLOCK, spacing=1)
    v.label(v.xy(39.4690, -0.3715), "L'EIXAMPLE", 11, "#8A6A2F", "bold", halo=BLOCK, spacing=1)
    v.label(v.xy(39.4797, -0.3735), "Jardí del Túria", 11, "#3C6B33", "italic", angle=-12,
            halo=PARK)

    stations = {"Xàtiva": (39.4673, -0.3773)}
    for e in els:
        if e["type"] == "node" and tags(e).get("railway") == "station" and "name" in tags(e):
            name = tags(e)["name"]
            if "Estació del Nord" not in name:
                stations[name.split(" - ")[0]] = (e["lat"], e["lon"])
    for name, (lat, lon) in stations.items():
        x, y = v.xy(lat, lon)
        if not v.inside((x, y), -20 * SS):
            continue
        r = 8 * SS
        v.d.ellipse((x - r, y - r, x + r, y + r), fill=METRO, outline="white", width=SS)
        f = font("bold", 10)
        v.d.text((x, y), "M", font=f, fill="white", anchor="mm")
        v.label((x, y + 17 * SS), name, 10, METRO, "bold", halo="#FFFAF0", force=True)

    road_label_spots(v, els, tuple(widths), 60, 9.5)
    credit(v)
    v.save(ART / "map_centre.png")
    return v


# ----------------------------------------------------------------------- pins

def make_pins():
    content = json.loads((ROOT / "game/data/content.json").read_text(encoding="utf-8"))
    size = 112
    for loc in content["locations"]:
        src = ART / f"val_{loc['id']}.png"
        if not src.exists():
            continue
        img = Image.open(src).convert("RGB")
        side = img.width
        top = int(img.height * 0.14)
        crop = img.crop((0, top, side, top + side)).resize((size * 2, size * 2), Image.LANCZOS)
        mask = Image.new("L", (size * 2, size * 2), 0)
        ImageDraw.Draw(mask).ellipse((2, 2, size * 2 - 3, size * 2 - 3), fill=255)
        pin = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
        pin.paste(crop, (0, 0), mask)
        pin.resize((size, size), Image.LANCZOS).save(ART / f"pin_{loc['id']}.png")
    print(f"pins: {len(content['locations'])}")


def main():
    city = draw_city()
    centre = draw_centre()
    make_pins()
    # where the old-town view sits on the city view, for the "zoom in" frame
    half_w = W / 2 / centre.scale / KX
    half_h = H / 2 / centre.scale / KY
    x0, y0 = city.xy(centre.lat0 + half_h, centre.lon0 - half_w)
    x1, y1 = city.xy(centre.lat0 - half_h, centre.lon0 + half_w)
    out = {"kx": KX, "ky": KY, "size": [W, H], "views": VIEWS,
           "centre_on_city": [x0 / SS, y0 / SS, (x1 - x0) / SS, (y1 - y0) / SS]}
    (ROOT / "game/data/map.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
    print("maps written; centre frame on city:", [round(n) for n in out["centre_on_city"]])


if __name__ == "__main__":
    main()
