# Proposal: Tom's 16 new slice cards, and an upgrade for every Tom card

- Author: Agent B, task 012
- Status: **waiting for answers** (Smoketsu and steamjgrube)
- GDD version read: 0.5

## Why

G14's answer (both people, 2026-10-10): the slice's 30 cards are Tom's 14 GDD cards plus **16 new
Tom cards**, proposed here first. G15's answer: upgrade values for every Tom card are proposed here
too, so Lift works on the whole deck. Agents may not invent cards, so nothing here is data until you
answer. Under each card and each upgrade group, write "accept", a change, or "cut".

**Every number below is an untested starting value.** None of it argues balance as settled.

Design goals:
- **Fill the three build directions** the GDD names: Orthopedic Surgeon (Broken Arm), Repellent (Ick)
  and Head First (self-damage). Head First has only Skull Bash and Pickup Line today.
- **Use the ops that exist** (`core/ops/README.md`). 13 of the 16 cards need nothing new. Three need
  something from Agent A, listed in "Ops this needs from Agent A".
- **Tone:** Ick is repellence that works on every enemy alike: unwanted opinions, bad lines, long
  replies. Tom thinks it's charisma. Nothing here is aimed at anyone but Tom, monsters or institutions.

## The full Tom pool after this proposal

Chest Bump (the Bro Move) and Junk are not counted (G14).

| Rarity | GDD cards | New | Total |
| --- | --- | --- | --- |
| Starter | 4 | 0 | 4 |
| Common | 4 | 6 | 10 |
| Uncommon | 4 | 6 | 10 |
| Rare | 2 | 4 | 6 |
| **All** | **14** | **16** | **30** |

| Type | GDD cards | New | Total |
| --- | --- | --- | --- |
| Attack | 6 | 7 | 13 |
| Skill | 6 | 7 | 13 |
| Power | 2 | 2 | 4 |

| Build | GDD cards | New |
| --- | --- | --- |
| Orthopedic Surgeon | Arm Bar, Wrist Lock, Cast Party, Snap City, Double Arm Day | Headlock, Dislocate, Compound Fracture, Full Nelson, Main Character Energy |
| Repellent | Well, Actually, Unsolicited Advice, Pickup Line, Reply Guy, Friend Zone | Noogie, Hot Take, Stare Down, Story Time, Three-Hour Podcast |
| Head First | Skull Bash, Pickup Line | Noggin Knock, Headbutt, Tough Skull, Nothing to Lose |
| General | Punch, Flex, Chrome Dome | Bro Hug, Gym Selfie |

**Assist cards:** 1 of 30 (Bro Hug), against the GDD's "about 1 card in 6" (about 5). That's
fine for a solo slice, but co-op will need more. See question Q2.

## New cards

Effects are written as data, in the format of `core/ops/README.md`. "Joke" says who it lands on.

### Common

#### `tom_noogie`: Noogie
- Attack · cost 0 · common · target `enemy` · Repellent
- Text: "Deal 4 damage. Apply 1 Ick"
- Effects: `damage` 4; `apply_status` `ick` 1
- Joke: Tom, who thinks a noogie is a love language.

Answer:

#### `tom_headlock`: Headlock
- Attack · cost 1 · common · target `enemy` · Orthopedic Surgeon
- Text: "Deal 7 damage. If the target has a Broken Arm, apply 1 Noodle Arms"
- Effects: `damage` 7; `{"op": "apply_status", "status": "noodle_arms", "stacks": 1, "if": "target_has_broken_arm"}`
- Joke: the monster, held at an angle no chiropractor approves of.

Answer:

#### `tom_hot_take`: Hot Take
- Skill · cost 1 · common · target `enemy` · Repellent
- Text: "Apply 3 Ick. Draw 1 card"
- Effects: `apply_status` `ick` 3; `draw` 1
- Joke: Tom, sharing an opinion nobody in the dungeon asked for.

Answer:

#### `tom_stare_down`: Stare Down
- Skill · cost 1 · common · target `enemy` · Repellent
- Text: "Gain 5 Guard. Apply 2 Ick"
- Effects: `guard` 5 (always lands on Tom); `apply_status` `ick` 2
- Joke: Tom, who blinks less than is comfortable.

Answer:

#### `tom_noggin_knock`: Noggin Knock
- Attack · cost 1 · common · target `enemy` · Head First
- Text: "Deal 5 damage twice. Tom takes 2 damage"
- Effects: `{"op": "damage", "amount": 5, "hits": 2}`; `self_damage` 2
- Joke: Tom's bald head, which is load-bearing.

