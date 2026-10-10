# Proposal: 16 more Tom cards for the solo slice

Status: **draft, waiting on Smoketsu and steamjgrube.** Nothing here is in the GDD until you both accept it.
Author: Agent B, at steamjgrube's request.

## Why

GDD milestone 2 asks for "Tom, floor 1, 30 cards". The GDD designs 14 Tom cards: the 4 starters and 10 samples.
Agents may not invent cards on their own, so the other 16 are drafted here for review.

This draft reads "30 cards" as **30 distinct cards in Tom's pool, starters included**. If you meant
something else, such as 30 cards plus neutral cards or a 30-card reward pool without the starters,
say so and the count changes.

## Shape of the pool

| Rarity | In the GDD | Proposed here | Total |
| --- | --- | --- | --- |
| Starter | 4 | 0 | 4 |
| Common | 4 | 6 | 10 |
| Uncommon | 4 | 6 | 10 |
| Rare | 2 | 4 | 6 |
| **All** | **14** | **16** | **30** |

The new cards fill gaps in the three build directions the GDD names for Tom:

| Build | GDD cards today | Added here |
| --- | --- | --- |
| Orthopedic Surgeon (Broken Arm) | Arm Bar, Wrist Lock, Cast Party, Snap City, Double Arm Day | Headlock, Dislocate, Compound Fracture, Full Nelson |
| Repellent (Ick) | Well, Actually, Unsolicited Advice, Pickup Line, Reply Guy, Friend Zone | Noogie, Hot Take, Stare Down, Story Time, Three-Hour Podcast |
| Head First (self-damage) | Skull Bash, Pickup Line | Noggin Knock, Headbutt, Tough Skull, Nothing to Lose |
| Both mechanics, or general | Chrome Dome | Bro Hug, Gym Selfie, Main Character Energy |

Head First is the biggest gap. The GDD promises "HP-based payoffs", but no card has one yet.

## The cards

All numbers are untested starting values, like every number in the GDD.

### Common

| Id | Card | Type | Cost | Effect |
| --- | --- | --- | --- | --- |
| `tom_noogie` | Noogie | Attack | 0 | Deal 4 damage. Apply 1 Ick |
| `tom_headlock` | Headlock | Attack | 1 | Deal 7 damage. If the target has a Broken Arm, apply 1 Noodle Arms |
| `tom_hot_take` | Hot Take | Skill | 1 | Apply 3 Ick. Draw 1 card |
| `tom_stare_down` | Stare Down | Skill | 1 | Gain 5 Guard. Apply 2 Ick |
| `tom_noggin_knock` | Noggin Knock | Attack | 1 | Deal 5 damage twice. Tom takes 2 damage |
| `tom_bro_hug` | Bro Hug | Skill, Assist | 1 | Target Dude gains 7 Guard |

### Uncommon

| Id | Card | Type | Cost | Effect |
| --- | --- | --- | --- | --- |
| `tom_dislocate` | Dislocate | Attack | 1 | Break 1 arm. Apply 2 Exposed |
| `tom_compound_fracture` | Compound Fracture | Attack | 2 | Deal 6 damage, plus 6 for each Broken Arm on the target |
| `tom_story_time` | Story Time | Skill | 2 | Apply 7 Ick |
| `tom_gym_selfie` | Gym Selfie | Skill | 1 | Gain 2 Swole for this fight. Apply 1 Ick to all enemies. Tapped |
| `tom_headbutt` | Headbutt | Attack | 2 | Deal 18 damage. Tom takes 4 damage |
| `tom_tough_skull` | Tough Skull | Power | 1 | Whenever one of Tom's own cards damages him, gain 3 Guard |

### Rare

| Id | Card | Type | Cost | Effect |
| --- | --- | --- | --- | --- |
| `tom_full_nelson` | Full Nelson | Attack | 3 | Deal 10 damage. Break every arm the target has left |
| `tom_three_hour_podcast` | Three-Hour Podcast | Skill | 2 | Apply Ick until the target reaches its Ick threshold. Tapped |
| `tom_nothing_to_lose` | Nothing to Lose | Attack | 2 | Deal damage equal to Tom's missing HP, up to 30. Tapped |
| `tom_main_character_energy` | Main Character Energy | Power | 2 | Whenever Tom breaks an arm, apply 2 Ick to that enemy |

### Tone check

- Every Ick card is Tom being tiresome: hot takes, staring, long stories, a podcast nobody wanted.
  It works on every enemy alike and is never aimed at women, as the writing rules require.
- The jokes land on Tom. No real brands, people or groups are named.

## What Agent A would need to build

Most cards reuse rules the GDD's own cards already need. Some need something new in `core`.
Content can't add rules on its own, so each item below becomes a `core` task request if you accept the card.

| Card | Needs | New? |
| --- | --- | --- |
| Noogie, Hot Take, Stare Down, Story Time, Dislocate, Bro Hug | `damage`, `guard`, `apply_status`, `draw` | No |
| Headlock | A condition "target has a Broken Arm" | No, Wrist Lock needs it too |
| Noggin Knock, Headbutt | Self-damage | No, Skull Bash needs it too |
| Gym Selfie | Swole for the rest of the fight | No, Protein Shake needs it too |
| Compound Fracture | Damage that scales with the target's Broken Arm count | **Yes** |
| Tough Skull | A Power that triggers when Tom's own card damages him | **Yes**, a new trigger shaped like Reply Guy's |
| Main Character Energy | A Power that triggers when Tom breaks an arm | **Yes**, a new trigger shaped like Reply Guy's |
| Full Nelson | Break all remaining arms in one effect | **Yes** |
| Three-Hour Podcast | Apply Ick equal to threshold minus current Ick | **Yes** |
| Nothing to Lose | Damage equal to `max_hp − hp`, capped | **Yes** |

The cap of 30 on Nothing to Lose would be a new tuning constant in `data/constants.json`,
for example `NOTHING_TO_LOSE_CAP`, not a number in code.

## Decisions for you

1. Accept, change or cut each card. Suggested-change blocks on this file's lines work well for that.
2. Confirm that "30 cards" means 30 distinct cards in Tom's pool, starters included.
3. **Upgrades are not designed.** The Tailgate's Lift is in the solo slice, but the GDD gives an
   upgrade only for Arm Bar (8 → 11 damage). All 30 cards need upgrade values. That should be a
   separate proposal once this list is settled. Should Agent B draft it?
4. **Assist cards:** the GDD aims for about 1 card in 6 being Assist. Tom has none in the GDD and
   only Bro Hug here. That is fine for the solo slice, but more will be needed for co-op.
5. Should any of these be cut to keep the six new `core` rules out of the solo slice?
   The cards that need nothing new are Noogie, Headlock, Hot Take, Stare Down, Noggin Knock,
   Bro Hug, Dislocate, Story Time, Gym Selfie and Headbutt.

Once accepted, Agent B adds these cards to the pool (task 004) and opens `core` task requests
for Agent A for each "Yes" row above. The owner copies the cards into the source GDD.
