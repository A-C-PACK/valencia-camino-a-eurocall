"""Write one Ideogram caption per location illustration into art/captions/.

Every scene shares one style block so the twelve places read as one set.
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
        "A cosy little wine bar in the Ruzafa neighbourhood of Valencia in the evening, with the "
        "owner pouring a glass of red wine at the bar.",
        "A warm narrow bar with exposed brick, shelves of wine bottles without readable labels, "
        "hanging filament bulbs and a street door open to the blue dusk.",
        [([240, 300, 660, 640], "A woman in her mid thirties with dark hair tied back and a dark "
          "apron, pouring red wine into a glass and smiling wryly.", ["#F2C9A0", "#1F3A4D", "#B8402A"]),
         ([600, 0, 860, 1000], "A wooden bar top with small plates of tapas: olives, cheese, bread "
          "with tomato, and two wine glasses.", ["#5B3A29", "#3F7D4E", "#E8A33D"]),
         ([0, 0, 380, 1000], "Shelves of dark wine bottles and warm hanging bulbs.",
          ["#5B3A29", "#E8A33D", "#B8402A"]),
         ([640, 660, 960, 960], "A blonde woman customer on a bar stool laughing, holding a "
          "notebook.", ["#E9D3A1", "#7FC4D6", "#F2C9A0"])]),
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