Answer:

#### `tom_bro_hug`: Bro Hug
- Skill, Assist · cost 1 · common · target `ally` · keywords `assist` · General
- Text: "Target Dude gains 7 Guard"
- Effects: `guard` 7. **Needs Agent A:** `guard` lands on the actor, and `ally` targets are not built
  (see "Ops this needs from Agent A", item 1).
- Joke: Tom, whose hugs last two beats too long.

Answer:

### Uncommon

#### `tom_dislocate`: Dislocate
- Skill · cost 1 · uncommon · target `enemy` · Orthopedic Surgeon
- Text: "Break 1 arm. Apply 2 Exposed"
- Effects: `apply_status` `broken_arm` 1; `apply_status` `exposed` 2
- Joke: the monster, now holding its own elbow.

Answer:

#### `tom_compound_fracture`: Compound Fracture
- Attack · cost 2 · uncommon · target `enemy` · Orthopedic Surgeon
- Text: "Deal 6 damage. If the target has a Broken Arm, deal 6 more. If it is Armless, deal 6 more"
- Effects: `damage` 6; `{"op": "damage", "amount": 6, "if": "target_has_broken_arm"}`;
  `{"op": "damage", "amount": 6, "if": "target_now_armless"}`
- Joke: the monster, whose healthcare plan does not cover this.

Answer:

#### `tom_story_time`: Story Time
- Skill · cost 2 · uncommon · target `enemy` · Repellent
- Text: "Apply 7 Ick"
- Effects: `apply_status` `ick` 7
- Joke: Tom, forty minutes into a story about his own protein intake.

Answer:

#### `tom_gym_selfie`: Gym Selfie
- Skill · cost 1 · uncommon · target `self` · keywords `tapped` · General
- Text: "Gain 2 Swole for this fight. Apply 1 Ick to all enemies. Tapped"
- Effects: `{"op": "gain_stat", "stat": "swole", "amount": 2, "duration": "fight"}`;
  `{"op": "apply_status", "status": "ick", "stacks": 1, "target": "all_enemies"}`
- Joke: Tom, posing mid-fight.

Answer:

#### `tom_headbutt`: Headbutt
- Attack · cost 2 · uncommon · target `enemy` · Head First
- Text: "Deal 18 damage. Tom takes 4 damage"
- Effects: `damage` 18; `self_damage` 4
- Joke: Tom, solving a problem the only way he knows.

Answer:

#### `tom_tough_skull`: Tough Skull
- Power · cost 1 · uncommon · target `none` · Head First
- Text: "Whenever Tom takes damage from his own card, gain 3 Guard"
- Effects: `[]`; `power_triggers: [{"when": "self_damaged", "target": "self", "effects": [guard 3]}]`.
  **Needs Agent A:** a new trigger, `self_damaged` (item 2).
- Joke: Tom, who has learned nothing.

Answer:

### Rare

#### `tom_full_nelson`: Full Nelson
- Attack · cost 3 · rare · target `enemy` · Orthopedic Surgeon
- Text: "Deal 10 damage. Break 2 arms"
- Effects: `damage` 10; `apply_status` `broken_arm` 2 (capped at the enemy's `arm_count`, so it
  leaves most floor 1 enemies Armless)
- Joke: the monster, folded like a lawn chair.

Answer:

#### `tom_three_hour_podcast`: Three-Hour Podcast
- Skill · cost 2 · rare · target `enemy` · keywords `tapped` · Repellent
- Text: "Apply 12 Ick. Tapped"
- Effects: `apply_status` `ick` 12 (in solo, enough to Gross Out any floor 1 enemy, Chad included,
  at its starting threshold; co-op thresholds scale up)
- Joke: Tom's podcast, whose one listener is a smart speaker he forgot to turn off.

Answer:

#### `tom_nothing_to_lose`: Nothing to Lose
- Attack · cost 2 · rare · target `enemy` · keywords `tapped` · Head First
- Text: "Deal damage equal to the HP Tom is missing, up to 30. Tapped"
- Effects: **needs Agent A:** a new op, `damage_from_missing_hp` (item 3).
- Joke: Tom, who confuses being hurt with being right.

Answer:

#### `tom_main_character_energy`: Main Character Energy
- Power · cost 2 · rare · target `none` · Orthopedic Surgeon and Repellent
- Text: "Whenever an enemy is Grossed Out, break 1 of its arms"
- Effects: `[]`; `power_triggers: [{"when": "enemy_grossed_out", "target": "subject", "effects": [apply_status broken_arm 1]}]`
- Joke: Tom, narrating his own victory to people who are trying to leave.

