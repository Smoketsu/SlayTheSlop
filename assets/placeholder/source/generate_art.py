"""Generates the placeholder art made with the OpenAI image API (tasks 061 and 063).

Lane: assets (taken over by Agent A from Agent B, 2026-10-13, at Smoketsu's request).
How the art should look and how to add more: assets/STYLE_GUIDE.md. Where each file came from:
assets/placeholder/README.md.

Usage, from the repository root, in an environment where the OpenAI API is reachable and
authorised (the key is never read, printed or stored by this script; the environment supplies it):

    python3 assets/placeholder/source/generate_art.py RAW_DIR [NAME ...]
    python3 assets/placeholder/source/generate_art.py --convert RAW_DIR

The first form generates every spec in SPECS (or only the named outputs) into RAW_DIR as PNG, skipping
files that already exist, and appends one line per call to RAW_DIR/usage.jsonl (model, size, quality,
token usage). The second converts RAW_DIR into the game files under assets/placeholder/ (CONVERT).
Generation costs money on the account behind the API, about $0.03-0.05 per image at "medium".
"""
import base64, json, os, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

## Image model used for every spec. Changed by whoever regenerates art; record it in README.md.
MODEL = "gpt-image-2.5-sunburst"
## Quality tier for every call: "low", "medium" or "high" (high costs about four times medium).
QUALITY = "medium"
## Parallel API calls at once (a politeness limit, not a rule).
WORKERS = 4
## Folder holding the reference art, relative to the repository root.
PLACEHOLDER = "assets/placeholder"
## Style references by key: "scene" (characters + the Basement, for splashes and the map) and
## "sheet" (characters only, for icons and UI). Paths relative to the repository root.
REFS = {
    "scene": [f"{PLACEHOLDER}/source/character_sheet.webp", f"{PLACEHOLDER}/backgrounds/basement.webp"],
    "sheet": [f"{PLACEHOLDER}/source/character_sheet.webp"],
}
## The shared style line appended to every prompt (assets/STYLE_GUIDE.md "Prompt template").
STYLE = ("Art style: match the reference images exactly - bold dark ink outlines, cel-shaded comic "
         "fantasy game art, warm candlelit palette, chunky exaggerated proportions, slightly grimy and "
         "comedic. The bald, heavily muscled man in a red sleeveless tunic, brown leather belt and boots "
         "from the character sheet is Tom; keep his look identical. No real-world brand names or logos. "
         "No watermark, no UI, no captions.")
## Prefix for splash prompts: the 16:9 framing and the calm bottom part for UI.
SPLASH = "Wide 16:9 composition, the subject readable at a glance, keep the bottom quarter calm and uncluttered for UI text. "
## Prefix for map node icons: one round medallion on a transparent background.
ICON = ("A single round medallion badge icon, bronze rim with rivets, dark slate inner disc, centered, filling "
        "most of the canvas, on a fully transparent background with nothing else around it. It must read "
        "clearly at 48 pixels. No text. The badge shows: ")
