"""Writes the placeholder stat, status, intent and pile icons (task 057) as small SVG files.

Lane: client (Agent B). Every shape here was drawn for this repository from plain circles, rectangles
and paths; nothing is copied from other art. Run from the repository root:

    python3 -I assets/placeholder/source/make_icons.py assets/placeholder/icons

It needs only the Python standard library. Each icon is a 64 x 64 viewBox with a dark outline so it
reads over the fight room. The client looks icons up by file name (client/visual/icons.gd ICONS), so a
replacement icon sheet only has to keep the same file names.
"""

import os
import sys

# OUTLINE: stroke colour drawn around every shape, so icons read on light and dark floors.
OUTLINE = "#14121a"
# OUTLINE_WIDTH: width of that stroke, in viewBox units (the viewBox is 64 wide).
OUTLINE_WIDTH = 3

# BONE_HALVES: the two halves of the broken bone, lying flat, each a shaft ending in a zigzag break
# with two knobs at its outer end. Drawn twice by "broken_bone": once as the outline, once as the fill.
BONE_HALVES = (
    '<path d="M8 27 H25 L29 30 L25 33 L29 37 H8 Z"/><circle cx="8" cy="26" r="6"/><circle cx="8" cy="38" r="6"/>'
    '<path d="M56 27 H39 L35 30 L39 33 L35 37 H56 Z"/><circle cx="56" cy="26" r="6"/><circle cx="56" cy="38" r="6"/>'
)