Answer:

## Upgrades

Written as `upgrade` field paths, in the style of the GDD's example card. Arm Bar is exactly the
GDD's: 8 to 11 damage. Pattern: about +3 damage, +3 Guard, +1 to +2 Ick, or −1 cost.

### GDD cards

| Card | `upgrade` | Reads |
| --- | --- | --- |
| Punch | `{"effects[0].amount": 9}` | 6 → 9 damage |
| Flex | `{"effects[0].amount": 8}` | 5 → 8 Guard |
| Arm Bar | `{"effects[0].amount": 11}` | 8 → 11 damage (GDD) |
| Well, Actually | `{"effects[0].stacks": 3}` | 2 → 3 Ick |
| Wrist Lock | `{"effects[0].amount": 8}` | 5 → 8 damage |
| Chrome Dome | `{"effects[0].amount": 10}` | 7 → 10 Guard |
| Skull Bash | `{"effects[0].amount": 14}` | 10 → 14 damage |
| Unsolicited Advice | `{"effects[0].stacks": 5}` | 3 → 5 Ick |
| Cast Party | `{"effects[0].amount": 6}` | 4 → 6 Guard per Broken Arm |
| Snap City | `{"effects[0].amount": 18}` | 14 → 18 damage |
| Pickup Line | `{"effects[0].stacks": 6}` | 4 → 6 Ick to all |
| Reply Guy | `{"power_triggers[0].effects[0].stacks": 3}` | 2 → 3 Ick |
| Double Arm Day | `{"effects[0].amount": 12, "effects[2].amount": 12}` | 9 → 12 per hit |
| Friend Zone | `{"cost": 1}` | cost 2 → 1 |

Answer:

### New cards

| Card | `upgrade` | Reads |
| --- | --- | --- |
| Noogie | `{"effects[0].amount": 6, "effects[1].stacks": 2}` | 4 → 6 damage, 1 → 2 Ick |
| Headlock | `{"effects[0].amount": 10}` | 7 → 10 damage |
| Hot Take | `{"effects[0].stacks": 5}` | 3 → 5 Ick |
| Stare Down | `{"effects[0].amount": 8}` | 5 → 8 Guard |
| Noggin Knock | `{"effects[0].amount": 7}` | 5 → 7 per hit |
| Bro Hug | `{"effects[0].amount": 10}` | 7 → 10 Guard |
| Dislocate | `{"cost": 0}` | cost 1 → 0 |
| Compound Fracture | `{"effects[0].amount": 9}` | first hit 6 → 9 |
| Story Time | `{"effects[0].stacks": 10}` | 7 → 10 Ick |
| Gym Selfie | `{"effects[0].amount": 3}` | 2 → 3 Swole |
| Headbutt | `{"effects[0].amount": 23}` | 18 → 23 damage |
| Tough Skull | `{"power_triggers[0].effects[0].amount": 5}` | 3 → 5 Guard |
| Full Nelson | `{"effects[0].amount": 15}` | 10 → 15 damage |
| Three-Hour Podcast | `{"cost": 1}` | cost 2 → 1 |
| Nothing to Lose | `{"cost": 1}` | cost 2 → 1 |
| Main Character Energy | `{"cost": 1}` | cost 2 → 1 |

Answer:

## Ops this needs from Agent A

Each becomes a core task request (odd id) only if the card is accepted.

1. **`ally` targets** (Bro Hug, and every later Assist card). `core/ops/README.md` lists `ally` as
   not built (`bad_target`). Wanted: a card with `target: "ally"` lands on the picked Dude, and in solo
   on the player's own Dude (GDD "Card types and keywords": Assist). `guard` should then land on
   the card's targets for `ally` cards rather than on the actor, or a new field `"on": "targets"`.
2. **Power trigger `when: "self_damaged"`** (Tough Skull): fires each time the Power's Dude takes
   damage from their own card's `self_damage` (not from enemies, Burn or Bedbugs). `target: "self"`.
3. **Op `damage_from_missing_hp`** (Nothing to Lose): fields `cap` (int ≥ 0). Attack damage equal
   to `min(max_hp − hp, cap)` of the actor, then the damage order as usual. The cap 30 would be data
   on the card, not a constant.

## Questions

- **Q1. Chest Bump's upgrade.** G15 doesn't cover the Bro Move, and it is never Lifted at a Tailgate
  because it's not in the deck. Suggested: no upgrade.

  Answer:

- **Q2. Assist cards.** 1 of 30 (Bro Hug). Suggested: fine for the solo slice; revisit with co-op.

  Answer:
