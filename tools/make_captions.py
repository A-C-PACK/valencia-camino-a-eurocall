"""Write one Ideogram caption per location illustration into art/captions/.

Every scene shares one style block so all the places read as one set.
No text elements: signage rendered by the model would be uncontrolled Spanish
sitting next to carefully levelled Spanish, so the scenes stay wordless.

    python tools/make_captions.py
"""

import json
import pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "art" / "captions"

PALETTE = ["#F6E7C8", "#E8A33D", "#D9622B", "#B8402A", "#2E6F8E", "#7FC4D6",
           "#3F7D4E", "#F2C9A0", "#5B3A29", "#FFFFFF", "#1F3A4D", "#E9D3A1"]

STYLE = {
    "aesthetics": "Warm, inviting vintage travel-poster illustration of Valencia, Spain; "
                  "simple confident shapes, gentle grain, uncluttered composition, "
                  "no lettering, no signs with words, no captions, no user interface.",
    "lighting": "Bright Mediterranean light with soft warm shadows.",
    "medium": "Gouache painting.",
    "art_style": "Mid-century gouache travel poster with flat layered shapes, visible "
                 "brush texture and a limited warm palette.",
    "color_palette": PALETTE,
}

# id: (high level, background, [(bbox, desc, palette), ...])   bbox = [y0, x0, y1, x1]
SCENES = {
    "title": (
        "A tall travel-poster view of Valencia's old town at golden hour, with the octagonal "
        "Miguelete bell tower rising over terracotta rooftops, orange trees in the foreground "
        "and swifts in a wide warm sky.",
        "A wide glowing sky fading from pale gold near the rooftops to soft teal at the top, "
        "above a sea of terracotta roofs and pale stone facades.",
        [([180, 380, 720, 640], "The Miguelete, a tall octagonal Gothic stone bell tower with a small "
          "belfry on top, pale honey stone lit warmly from the left.", ["#E9D3A1", "#D9622B", "#5B3A29"]),
         ([560, 0, 820, 1000], "Layered terracotta rooftops and a blue-tiled church dome among pale "
          "plastered buildings with small balconies.", ["#D9622B", "#2E6F8E", "#F6E7C8"]),
         ([760, 0, 1000, 1000], "Foreground orange trees with dark glossy leaves and bright round "
          "oranges, framing the bottom of the picture.", ["#3F7D4E", "#E8A33D", "#5B3A29"]),
         ([60, 100, 300, 900], "A few small dark swifts wheeling in the open sky.", ["#1F3A4D"])]),
    "aeropuerto": (
        "The taxi rank outside a small modern Mediterranean airport terminal on a sunny afternoon, "
        "with an older taxi driver waiting beside his white taxi.",
        "A low glass-and-steel terminal building under a clear blue sky, with a row of palm trees "
        "and a covered walkway along the kerb.",
        [([430, 80, 900, 760], "A white four-door saloon taxi parked at the kerb, seen from the side, "
          "with a small green light on its roof and all of its doors closed.", ["#FFFFFF", "#3F7D4E", "#1F3A4D"]),
         ([380, 660, 920, 900], "A man of about seventy with grey hair, a short-sleeved shirt and a "
          "weathered friendly face, standing on the pavement beside the taxi with one arm "
          "raised in greeting.",
          ["#F2C9A0", "#F6E7C8", "#5B3A29"]),
         ([760, 300, 960, 520], "A rolling suitcase standing on the pavement in the foreground.",
          ["#B8402A", "#1F3A4D"]),
         ([120, 0, 480, 1000], "Tall palm trees in a row in front of the terminal.",
          ["#3F7D4E", "#5B3A29"])]),
    "hotel": (
        "The reception of a small charming hotel in an old Valencian townhouse, with a receptionist "
        "smiling behind a wooden desk.",
        "A cool high-ceilinged lobby with patterned hydraulic floor tiles, a pale wall with an arched "
        "doorway and a tall window letting in sunlight.",
        [([420, 100, 800, 900], "A long polished wooden reception desk with a brass bell, a small "
          "vase of flowers and a rack of room keys on the wall behind it.", ["#5B3A29", "#E8A33D", "#F6E7C8"]),
         ([250, 380, 640, 640], "A young man in a neat dark waistcoat and white shirt standing behind "
          "the desk, smiling politely.", ["#1F3A4D", "#FFFFFF", "#F2C9A0"]),
         ([780, 0, 1000, 1000], "Decorative floor tiles in a repeating geometric pattern of ochre, "
          "teal and cream.", ["#E8A33D", "#2E6F8E", "#F6E7C8"]),
         ([200, 720, 760, 980], "A large potted palm beside the desk.", ["#3F7D4E", "#D9622B"])]),
    "metro": (
        "A clean modern underground metro platform in Valencia with a train arriving and a few "
        "passengers waiting.",
        "A bright tunnel station with a curved pale ceiling, a long platform with a yellow safety "
        "line and a ticket machine against the wall.",
        [([330, 0, 760, 620], "A modern metro train with a white and red livery and large windows, "
          "pulling in along the platform edge.", ["#FFFFFF", "#B8402A", "#1F3A4D"]),
         ([380, 640, 900, 860], "A woman in a transport uniform with a lanyard, standing by a ticket "
          "machine and gesturing helpfully.", ["#2E6F8E", "#F2C9A0", "#1F3A4D"]),
         ([420, 860, 800, 1000], "A tall ticket vending machine with a glowing screen and no readable "
          "words.", ["#D9622B", "#7FC4D6"]),
         ([760, 0, 1000, 1000], "The platform floor with a bold yellow safety stripe.",
          ["#E9D3A1", "#E8A33D"])]),
    "mercado": (
        "A fruit and vegetable stall inside Valencia's Central Market, piled with oranges and "
        "tomatoes beneath the market's iron and stained-glass dome.",
        "The soaring interior of a modernist market hall with slender iron columns, coloured glass "
        "panels and ceramic tile details, light pouring down from a dome.",
        [([520, 0, 1000, 1000], "A generous market stall with sloping crates of oranges, lemons, "
          "tomatoes, peppers and bunches of herbs.", ["#E8A33D", "#B8402A", "#3F7D4E"]),
         ([300, 330, 640, 660], "A cheerful woman of about fifty in a striped apron behind the stall, "
          "holding up an orange.", ["#F2C9A0", "#2E6F8E", "#E8A33D"]),
         ([0, 150, 330, 850], "The underside of a great dome of iron ribs and stained glass in amber "
          "and blue.", ["#E8A33D", "#7FC4D6", "#5B3A29"]),
         ([330, 0, 540, 300], "Hanging cured hams and strings of dried peppers at a neighbouring "
          "stall.", ["#B8402A", "#5B3A29"])]),
    "horchateria": (
        "A table at a traditional Valencian horchateria with two tall glasses of creamy horchata "
        "and a plate of long sugar-glazed fartons pastries.",
        "An old cafe interior covered in hand-painted blue and yellow ceramic tiles, with marble "
        "tables and bentwood chairs.",
        [([520, 120, 920, 880], "A round white marble table seen slightly from above with two tall "
          "glasses of pale creamy horchata and a plate of long thin glazed pastries.",
          ["#FFFFFF", "#F6E7C8", "#E9D3A1"]),
         ([200, 560, 620, 880], "A waiter in a white shirt and black apron carrying a small round "
          "tray, smiling.", ["#FFFFFF", "#1F3A4D", "#F2C9A0"]),
         ([0, 0, 520, 1000], "Walls of traditional glazed tiles painted with blue and yellow floral "
          "scenes, with no writing.", ["#2E6F8E", "#E8A33D", "#F6E7C8"])]),
    "catedral": (
        "The Plaza de la Reina in Valencia with the cathedral's baroque doorway and the tall "
        "octagonal Miguelete tower, seen from the square on a bright morning.",
        "A broad sunny paved square edged with trees and cafe umbrellas beneath a clear sky.",
        [([60, 420, 800, 700], "The Miguelete, a tall octagonal Gothic bell tower of pale honey "
          "stone.", ["#E9D3A1", "#5B3A29"]),
         ([400, 150, 820, 480], "A curved baroque stone church doorway with columns and sculpted "
          "figures beside the tower.", ["#E9D3A1", "#D9622B"]),
         ([620, 640, 940, 900], "A young woman guide holding a small folded umbrella aloft, turning "
          "to speak to visitors.", ["#B8402A", "#F2C9A0", "#1F3A4D"]),
         ([780, 0, 1000, 620], "Cafe tables under cream umbrellas and a few orange trees in "
          "planters.", ["#F6E7C8", "#3F7D4E", "#E8A33D"])]),
    "farmacia": (
        "The inside of a tidy Spanish pharmacy with a pharmacist in a white coat at the counter.",
        "Clean white shelves lined with small plain boxes and bottles, filling the whole wall "
        "behind the counter.",
        [([260, 320, 700, 690], "A woman pharmacist of about forty with shoulder-length dark hair, "
          "glasses and an open white coat, standing upright behind the counter, looking straight "
          "at the viewer with open eyes and a warm reassuring smile.",
          ["#FFFFFF", "#F2C9A0", "#5B3A29"]),
         ([600, 60, 880, 940], "A pale counter with a small paper bag and a box of tablets on it.",
          ["#F6E7C8", "#7FC4D6"]),
         ([60, 720, 260, 900], "A glowing green pharmacy cross sign on the wall.",
          ["#3F7D4E", "#FFFFFF"]),
         ([0, 0, 560, 1000], "Tall white shelving with neat rows of small coloured boxes.",
          ["#FFFFFF", "#7FC4D6", "#E8A33D"])]),
    "playa": (
        "A beachfront restaurant terrace at Malvarrosa beach in Valencia at lunchtime, with a wide "
        "paella pan on the table and the sea beyond.",
        "A wide pale sandy beach and calm blue Mediterranean under a bright sky, with a palm-lined "
        "promenade.",
        [([540, 150, 920, 850], "A wooden table with a large shallow paella pan of golden rice with "
          "green beans and chicken, lemon wedges and two plates.", ["#E8A33D", "#3F7D4E", "#5B3A29"]),
         ([250, 620, 700, 900], "A waitress in a white shirt and long dark apron holding a notepad, "
          "smiling.", ["#FFFFFF", "#1F3A4D", "#F2C9A0"]),
         ([0, 0, 300, 1000], "A striped awning in white and blue shading the terrace.",
          ["#FFFFFF", "#2E6F8E"]),
         ([280, 0, 560, 620], "The beach and sea with a few tiny distant bathers and a sailing boat.",
          ["#F6E7C8", "#7FC4D6", "#2E6F8E"])]),
    "ciencias": (
        "The futuristic white buildings of Valencia's City of Arts and Sciences reflected in "
        "shallow turquoise pools, with a cyclist on the path in the foreground.",
        "A vivid blue sky over long shallow reflecting pools of pale turquoise water bordered by "
        "white paving.",
        [([220, 60, 600, 700], "A huge white curved building shaped like a giant eye or helmet with "
          "sweeping ribs, covered in white mosaic.", ["#FFFFFF", "#7FC4D6", "#1F3A4D"]),
         ([300, 600, 620, 1000], "A long white skeletal building with repeating arched ribs like a "
          "whale skeleton.", ["#FFFFFF", "#E9D3A1"]),
         ([620, 380, 960, 760], "A man of about thirty in a bright t-shirt standing beside a rental "
          "bicycle and pointing the way.", ["#D9622B", "#F2C9A0", "#1F3A4D"]),
         ([600, 0, 800, 1000], "Still turquoise water mirroring the white architecture.",
          ["#7FC4D6", "#FFFFFF"])]),
    "congreso": (
        "The registration desk of an academic conference in a bright modern university atrium, "
        "with a friendly volunteer handing over a name badge.",
        "A light-filled university hall with tall windows, pale concrete and wood, and blank "
        "poster boards along one side.",
        [([520, 80, 820, 920], "A long registration table covered with a plain cloth, with rows of "
          "name badges on lanyards and a stack of tote bags.", ["#2E6F8E", "#F6E7C8", "#E8A33D"]),
         ([260, 360, 660, 640], "A young woman volunteer in a teal t-shirt holding out a name badge "
          "on a lanyard with a warm smile.", ["#2E6F8E", "#F2C9A0", "#5B3A29"]),
         ([300, 700, 760, 960], "Two conference attendees chatting with coffee cups in hand.",
          ["#B8402A", "#1F3A4D", "#F2C9A0"]),
         ([60, 0, 460, 320], "Free-standing poster boards with abstract coloured blocks and no "
          "readable writing.", ["#FFFFFF", "#D9622B", "#7FC4D6"])]),
    "ruzafa": (
        "A painted travel-poster scene inside a cosy little wine bar in Valencia in the "
        "evening, seen at eye level from beside the bar: the owner stands behind the bar "
        "pouring red wine for a woman customer who sits on a tall bar stool, the two adult "
        "women the same size with their heads at the same height, realistic proportions.",
        "A warm narrow bar with an exposed brick wall, shelves of dark wine bottles without "
        "readable labels, a few hanging filament bulbs and a street door open onto a quiet "
        "blue dusk street of plain shuttered house fronts and one glowing street lamp.",
        [([170, 60, 640, 460], "A woman in her mid thirties with dark hair tied back, a white "
          "shirt and a dark apron, standing behind the bar, pouring red wine from a bottle "
          "into a glass and smiling wryly.", ["#F2C9A0", "#1F3A4D", "#B8402A"]),
         ([180, 540, 960, 940], "A blonde woman in her mid thirties in a light blue blouse, "
          "seen in three-quarter view, sitting upright on a tall wooden bar stool with her "
          "elbow resting on the bar top and a small notebook beside her, laughing.",
          ["#E9D3A1", "#7FC4D6", "#F2C9A0"]),
         ([600, 0, 720, 1000], "A long polished wooden bar top at elbow height with small "
          "plates of olives, cheese and bread with tomato, and two wine glasses.",
          ["#5B3A29", "#3F7D4E", "#E8A33D"]),
         ([0, 0, 220, 1000], "Shelves of dark wine bottles and warm hanging bulbs.",
          ["#5B3A29", "#E8A33D", "#B8402A"]),
         ([720, 0, 1000, 560], "The dark wood panelled front of the bar.",
          ["#5B3A29", "#D9622B"])]),
    "tablao": (
        "A small intimate flamenco tablao at night: a dancer in a red dress mid-turn on a wooden "
        "stage, with a guitarist and a singer seated behind her.",
        "A dark intimate room with a low wooden stage, a deep red back wall and a few candlelit "
        "tables in shadow in the foreground.",
        [([180, 300, 820, 720], "A flamenco dancer in a long red ruffled dress with one arm raised "
          "and her skirt swirling, hair pulled back with a flower.", ["#B8402A", "#D9622B", "#5B3A29"]),
         ([360, 60, 800, 320], "A seated guitarist in a dark suit bent over a Spanish guitar.",
          ["#1F3A4D", "#E8A33D", "#F2C9A0"]),
         ([360, 720, 800, 960], "A seated singer in a dark shirt clapping his hands, head tilted "
          "back as he sings.", ["#1F3A4D", "#F2C9A0"]),
         ([820, 0, 1000, 1000], "Silhouetted small round tables with candles and glasses at the "
          "front edge of the picture.", ["#5B3A29", "#E8A33D"])]),
    # ---- part 2: the history readings
    "almoina": (
        "An underground archaeological site in Valencia: low ancient Roman stone walls and "
        "column stumps lit by rippling light that falls through a glass ceiling with water above.",
        "A wide dim underground hall with a pale sandy floor and a glowing ceiling of glass "
        "under shallow water that throws soft blue ripples of light over everything.",
        [([420, 0, 1000, 1000], "Low ruined walls of rough ancient stone and brick laid out like "
          "the floor plan of small rooms, with a round stone basin.", ["#E9D3A1", "#5B3A29", "#D9622B"]),
         ([300, 100, 720, 330], "Three broken Roman column stumps of pale stone standing in a "
          "row.", ["#F6E7C8", "#E9D3A1"]),
         ([0, 0, 320, 1000], "A ceiling of glass panels with sunlit water above, bright turquoise "
          "and white.", ["#7FC4D6", "#FFFFFF", "#2E6F8E"]),
         ([480, 640, 900, 860], "A young woman guide seen from behind, pointing at the ruins from "
          "a metal walkway.", ["#B8402A", "#1F3A4D", "#F2C9A0"])]),
    "valldigna": (
        "A narrow old lane in the Carmen quarter of Valencia passing under a plain round stone "
        "arch between two houses, with a small balcony of flowerpots above the arch.",
        "A shaded narrow street of pale plastered old houses with wooden shutters, sunlight "
        "falling on the far side of the arch.",
        [([250, 280, 1000, 720], "A simple semicircular archway of worn stone blocks spanning "
          "the lane, deep enough to walk through, with bright sunlight beyond it.",
          ["#E9D3A1", "#5B3A29", "#F6E7C8"]),
         ([120, 300, 300, 700], "A small iron balcony above the arch crowded with terracotta "
          "pots of red geraniums.", ["#B8402A", "#3F7D4E", "#1F3A4D"]),
         ([0, 0, 1000, 290], "The tall wall of an old house in warm ochre plaster with green "
          "wooden shutters.", ["#E8A33D", "#3F7D4E"]),
         ([0, 710, 1000, 1000], "An old wall of rammed earth and rough stone, part of a "
          "medieval city wall, with a climbing plant.", ["#E9D3A1", "#5B3A29", "#3F7D4E"])]),
    "serranos": (
        "The Torres de Serranos in Valencia, a massive Gothic city gate of two polygonal stone "
        "towers joined over a pointed archway, seen from the square in front in morning light.",
        "A clear blue sky and a broad paved square with a few small trees.",
        [([120, 80, 900, 460], "A huge polygonal tower of pale honey stone with battlements "
          "on top.", ["#E9D3A1", "#5B3A29"]),
         ([120, 540, 900, 920], "A matching huge polygonal tower of pale honey stone with "
          "battlements on top.", ["#E9D3A1", "#5B3A29"]),
         ([300, 420, 900, 580], "A central section joining the two towers, with a tall pointed "
          "gateway at the bottom and delicate Gothic stone tracery above it.",
          ["#E9D3A1", "#D9622B", "#1F3A4D"]),
         ([800, 560, 980, 760], "Two small figures of visitors walking towards the gate, one "
          "carrying a notebook.", ["#B8402A", "#2E6F8E", "#F2C9A0"])]),
    "lonja": (
        "The interior of the Silk Exchange in Valencia: a tall Gothic hall where slender twisted "
        "stone columns spiral upwards and branch into a ribbed vault like palm trees.",
        "A high pale stone hall filled with soft golden light from tall Gothic windows, with a "
        "floor of patterned marble.",
        [([0, 150, 880, 330], "A slender spiral-twisted stone column rising from floor to vault.",
          ["#E9D3A1", "#F6E7C8", "#5B3A29"]),
         ([0, 660, 880, 840], "A second slender spiral-twisted stone column rising from floor "
          "to vault.", ["#E9D3A1", "#F6E7C8", "#5B3A29"]),
         ([0, 0, 300, 1000], "A stone vault of star-patterned ribs spreading from the tops of "
          "the columns like palm fronds.", ["#E9D3A1", "#E8A33D"]),
         ([820, 0, 1000, 1000], "A floor of marble tiles in a bold geometric pattern of black, "
          "white and warm brown.", ["#1F3A4D", "#FFFFFF", "#5B3A29"]),
         ([620, 400, 900, 600], "Two small visitors looking up at the ceiling.",
          ["#B8402A", "#2E6F8E", "#F2C9A0"])]),
    "patriarca": (
        "A quiet two-storey Renaissance cloister in Valencia with rows of slender white marble "
        "columns and round arches around a sunny courtyard.",
        "A square courtyard paved in pale stone under a deep blue sky, enclosed by two tiers "
        "of arcades.",
        [([330, 0, 640, 1000], "An upper gallery of small round arches on thin white marble "
          "columns with a stone balustrade.", ["#FFFFFF", "#E9D3A1", "#1F3A4D"]),
         ([600, 0, 900, 1000], "A lower arcade of larger round arches on white marble columns, "
          "with deep cool shadow behind.", ["#FFFFFF", "#E9D3A1", "#5B3A29"]),
         ([560, 420, 860, 580], "A white marble statue of a seated bishop on a pedestal in the "
          "middle of the courtyard.", ["#FFFFFF", "#E9D3A1"]),
         ([640, 700, 940, 880], "A man in his fifties in a linen jacket, a university "
          "professor, standing with a book under his arm.", ["#37506B", "#F2C9A0", "#F6E7C8"])]),
    "quart": (
        "The Torres de Quart in Valencia: two massive round medieval towers of rough grey-brown "
        "stone flanking a gateway, their walls pitted with round cannonball holes.",
        "A bright sky and a street of low old houses leading up to the gate.",
        [([100, 40, 920, 440], "A huge cylindrical tower of rough stone with battlements, its "
          "surface scarred with many round holes of different sizes.",
          ["#E9D3A1", "#5B3A29", "#1F3A4D"]),
         ([100, 560, 920, 960], "A matching huge cylindrical tower of rough stone with "
          "battlements, also scarred with round holes.", ["#E9D3A1", "#5B3A29", "#1F3A4D"]),
         ([380, 420, 920, 580], "A plain wall between the towers with a tall round-arched "
          "gateway.", ["#E9D3A1", "#1F3A4D"]),
         ([820, 300, 990, 520], "A young woman guide with a small folded red umbrella pointing "
          "up at the tower.", ["#B8402A", "#F2C9A0", "#1F3A4D"])]),
    "norte": (
        "The front of the North Station in Valencia, an ornate early twentieth century railway "
        "station decorated with ceramic oranges and orange blossom, with a white taxi outside.",
        "A clear warm sky above a wide pavement with palm trees.",
        [([120, 0, 760, 1000], "A wide symmetrical station facade in cream and ochre with "
          "small towers, tall windows, bands of green and white tiles and clusters of ceramic "
          "oranges with leaves, with no lettering.", ["#F6E7C8", "#E8A33D", "#3F7D4E", "#D9622B"]),
         ([60, 400, 260, 600], "A decorative crest at the top centre of the facade with a "
          "five-pointed star.", ["#E8A33D", "#B8402A"]),
         ([700, 80, 960, 620], "A white four-door saloon taxi parked at the kerb with a small "
          "green light on its roof.", ["#FFFFFF", "#3F7D4E", "#1F3A4D"]),
         ([620, 640, 960, 820], "A grey-haired taxi driver of about seventy in a short-sleeved "
          "shirt standing by the taxi, looking up at the station.",
          ["#F2C9A0", "#F6E7C8", "#5B3A29"])]),
    "refugio": (
        "The inside of a Spanish Civil War air-raid shelter: a long empty underground room with "
        "a low curved concrete ceiling and plain benches along both walls.",
        "A bare concrete tunnel-like room receding into the distance, lit by a few dim bulbs, "
        "quiet and still, with blank walls.",
        [([0, 0, 420, 1000], "A low barrel-vaulted ceiling of pale grey concrete with a line of "
          "small hanging light bulbs glowing warmly.", ["#E9D3A1", "#E8A33D", "#5B3A29"]),
         ([480, 0, 900, 300], "A long plain bench built along the left wall.",
          ["#5B3A29", "#E9D3A1"]),
         ([480, 700, 900, 1000], "A long plain bench built along the right wall.",
          ["#5B3A29", "#E9D3A1"]),
         ([300, 400, 640, 600], "A narrow doorway at the far end with a few steps leading up "
          "towards daylight.", ["#F6E7C8", "#7FC4D6"]),
         ([640, 0, 1000, 1000], "A bare worn concrete floor running the whole length of the "
          "room between the benches, completely empty.", ["#E9D3A1", "#5B3A29"])]),
    "turia": (
        "The Turia Garden in Valencia: a long sunken green park of lawns, pines and palms, "
        "crossed by an old stone bridge whose arches stand on dry grass, with a cyclist and a "
        "runner on a path that passes under the bridge.",
        "A bright sky over a dry sunken park of lawns and trees between two low stone walls, "
        "with city rooftops beyond.",
        [([240, 0, 600, 1000], "A long old stone bridge with a row of round arches spanning the "
          "whole picture, pale honey stone, its piers standing on green grass.",
          ["#E9D3A1", "#5B3A29", "#3F7D4E"]),
         ([420, 0, 760, 1000], "Green lawn, umbrella pines, palms and orange trees growing "
          "under and around the arches, with a pale gravel footpath passing through one arch.",
          ["#3F7D4E", "#E8A33D", "#F6E7C8"]),
         ([720, 0, 1000, 1000], "A curving path of pale gravel beside a green lawn with "
          "flower beds.", ["#F6E7C8", "#3F7D4E", "#B8402A"]),
         ([700, 520, 960, 800], "A cyclist and a runner on the path.",
          ["#D9622B", "#2E6F8E", "#F2C9A0"])]),
    "cabanyal": (
        "A street of low two-storey houses in the Cabanyal fishing quarter of Valencia, "
        "each front covered in glazed tiles of a different colour, with wrought-iron balconies.",
        "A long straight narrow street under a vivid blue sky, with the sea just visible at "
        "the far end.",
        [([200, 0, 900, 340], "A house front covered in glossy green tiles with white floral "
          "borders, a wooden door and an iron balcony.", ["#3F7D4E", "#FFFFFF", "#5B3A29"]),
         ([200, 330, 900, 660], "A house front covered in blue and white tiles in a geometric "
          "pattern, with a balcony of flowerpots.", ["#2E6F8E", "#FFFFFF", "#B8402A"]),
         ([200, 650, 900, 1000], "A house front covered in ochre yellow tiles with a tiled panel "
          "of a small sailing boat above the door.", ["#E8A33D", "#F6E7C8", "#2E6F8E"]),
         ([640, 380, 960, 560], "A grey-haired man of about seventy in a short-sleeved shirt, "
          "standing in the street and gesturing proudly at the houses.",
          ["#F2C9A0", "#F6E7C8", "#5B3A29"])]),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (high, background, elements) in SCENES.items():
        caption = {
            "high_level_description": high,
            "style_description": STYLE,
            "compositional_deconstruction": {
                "background": background,
                "elements": [{"type": "obj", "bbox": b, "desc": d, "color_palette": p}
                             for b, d, p in elements],
            },
        }
        (OUT / f"val_{name}.json").write_text(
            json.dumps(caption, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {len(SCENES)} captions to {OUT}")


if __name__ == "__main__":
    main()
