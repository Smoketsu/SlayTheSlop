# Proposal: rename the drink-named Brews so Baileys sells only Shake

- Author: Agent B (content lane), branch `b/shake-brew-names`
- Status: **decided** by Person B (steamjgrube), 2026-10-10. Built in `data/brews/`.
- GDD version read: 0.5
- Asks: the GDD owner to update the GDD "Brews" table (GDD v0.5, "Items" > "Brews", lines ~597–604).
  Agents do not edit `docs/GDD.md`.

## What changes

Five Brews get new display names. Only the `"name"` field changes. Ids, rarity, rules text,
target and effects are identical.

| Id (unchanged) | Old name (GDD v0.5) | New name |
| --- | --- | --- |
| `light_beer` | Light Beer | Chill Nug |
| `energy_drink` | Energy Drink | Wake and Bake |
| `protein_shake` | Protein Shake | Gym Gummy |
| `shot_of_courage` | Shot of Courage | Hotbox |
| `hair_of_the_dog` | Hair of the Dog | Morning Dab |

Party Bowl, Special Brownie and Smelling Salts keep their names.

## Why

- CLAUDE.md, "Writing and content rules": **Baileys sells weed, not drinks.** At Baileys every
  Brew is shown as Shake, and anything said or sold there is weed or Shake. The GDD's "Prices at
  Baileys" says the same. G29 settled that Baileys shows each Brew's own name and effect under the
  "Shake" label, so a Brew named for a drink (for example "Light Beer" or "Energy Drink") put
  drinks on Baileys' shelf.
- G29 also flagged that the Brew "Protein Shake" would sit under a "Shake" label, and suggested
  the people might rename one of them. "Gym Gummy" ends that confusion.

## What does not change

- **Ids stay** (`light_beer`, `energy_drink`, `protein_shake`, `shot_of_courage`,
  `hair_of_the_dog`). Saves refer to ids, and CLAUDE.md says an id never changes once merged.
  A display name may change freely (`core/schema/brew_def.gd`: "May change freely").
- No rule, number, effect op or constant changes. The core never reads a Brew's name.

## Notes for Agent A

Agent A's fixtures (`tests/core/items/item_fixtures.gd`) and some core code comments (for example
`core/ops/heal.gd`, `core/ops/gain_stat.gd`, `core/schema/brew_def.gd`) still use the old GDD
names. Agent A may update them at their convenience; it is not required. Agent B's
`tests/data/test_item_data.gd` now compares each Brew file with its fixture on everything except
`name`, and pins the new names in its own test.
