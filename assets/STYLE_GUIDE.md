# Art style guide

How every piece of art in Dungeon Dudes should look, how big it is, what it is called, and how to make
more that matches. Written for task 063 (2026-10-13, Agent A, from Smoketsu's request for "a sprite
guide in general, so that we can have assets moving forward, even small animations").

Everything here describes **placeholder** art. When real art arrives it replaces files under the same
names, and this guide is updated with it. Items marked **(proposed)** are this guide's own defaults,
not decisions anyone has confirmed.

## The look

The reference set is Smoketsu's character sheet (`placeholder/source/character_sheet.webp`) and the
three room backgrounds (`placeholder/backgrounds/`). New art should look like it came from the same
sheet.

- **Outline:** bold, dark brown-black ink outline on every character and prop, thicker on the
  silhouette than inside it.
- **Shading:** cel shading, two or three flat tones per material, with a soft highlight. No painterly
  gradients and no photo textures.
- **Proportions:** chunky and exaggerated. Big hands, big boots, big heads on small monsters. Tom is
  mostly shoulders.
- **Mood:** grimy, comedic, warm. Rooms are lit by candles and string lights, so warm orange light sits
  against dark stone.
- **Palette** (sampled from the reference art, for guidance, not a hard limit):

  | Use | Colours |
  | --- | --- |
  | Room darks (stone, shadow) | `#110d0b` `#1c1817` `#261d1a` `#362b25` |
  | Wood and leather | `#3e2f26` `#4f3828` `#6e4727` `#73463a` |
  | Candlelight | `#af6f2e`, brightening to warm yellow at the flame |
  | Parchment and bone | `#b29f78` |
  | Character sheet background (not part of any sprite) | `#595a63` |
  | Accents | Tom's red tunic, goblin green, party-cup red, Baileys leaf green |

## Sizes

| Art | Canvas | Notes |
| --- | --- | --- |
| Character sprite | Trimmed to the character with a 4 px margin, about 180–275 px per side | Transparent PNG, three-quarter view as on the sheet, standing on the bottom edge |
| Fight background | 1672 × 941 (about 16:9) | WebP. Its **floor line** is where the characters' feet go, as a fraction of the height from the top: 0.60 in all three rooms (`client/visual/backgrounds.gd` `FLOOR_LINES`). Measure it on any new room and add it there |
| Splash | 1536 × 1024 | WebP. Shown filling a 16:9 screen (cropped a little top and bottom). **Safe area:** the top half (`client/visual/splashes.gd` `SAFE_TOP` 0.5) stays clear of UI. Put the subject and the joke there, roughly centred. The bottom half sits under the dark choice panel, so keep it calm |
| Map backdrop | 1536 × 1024 | WebP. Keep the middle low-contrast so nodes and trails read on top of it |
| Map node icon | 256 × 256 | Transparent PNG, one round bronze medallion. Must read at 48 px |
| Stat and intent icon | 64 × 64 SVG | Drawn by `placeholder/source/make_icons.py` (task 057) |
| UI pieces (card frame, button, panel) | Card frame 512 × 768, others up to 512 px | Transparent PNG, blank: no text baked in |

## Poses and expressions

- **Tom:** arms folded or flexing, smug grin, total confidence in a bad idea. He is never cruel and never
  scary, just loud. His Ick is repellence that works on everyone alike. Never draw it as hostility toward
  women. He thinks it is charisma.
- **Cheney, Grube, Nate, Ethan:** not drawn yet. Add each one's sheet entry here when their art arrives,
  using only what the GDD says about them. No likenesses or personal details of the real people.
- **Enemies:** each shows the habit it punishes (the Bouncer checks ID, the Intern carries paperwork).
  Expressions are smug, bored or hungover, rarely menacing.

## Naming

- Files are named by **content id**, the same id the data uses: `characters/<id>.png`,
  `backgrounds/<boss id>.webp`, `splashes/<side quest id>.webp`. The client looks art up by id with a
  visible fallback, so a missing picture never crashes.
- Ids are `snake_case` and never change once merged (CLAUDE.md "Naming and identifiers").
- Non-content art (offer kinds, map nodes, UI) is named by the kind the client uses: `splashes/tailgate.webp`,
  `map/node_<node type>.png`, `ui/<piece>.png`.

## Animation conventions (proposed)

Nothing is animated frame by frame yet: the fight screen moves whole sprites (task 028). When a
character gets frames, use these defaults so every sheet loads the same way:

| Animation | Frames | Frames per second | Loops |
| --- | --- | --- | --- |
| `idle` | 4 | 6 | yes |
| `attack` | 6 | 12 | no |
| `hit` | 3 | 12 | no |
| `passed_out` | 6 | 8 | no (holds the last frame) |

- **Packing:** one horizontal strip per animation, equal square cells, transparent background, feet on the
  same baseline in every frame, named `characters/<id>_<animation>.png`.
- **Cell size:** the character's sprite size rounded up to a multiple of 16.
- SpriteCook (a connected art tool) can animate a still and export a Godot SpriteFrames package. Its
  output must still follow this table.

## Prompt template

The art so far came from ChatGPT image generation (Smoketsu's sheet, 2026-10-10) and from the OpenAI
image API (Agent A, 2026-10-13). To make more in the same style, pass the character sheet, plus the
Basement background for scenes, as **reference images**, and end the prompt with this style line:

> Art style: match the reference images exactly - bold dark ink outlines, cel-shaded comic fantasy game
> art, warm candlelit palette, chunky exaggerated proportions, slightly grimy and comedic. The bald,
> heavily muscled man in a red sleeveless tunic, brown leather belt and boots from the character sheet
> is Tom; keep his look identical. No real-world brand names or logos. No watermark, no UI, no captions.

Lead the prompt with what is being made and its framing:

- **Splash:** "Wide 16:9 composition, the subject readable at a glance, keep the bottom quarter calm and
  uncluttered for UI text. Side Quest splash '<name>': <the scene and the joke>."
- **Map node icon:** "A single round medallion badge icon, bronze rim with rivets, dark slate inner disc,
  centered, filling most of the canvas, on a fully transparent background with nothing else around it.
  It must read clearly at 48 pixels. No text. The badge shows: <subject>."

Every prompt used so far is in `placeholder/source/generate_art.py` (`SPECS`). That script regenerates
any of them and converts the results into the game files. It is the place to add new art.

## Sources and rules

- Record every new file in `placeholder/README.md`: who made it, when, with what tool or model, and on
  what terms. Art from outside the project needs a licence that clearly allows our use.
- CLAUDE.md "Writing and content rules" apply to pictures too. The joke lands on a Dude, a monster or an
  institution, never on a real-world group. No real brands, logos, artists or licensed characters. No
  likenesses of the real people the Dudes, Dylan or Baileys are named after.
- **Baileys sells weed, not drinks.** Everything for sale at Baileys reads as weed or Shake. No beer,
  bottles, cans or drink branding in Baileys art.
- Generated text in a picture (signs, stickers) is part of the joke, so check it is spelled right and
  follows the rules above before committing.