## Every image: (raw file name, size, background "opaque"/"transparent", REFS key, subject prompt).
SPECS = [
 ("splash_gas_station_sushi.png", "1536x1024", "opaque", "scene", 'Splash illustration for a roguelike event called "Gas-Station Sushi". Tom stands in a grimy late-night gas station aisle under flickering fluorescent light, holding up a sad plastic tray of sushi at arm\'s length and squinting at it with deep suspicion while his stomach visibly gurgles. The tray has one sticker that says FRESH, written three times in three different pen colors. Behind him: a dusty hot-dog roller, a buzzing cooler of unlabeled sodas, a bored goblin cashier. Funny, readable at a glance, Tom large in the left-center of the frame, wide 16:9 composition with clear empty space at the bottom for text.'),
 ("splash_baileys.png", "1536x1024", "opaque", "scene", 'Splash illustration for "Baileys", a shop inside a fantasy dungeon that sells weed. A cozy hole-in-the-wall cave dispensary: wooden counter, glass jars of green cannabis buds on shelves, little burlap baggies labeled SHAKE, a hand-painted sign reading "BAILEYS", hazy green smoke curling in the lamplight, lava lamps and a tapestry. Behind the counter a very relaxed hooded goblin shopkeeper with half-closed eyes. Tom leans on the counter, overly eager, holding out a fistful of crumpled cash. Absolutely no alcohol: no beer, no bottles, no cans, no cups, no kegs. Wide 16:9 composition, clear empty space along the bottom for text.'),
 ("splash_beer_pong_table.png", "1536x1024", "opaque", "scene", SPLASH + "Side Quest splash 'The Beer Pong Table': in a candlelit party basement, a wobbly folding table with ten red plastic cups racked in a triangle. Across the table a lanky goblin in a sweatband and a too-small jersey brags that he almost went pro. Tom squints along his arm, ping-pong ball pinched in his huge fingers, supremely confident and clearly about to miss. Spilled cups on the floor."),
 ("splash_free_couch_on_the_curb.png", "1536x1024", "opaque", "scene", SPLASH + "Side Quest splash 'Free Couch on the Curb': night, a curb outside a run-down college house under a buzzing streetlight. A sagging floral couch with a big stain shaped like a small country and a cardboard sign that says FREE. Two small glowing eyes peek out from between the cushions. Tom gazes at the couch with pure love, arms spread as if to hug it."),
 ("splash_three_am_tattoo.png", "1536x1024", "opaque", "scene", SPLASH + "Side Quest splash '3 a.m. Tattoo': a dim, cramped tattoo parlor; a wall clock reads 3:00; flash sheets of generic skulls, daggers and hearts on the walls. A droopy-eyed kobold tattoo artist, mostly asleep, holds a buzzing tattoo machine. Tom sits in the chair flexing his bicep and pointing at it with total confidence, no design in mind."),
 ("splash_unlabeled_brownie.png", "1536x1024", "opaque", "scene", SPLASH + "Side Quest splash 'The Unlabeled Brownie': a lone brownie on a flimsy paper plate sits on a sticky basement table, lit by a single dramatic spotlight beam as if it were a holy relic, faint wavy aura around it. No label, no owner, no note. Tom leans in from the side, sweating, one hand reaching while the other hand tries to hold it back."),
 ("splash_tailgate.png", "1536x1024", "opaque", "scene", SPLASH + "Rest-site splash 'The Tailgate': dusk at a cozy campground tailgate outside the dungeon entrance. An old pickup truck with its tailgate down holding a rack of rusty dumbbells, a grill with sizzling burgers, folding camp chairs, a campfire, string lights, an acoustic guitar leaning on a cooler. Tom naps blissfully in a hammock with one arm still curling a dumbbell. Warm, safe, restful mood. No beer cans or bottles visible."),
 ("map_basement.png", "1536x1024", "opaque", "scene", "Top-down view of a hand-drawn party flyer used as a dungeon map: a sheet of crumpled paper taped to a beer-stained wooden table. The paper shows a rough ink floor plan of a party basement with a few faint doodled rooms and arrows, mostly empty paper in the middle so game nodes can be drawn over it. Around the edges: masking tape, cup rings, pizza crumbs, a chewed pencil, a bottle cap. Title scrawled at the top: THE BASEMENT. Wide 16:9, flat, even lighting, low contrast in the centre."),
 ("icon_brawl.png", "1024x1024", "transparent", "sheet", ICON + "a crossed wooden paddle and red plastic party cup."),
 ("icon_rival.png", "1024x1024", "transparent", "sheet", ICON + "a snarling green goblin head wearing a red letterman jacket collar, glowing red eyes."),
 ("icon_side_quest.png", "1024x1024", "transparent", "sheet", ICON + "a crumpled parchment scroll with a big black question mark."),
 ("icon_tailgate.png", "1024x1024", "transparent", "sheet", ICON + "a small camping tent beside a little grill and a campfire."),
 ("icon_baileys.png", "1024x1024", "transparent", "sheet", ICON + "a small burlap shop sack with a green cannabis leaf on it, a wisp of green smoke."),
 ("icon_loot.png", "1024x1024", "transparent", "sheet", ICON + "a closed white-and-blue picnic cooler with a sparkle."),
 ("icon_boss.png", "1024x1024", "transparent", "sheet", ICON + "a gold goblin king's crown with red gems over a pair of crossed bones."),
 ("icon_start.png", "1024x1024", "transparent", "sheet", ICON + "a wooden basement door at the bottom of stone stairs, warm light under it."),
 ("ui_card_frame.png", "1024x1536", "transparent", "sheet", "A blank trading-card frame for a deckbuilder game, portrait, front view, perfectly symmetrical: dark wood and bronze border with rivets, a blank name banner at the top, a large empty art window, a blank parchment text box in the lower half, a round empty cost gem socket in the top-left corner. All areas empty - no text, no art inside. Fully transparent background outside the card."),
 ("ui_button.png", "1536x1024", "transparent", "sheet", "A single wide game UI button, front view: a chunky wooden plank with bronze corner caps and rivets, slightly worn, blank face with no text, centered, on a fully transparent background."),
 ("ui_panel.png", "1024x1024", "transparent", "sheet", "A single square game UI panel for a 9-slice: dark wood frame with bronze corner brackets and rivets, a plain parchment interior that is flat and even so it can stretch, front view, centered, on a fully transparent background, nothing else."),
]

## Raw file -> (game file under PLACEHOLDER, max size (w, h) or None to keep, format). Used by --convert.
CONVERT = {}
for _spec in SPECS:
    _name = _spec[0]
    if _name.startswith("splash_"):
        CONVERT[_name] = (f"splashes/{_name[7:-4]}.webp", None, "webp")
    elif _name == "map_basement.png":
        CONVERT[_name] = ("map/basement.webp", None, "webp")
    elif _name.startswith("icon_"):
        CONVERT[_name] = (f"map/node_{_name[5:-4]}.png", (256, 256), "png")
    elif _name.startswith("ui_"):
        CONVERT[_name] = (f"ui/{_name[3:-4]}.png", {"ui_card_frame.png": (512, 768)}.get(_name, (512, 512)), "png")


def generate(raw_dir, spec):
    """Calls the API for one spec and writes the PNG. raw_dir: output folder. spec: one SPECS entry."""
    out, size, background, refs_key, body = spec
    path = os.path.join(raw_dir, out)  # where the PNG goes
    if os.path.exists(path):
        return f"{out}: already made"
    prompt = body + " " + STYLE  # the full prompt sent
    started = time.time()  # for the usage log only
    cmd = ["curl", "-sS", "https://api.openai.com/v1/images/edits", "-F", f"model={MODEL}",
           "-F", f"prompt={prompt}", "-F", f"size={size}", "-F", f"quality={QUALITY}",
           "-F", f"background={background}", "-F", "n=1"]  # the request; refs are added below
    for ref in REFS[refs_key]:
        mime = "image/webp" if ref.endswith(".webp") else "image/png"  # curl would send octet-stream
        cmd += ["-F", f"image[]=@{ref};type={mime}"]
    resp = json.loads(subprocess.run(cmd, capture_output=True, text=True, timeout=600).stdout)  # API reply
    if "error" in resp:
        return f"{out}: API error: {resp['error'].get('message')}"
    with open(path, "wb") as f:
        f.write(base64.b64decode(resp["data"][0]["b64_json"]))
    entry = {"out": out, "model": MODEL, "size": size, "quality": QUALITY, "usage": resp.get("usage"),
             "seconds": round(time.time() - started, 1)}  # one usage-log line
    with open(os.path.join(raw_dir, "usage.jsonl"), "a") as f:
        f.write(json.dumps(entry) + "\n")
    return f"{out}: done"


def convert(raw_dir):
    """Writes the game files from raw_dir's PNGs (CONVERT). raw_dir: the generate step's folder."""
    from PIL import Image
    for raw, (target, max_size, fmt) in CONVERT.items():
        src = os.path.join(raw_dir, raw)  # the raw PNG
        if not os.path.exists(src):
            print(f"{raw}: missing, skipped")
            continue
        dst = os.path.join(PLACEHOLDER, target)  # the game file
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if fmt == "webp":
            Image.open(src).convert("RGB").save(dst, quality=86, method=6)
        else:
            im = Image.open(src).convert("RGBA")  # transparent art, trimmed to its content
            im = im.crop(im.getbbox())
            im.thumbnail(max_size, Image.LANCZOS)
            im.save(dst, optimize=True)
        print(f"{raw} -> {dst}")


if __name__ == "__main__":
    if sys.argv[1:2] == ["--convert"]:
        convert(sys.argv[2])
    else:
        raw_dir, wanted = sys.argv[1], set(sys.argv[2:])  # output folder; names to make ("" = all)
        os.makedirs(raw_dir, exist_ok=True)
        todo = [s for s in SPECS if not wanted or s[0] in wanted]  # specs to run
        with ThreadPoolExecutor(WORKERS) as pool:
            for line in pool.map(lambda s: generate(raw_dir, s), todo):
                print(line, flush=True)