# ICONS: file name (without ".svg") -> the SVG elements inside the 64 x 64 viewBox.
ICONS = {
    # HP: a red heart.
    "heart": f'<path d="M32 57 L9 33 C1 24 6 10 18 10 C25 10 29 14 32 19 C35 14 39 10 46 10 C58 10 63 24 55 33 Z" fill="#e0443e"/>',
    # Guard and the defend intent: a blue kite shield.
    "shield": f'<path d="M32 5 L55 13 V30 C55 45 45 54 32 60 C19 54 9 45 9 30 V13 Z" fill="#4f93e6"/>'
    f'<path d="M32 12 L48 18 V30 C48 41 41 48 32 53 Z" fill="#8cc0ff" stroke="none"/>',
    # Swole: a flexed arm.
    "flex": f'<path d="M6 56 V40 C6 34 10 30 16 30 L26 30 C26 22 32 16 40 18 L44 8 C46 4 54 4 56 8 L58 14 C59 18 55 20 52 20 L50 30 C50 44 42 56 28 56 Z" fill="#f0a35e"/>'
    f'<path d="M28 34 C34 30 40 32 42 38" fill="none" stroke-width="2.5"/>',
    # Chill: a pale blue snowflake.
    "snowflake": f'<g stroke="#9fe0ff" stroke-width="6" stroke-linecap="round" fill="none">'
    f'<path d="M32 6 V58 M9 19 L55 45 M9 45 L55 19"/>'
    f'<path d="M24 10 L32 18 L40 10 M24 54 L32 46 L40 54"/></g>'
    f'<circle cx="32" cy="32" r="5" fill="#9fe0ff"/>',
    # Clout: a gold crown.
    "crown": f'<path d="M8 50 L11 18 L23 32 L32 12 L41 32 L53 18 L56 50 Z" fill="#f2c234"/>'
    f'<rect x="8" y="50" width="48" height="7" fill="#d9a514"/>',
    # Exposed: a red and white bullseye (takes more damage).
    "bullseye": f'<circle cx="32" cy="32" r="27" fill="#e0443e"/><circle cx="32" cy="32" r="18" fill="#f4f0e8"/>'
    f'<circle cx="32" cy="32" r="10" fill="#e0443e"/><circle cx="32" cy="32" r="3" fill="#f4f0e8"/>',
    # Noodle Arms: two limp yellow noodles.
    "noodle": f'<g fill="none" stroke-linecap="round">'
    f'<path d="M8 18 C18 8 22 30 32 20 C42 10 46 32 56 22" stroke="{OUTLINE}" stroke-width="11"/>'
    f'<path d="M8 18 C18 8 22 30 32 20 C42 10 46 32 56 22" stroke="#f3e08a" stroke-width="6"/>'
    f'<path d="M8 42 C18 32 22 54 32 44 C42 34 46 56 56 46" stroke="{OUTLINE}" stroke-width="11"/>'
    f'<path d="M8 42 C18 32 22 54 32 44 C42 34 46 56 56 46" stroke="#f3e08a" stroke-width="6"/></g>',
    # Hungover: a queasy green face with crossed-out eyes.
    "queasy": f'<circle cx="32" cy="32" r="26" fill="#b6cf6a"/>'
    f'<path d="M18 20 L28 30 M28 20 L18 30 M36 20 L46 30 M46 20 L36 30" stroke-width="3.5" stroke-linecap="round"/>'
    f'<path d="M18 46 C22 40 26 50 32 44 C38 38 42 50 46 44" fill="none" stroke-width="3.5" stroke-linecap="round"/>',
    # Foggy: a grey cloud.
    "cloud": f'<path d="M14 48 C5 48 4 36 12 34 C10 24 22 18 28 24 C32 12 50 14 50 28 C60 28 62 48 50 48 Z" fill="#b4bccb"/>',
    # Faded: a pale ghost.
    "ghost": f'<path d="M12 58 V28 C12 16 21 7 32 7 C43 7 52 16 52 28 V58 L45 51 L38 58 L32 51 L26 58 L19 51 Z" fill="#e7ebff"/>'
    f'<ellipse cx="25" cy="28" rx="4" ry="6" fill="{OUTLINE}"/><ellipse cx="39" cy="28" rx="4" ry="6" fill="{OUTLINE}"/>',
    # Broken Arm: a bone snapped in two (outline first, then the fill over it, so overlaps stay clean).
    "broken_bone": f'<g transform="rotate(-35 32 32)">'
    f'<g fill="{OUTLINE}" stroke-width="6">{BONE_HALVES}</g>'
    f'<g fill="#f2ead6" stroke="none">{BONE_HALVES}</g></g>',
    # Ick: green stink lines over a blob.
    "stink": f'<ellipse cx="32" cy="50" rx="22" ry="9" fill="#6fae3c"/>'
    f'<g fill="none" stroke-linecap="round">'
    f'<path d="M18 40 C12 32 24 28 18 20 C14 14 20 10 20 6" stroke="{OUTLINE}" stroke-width="9"/>'
    f'<path d="M18 40 C12 32 24 28 18 20 C14 14 20 10 20 6" stroke="#9de05a" stroke-width="5"/>'
    f'<path d="M32 40 C26 32 38 28 32 20 C28 14 34 10 34 6" stroke="{OUTLINE}" stroke-width="9"/>'
    f'<path d="M32 40 C26 32 38 28 32 20 C28 14 34 10 34 6" stroke="#9de05a" stroke-width="5"/>'
    f'<path d="M46 40 C40 32 52 28 46 20 C42 14 48 10 48 6" stroke="{OUTLINE}" stroke-width="9"/>'
    f'<path d="M46 40 C40 32 52 28 46 20 C42 14 48 10 48 6" stroke="#9de05a" stroke-width="5"/></g>',
    # The attack intent: a sword, point up and to the right.
    "sword": f'<g transform="rotate(45 32 32)">'
    f'<path d="M28 42 V10 L32 2 L36 10 V42 Z" fill="#dfe3ea"/>'
    f'<rect x="18" y="41" width="28" height="6" rx="2" fill="#c99a27"/>'
    f'<rect x="29" y="47" width="6" height="11" fill="#7a4a24"/>'
    f'<circle cx="32" cy="60" r="3.5" fill="#c99a27"/></g>',
    # The buff intent: a green arrow pointing up.
    "arrow_up": f'<path d="M32 4 L58 32 H42 V60 H22 V32 H6 Z" fill="#5fcf5f"/>',
    # The debuff intent: a purple arrow pointing down.
    "arrow_down": f'<path d="M32 60 L58 32 H42 V4 H22 V32 H6 Z" fill="#b072e6"/>',
    # The summon intent: a plus in a circle.
    "summon": f'<circle cx="32" cy="32" r="27" fill="#6a63b8"/>'
    f'<path d="M27 14 H37 V27 H50 V37 H37 V50 H27 V37 H14 V27 H27 Z" fill="#f4f0e8"/>',
    # The charge intent: a gold hourglass.
    "hourglass": f'<rect x="12" y="4" width="40" height="7" rx="2" fill="#8a5a2a"/><rect x="12" y="53" width="40" height="7" rx="2" fill="#8a5a2a"/>'
    f'<path d="M16 11 H48 C48 24 38 28 36 32 C38 36 48 40 48 53 H16 C16 40 26 36 28 32 C26 28 16 24 16 11 Z" fill="#f4e6b0"/>'
    f'<path d="M22 50 C24 42 30 40 32 36 C34 40 40 42 42 50 Z" fill="#f2c234" stroke="none"/>',
    # The flee intent: an arrow leaving through a doorway.
    "flee": f'<rect x="6" y="6" width="26" height="52" fill="#5a4030"/>'
    f'<path d="M24 26 H44 V16 L60 32 L44 48 V38 H24 Z" fill="#f2c234"/>',
    # An unknown intent: a question mark.
    "question": f'<circle cx="32" cy="32" r="27" fill="#5b5f6b"/>'
    f'<path d="M23 24 C23 14 41 14 41 23 C41 30 32 30 32 38 V40" fill="none" stroke="#f4f0e8" stroke-width="6" stroke-linecap="round"/>'
    f'<circle cx="32" cy="49" r="4" fill="#f4f0e8" stroke="none"/>',
    # A skipped action (Grossed Out, fallen, Armless): Zzz.
    "zzz": f'<g fill="none" stroke-linejoin="round" stroke-linecap="round">'
    f'<path d="M6 28 H26 L6 54 H26" stroke="{OUTLINE}" stroke-width="10"/>'
    f'<path d="M6 28 H26 L6 54 H26" stroke="#a7c4ff" stroke-width="5"/>'
    f'<path d="M32 16 H46 L32 34 H46" stroke="{OUTLINE}" stroke-width="9"/>'
    f'<path d="M32 16 H46 L32 34 H46" stroke="#a7c4ff" stroke-width="4"/>'
    f'<path d="M50 6 H59 L50 18 H59" stroke="{OUTLINE}" stroke-width="8"/>'
    f'<path d="M50 6 H59 L50 18 H59" stroke="#a7c4ff" stroke-width="3"/></g>',
    # Hype: an orange orb with a faint lightning bolt, plain in the middle so a number reads on it.
    "hype_orb": f'<circle cx="32" cy="32" r="28" fill="#d8641a"/><circle cx="32" cy="32" r="22" fill="#ef8a2e" stroke="none"/>'
    f'<path d="M38 6 L20 34 H31 L27 58 L46 28 H35 Z" fill="#ffd27a" stroke="none" opacity="0.45"/>'
    f'<ellipse cx="24" cy="20" rx="8" ry="5" fill="#ffe2b0" stroke="none" opacity="0.7"/>',
    # The draw pile: a stack of blue card backs.
    "draw_pile": f'<rect x="18" y="4" width="34" height="46" rx="4" fill="#2f5a96"/>'
    f'<rect x="14" y="9" width="34" height="46" rx="4" fill="#3a6db3"/>'
    f'<rect x="10" y="14" width="34" height="46" rx="4" fill="#4c83cf"/>'
    f'<path d="M27 26 L35 37 L27 48 L19 37 Z" fill="#cfe0ff" stroke="none"/>',
    # The discard pile: red card faces, fanned.
    "discard_pile": f'<rect x="20" y="8" width="32" height="44" rx="4" fill="#8c3a3a" transform="rotate(14 36 30)"/>'
    f'<rect x="12" y="12" width="32" height="44" rx="4" fill="#b84a4a"/>'
    f'<path d="M20 26 H36 M20 34 H36 M20 42 H30" stroke="#f4e0d8" stroke-width="3" stroke-linecap="round"/>',
    # The Tapped pile: a grey card crossed out.
    "tapped_pile": f'<rect x="14" y="8" width="36" height="48" rx="4" fill="#6b6b72"/>'
    f'<path d="M20 16 L44 48 M44 16 L20 48" stroke="#ff6a5a" stroke-width="6" stroke-linecap="round"/>',
    # The Bro Meter: two fists bumping, with a spark where they meet.
    "fist_bump": f'<rect x="2" y="22" width="12" height="16" rx="3" fill="#c97f3e"/>'
    f'<rect x="12" y="18" width="19" height="26" rx="7" fill="#f0a35e"/>'
    f'<path d="M31 25 H24 M31 31 H24 M31 37 H24" stroke-width="2.5" stroke-linecap="round"/>'
    f'<rect x="50" y="22" width="12" height="16" rx="3" fill="#a8652e"/>'
    f'<rect x="33" y="18" width="19" height="26" rx="7" fill="#d98a48"/>'
    f'<path d="M33 25 H40 M33 31 H40 M33 37 H40" stroke-width="2.5" stroke-linecap="round"/>'
    f'<path d="M32 13 V5 M25 14 L21 8 M39 14 L43 8 M32 49 V57" fill="none" stroke="#f2c234" stroke-width="3.5" stroke-linecap="round"/>',
    # The marker over an attack intent that names the targeted Dude: a white chevron, tinted per
    # Dude by the client.
    "aim": f'<path d="M8 12 L32 54 L56 12 L32 26 Z" fill="#ffffff"/>',
}


def svg(body: str) -> str:
    """Returns a full SVG document around one icon's elements.

    body: the elements, drawn with the shared outline unless they set their own stroke.
    """
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n'
        f'<g stroke="{OUTLINE}" stroke-width="{OUTLINE_WIDTH}" stroke-linejoin="round">{body}</g>\n'
        "</svg>\n"
    )


def main() -> None:
    """Writes every icon in ICONS to <out_dir>/<name>.svg. out_dir: the first argument."""
    if len(sys.argv) != 2:
        sys.exit("usage: make_icons.py <out_dir>")
    # out_dir: the folder the SVG files are written to.
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    for name, body in sorted(ICONS.items()):
        with open(os.path.join(out_dir, name + ".svg"), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(svg(body))
    print("wrote %d icons to %s" % (len(ICONS), out_dir))


if __name__ == "__main__":
    main()
