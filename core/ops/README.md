# core/ops — the effect operation catalogue

Lane: core (Agent A). Content agents read this to write `effects` in card and enemy move files.

Every card (`data/cards/`) and enemy move (`data/enemies/`) has an `effects` list. Each entry is
one operation: a JSON object with an `"op"` name and that op's own fields. Effects run in order.
The registry is `core/ops/ops.gd` (`OPS`); each op lives in its own file here.

- **Unknown op or bad fields.** A card with an op not listed here, or with a field missing, of the
  wrong type or not listed for its op, is `unplayable` (the core never half-plays a card). In an
  enemy move such an effect is skipped. `Ops.check(effect)` / `Ops.check_all(effects)` return the
  problems; content tests can call them on every data file.
- **Need an op that is not here?** Write a task for the core lane (CLAUDE.md "Content is data").
- **Numbers** are ints. Base values are before Swole, Chill and Clout (GDD "Card definition fields").

## Who an effect lands on

| Who uses it | `targets` the op receives | The actor |
| --- | --- | --- |
| A card with `target: "enemy"` | the enemy uid the player picked | the Dude playing it |
| `target: "all_enemies"` | every enemy in the fight when the card is played, left to right | the Dude |
| `target: "self"` | the Dude playing it | the Dude |
| `target: "none"` | nobody | the Dude |
| `target: "ally"` / `"puppet"` | not built: the card is rejected with `bad_target` | |
| An enemy move | the intent's `target_ids` that are not Passed Out when it acts | the enemy |
| A Bro Move (`use_bro_move`, task 013) | as for a card with the Bro Move card's `target`, from the request's optional `target_id` | the Dude using it |
| A Power trigger (task 013) | the trigger's `target`: `subject`, `all_enemies` or `self` (see "Powers") | the Dude who played the Power |
| An effect with `"target": "all_enemies"` (task 013) | every enemy in the fight when that effect runs, overriding the above | unchanged |
| A card trigger (`on_draw`, `on_end_of_turn_in_hand`; task 015) | the card's owner | the card's owner |

Each op says whether it uses `targets` or the actor.

## Fields every op may have (task 013)

Besides its own fields, any effect may carry these. `Ops.check()` checks them; an unknown value
makes the card `unplayable` like any other bad field.

| Field | Values | Meaning |
| --- | --- | --- |
| `if` | `target_has_broken_arm`, `target_now_armless` | The effect runs only if the condition holds **when the effect is reached**, so after the card's earlier effects. It holds when at least one of the effect's targets is an enemy still in the fight that meets it; a dead or missing target never does. Skipped effects emit nothing. File: `core/ops/conditions.gd` |
| `target` | `all_enemies` | This effect lands on every enemy in the fight when it runs, instead of the card's targets. For cards that do one thing to the picked enemy and another to everyone (Chest Bump) |

- `target_has_broken_arm`: the target has at least 1 Broken Arm (Wrist Lock).
- `target_now_armless`: the target is Armless now: it has arms and all are broken (Snap City). An
  enemy that was already Armless before the card still counts.

## Tom's cards, written with these ops

The recipes task 006 should use (the core's own tests play exactly these, in
`tests/core/ops/tom_fixtures.gd`):

| Card | `target` | `effects` (and `power_triggers`) |
| --- | --- | --- |
| Punch | `enemy` | `damage` 6 |
| Flex | `self` | `guard` 5 |
| Arm Bar | `enemy` | `damage` 8 (`hits` 1), `apply_status` `broken_arm` 1 |
| Well, Actually | `enemy` | `apply_status` `ick` 2 |
| Wrist Lock | `enemy` | `damage` 5, `{"op": "draw", "amount": 1, "if": "target_has_broken_arm"}` |
| Chrome Dome | `self` | `guard` 7, `thorns` 3 |
| Skull Bash | `enemy` | `damage` 10, `self_damage` 2 |
| Unsolicited Advice | `enemy` | `apply_status` `ick` 3, `apply_status` `noodle_arms` 1 |
| Cast Party | `self` | `guard_per_broken_arm` 4 |
| Snap City | `enemy` | `damage` 14, `apply_status` `broken_arm` 1, `{"op": "gain_hype", "amount": 1, "if": "target_now_armless"}` |
| Pickup Line | `all_enemies` | `apply_status` `ick` 4, `self_damage` 3 |
| Reply Guy (type `power`) | `none` | `effects: []`; `power_triggers: [{"when": "enemy_buffed", "target": "subject", "effects": [apply_status ick 2]}]` |
| Double Arm Day | `enemy` | `damage` 9, `apply_status` `broken_arm` 1, `damage` 9, `apply_status` `broken_arm` 1 (each hit, then its break, as the text reads; not `hits: 2`) |
| Friend Zone (type `power`) | `none` | `effects: []`; `power_triggers: [{"when": "turn_start", "target": "all_enemies", "effects": [apply_status ick 1]}, {"when": "enemy_grossed_out", "target": "subject", "effects": [apply_status exposed 2]}]` |
| Chest Bump (Bro Move) | `enemy` | `damage` 20, `{"op": "apply_status", "status": "broken_arm", "stacks": 1, "target": "all_enemies"}` |

## Ops

### `damage`

Deal damage to each target. File: `core/ops/damage.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 0 or more | Base damage of one hit, before the attacker's Swole |
| `hits` | int, 1 or more, optional (default 1) | How many times the hit repeats |

- **Lands on:** `targets`. Hit 1 lands on every target in order, then hit 2, and so on. Targets
  that died or Passed Out are skipped; the effect stops once the fight is decided.
- **Each hit** follows the damage order (GDD "Damage order", task 009):

  | Step | What happens | Constant |
  | --- | --- | --- |
  | 1 | `amount` + the attacker's `swole`, never below 0 | — |
  | 2 | × Noodle multiplier if the attacker has Noodle Arms | `NOODLE_MULT` |
  | 3 | × (1 − reduction × k ÷ n) if the attacker is an enemy with k of its n arms broken (n > 0) | `BROKEN_ARM_MAX_REDUCTION` |
  | 4 | × Exposed multiplier if the target is Exposed | `EXPOSED_MULT` |
  | 5 | Round down **once**. Guard absorbs and is used up (G2), the rest comes off HP, HP stops at 0 | — |

  Steps 2–4 multiply exact fractions (`core/ops/ratio.gd`), never floats. At 0 HP an enemy dies
  (removed from the fight) and a Dude is Passed Out. Stacks do not matter: 1 Exposed and 3 Exposed
  both mean × `EXPOSED_MULT`.
- **Only attack damage** (G3) gets steps 1–4: `damage` effects on cards of type `attack`, on Bro
  Moves and in enemy moves. A `damage` effect on any other card type deals exactly `amount` (no
  Swole, no multipliers). Self-damage (Skull Bash), Burn and Bedbugs use the `self_damage` op
  (tasks 013 and 015).
- **Thorns** (task 013): after each hit an enemy lands on a Dude whose `thorns` is above 0, the
  enemy takes that much damage back (see `thorns`). If it dies, the rest of its hits do not happen.
- **Events per hit:** `damage_dealt` (`amount` = damage after step 5's rounding, before Guard,
  `blocked` = Guard used, `hp_lost`), then `enemy_died` or `dude_passed_out` if it reached 0 HP.
  Guard used up by a hit has no separate `guard_changed`.
- **Enemy intents:** a move with `damage` needs a target, so its intent is aimed at a Dude.

Example: `{ "op": "damage", "amount": 8, "hits": 1 }`.

### `guard`

The actor gains Guard. File: `core/ops/guard.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 0 or more | Base Guard gained, before Chill |

- **Lands on:** the actor (the Dude playing the card, or the enemy using the move), whatever the
  card's `target` is. So "Deal 6 damage. Gain 3 Guard" on a `target: "enemy"` card works.
- A Dude adds their `chill`, once per `guard` effect. Enemies have no Chill.
- **Hungover** (G4): a Hungover Dude's Guard from a card is (`amount` + Chill) × `HUNGOVER_MULT`,
  rounded down once. Brace 5 with 4 Chill while Hungover gives 6. Guard that does not come from a
  card (later: Gear, Brews) is not reduced.
- Dudes' Guard drops to 0 at Refresh. An enemy's Guard drops to 0 at the start of its own action
  in the enemy phase (G30, answered "accept"; built by task 011). Guard an enemy gains from its move
  therefore protects it through the players' next turn.
- **Events:** `guard_changed` (`delta` = Guard gained, `guard` = new total), only when it changes.
- **Enemy intents:** a move with only `guard` effects has no targets.
- Guard an enemy gains is a **buff** (G10): Reply Guy reacts to it (see "Powers").

Example: `{ "op": "guard", "amount": 5 }`.

### `apply_status`

Apply a status to each target. File: `core/ops/apply_status.gd`; the rules around statuses are
in `core/combat/statuses.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `status` | text | One of `exposed`, `noodle_arms`, `hungover`, `foggy`, `broken_arm`, `ick` (`core/schema/README.md` "Status ids") |
| `stacks` | int, 1 or more | Stacks to apply. For `broken_arm`, arms to break. For `ick`, Ick before Clout |

- **Lands on:** `targets` (the picked enemy, every enemy, the player for `target: "self"`, or an
  enemy move's intended Dudes). Targets that died or Passed Out are skipped.
- **Who can carry what** (GDD "Statuses"): `exposed` and `noodle_arms` go on anyone; `hungover` and
  `foggy` on Dudes only; `broken_arm` and `ick` on enemies only. On a target that cannot carry it,
  the effect does nothing.
- **What each does:**

  | Status | Effect | Wears off (G1) |
  | --- | --- | --- |
  | `exposed` | Takes × `EXPOSED_MULT` attack damage (damage order step 4) | 1 stack per turn |
  | `noodle_arms` | Deals × `NOODLE_MULT` attack damage (step 2) | 1 stack per turn |
  | `hungover` | Guard from cards × `HUNGOVER_MULT` (see `guard`) | 1 stack per turn |
  | `foggy` | Draws 1 fewer card per stack at Refresh, never below 0 | 1 stack, right after the Refresh it affected |
  | `broken_arm` | `broken_arms` rises by `stacks`, capped at `arm_count`; 0-arm enemies are immune. The enemy's attacks get damage order step 3. When every arm is broken it is **Armless**: its next move that deals damage is skipped, once per fight (G7) | Never |
  | `ick` | `ick` rises by `stacks` + the actor's Clout, once per application (G5). At or above `ick_threshold` the enemy is **Grossed Out** (G6): Ick resets to 0, the threshold rises by `ICK_THRESHOLD_STEP`, and it skips its next action | On trigger |

  "1 stack per turn": a Dude who is not Passed Out loses 1 stack of Exposed, Noodle Arms and
  Hungover at End of turn, after the hand is discarded. An enemy loses 1 stack of each status right
  after its slot in the enemy phase, whether it acted or skipped.
- **Skips in the enemy phase:** a Grossed Out enemy skips whatever it intended
  (`enemy_skipped`, reason `grossed_out`), one action per Grossed Out. An Armless enemy skips its
  next damaging move (`armless`, then `enemy_skipped`, reason `armless`). Grossed Out is used first.
- **Events:** `status_changed` for every change (`delta` = the actual change, `stacks` = the new
  total, 0 when it wore off). Grossed Out emits `status_changed` (Ick added), `grossed_out`
  (`new_threshold`), then `status_changed` (Ick back to 0). Nothing is emitted when nothing changes
  (an arm that is already broken, a status the target cannot carry).
- **Enemy intents:** a move with `apply_status` needs a target, so its intent is aimed at a Dude.
- **Debuffs** (G27) are `exposed`, `noodle_arms`, `hungover` and `foggy`
  (`core/combat/statuses.gd` `DEBUFFS`).

Examples: `{ "op": "apply_status", "status": "broken_arm", "stacks": 1 }` (Arm Bar's second effect),
`{ "op": "apply_status", "status": "ick", "stacks": 2 }` (Well, Actually).

### `draw`

The actor draws cards. File: `core/ops/draw.gd`. Task 013.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 1 or more | Cards to draw |

- **Lands on:** the actor, if it is a Dude who is not Passed Out; otherwise nothing happens.
- Draws from the top with the G8 reshuffle (discard pile shuffled in when the draw pile is empty;
  nothing when both are). No hand size limit.
- Each drawn copy's `on_draw` runs right after it is drawn (task 015; see "Card triggers").
- **Events:** `deck_shuffled`, `card_moved` (`draw_pile` -> `hand`) per card, then any `on_draw` events.
- **Enemy intents:** no targets.

Example: `{ "op": "draw", "amount": 1, "if": "target_has_broken_arm" }` (Wrist Lock).

### `gain_hype`

The actor gains Hype. File: `core/ops/gain_hype.gd`. Task 013.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 1 or more | Hype gained |

- **Lands on:** the actor, if it is a Dude who is not Passed Out; otherwise nothing happens. No cap.
- **Events:** `hype_changed` (`delta` = `amount`).
- **Enemy intents:** no targets.

Example: `{ "op": "gain_hype", "amount": 1, "if": "target_now_armless" }` (Snap City).

### `self_damage`

The actor takes damage that is not an attack. File: `core/ops/self_damage.gd`. Tasks 013 and 015
(Skull Bash, Pickup Line; Bedbugs' `on_draw`, Burn's `on_end_of_turn_in_hand`).

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 0 or more | Damage taken |

- **Lands on:** the actor (Dude or enemy), whatever the card's `target` is.
- **Not attack damage** (G3): no Swole, Noodle Arms, Broken Arm or Exposed. Exactly `amount`,
  through the actor's Guard first (G2), then HP, which stops at 0. A Dude at 0 HP is Passed Out.
  `amount` 0 does nothing.
- **Events:** `damage_dealt` with `source_id` `""` (no attacker, so no thorns), then
  `dude_passed_out` or `enemy_died` at 0 HP.
- **Enemy intents:** no targets.

Example: `{ "op": "self_damage", "amount": 2 }` (Skull Bash).

### `guard_per_broken_arm`

The actor gains Guard for every Broken Arm on all enemies. File: `core/ops/guard_per_broken_arm.gd`. Task 013.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 0 or more | Guard per Broken Arm, before Chill |

- **Lands on:** the actor. The count is the sum of `broken_arms` over every enemy still in the
  fight when the effect runs.
- The base, `amount` × count, then follows the `guard` rule exactly: Chill added once, Hungover
  for Guard from cards. With no Broken Arms only Chill is gained.
- **Events:** `guard_changed`, only when it changes.
- **Enemy intents:** no targets.

Example: `{ "op": "guard_per_broken_arm", "amount": 4 }` (Cast Party).

### `thorns`

Damage back to every enemy that hits the actor this turn. File: `core/ops/thorns.gd`. Task 013.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 1 or more | Damage dealt back per enemy hit |

- **Lands on:** the actor, if it is a Dude who is not Passed Out: `dude.thorns` rises by `amount`
  (two Chrome Domes make 6). Otherwise nothing happens.
- While `thorns` is above 0, **every hit** (G9) of an enemy's `damage` effect that lands on that
  Dude deals `thorns` damage back to that enemy, even if Guard absorbed the hit. Not attack damage
  (G3); it goes through the enemy's Guard, then HP, and can kill it, which ends its attack.
- `thorns` drops to 0 at the Dude's next Refresh, so it covers "this turn" and the enemy phase
  after it.
- **Events:** `thorns_changed` (`delta`, `thorns` = new value) when it rises and when it resets;
  each glare is a `damage_dealt` from the Dude to the enemy.
- **Enemy intents:** no targets.

Example: `{ "op": "thorns", "amount": 3 }` (Chrome Dome).

### `add_card`

Create new copies of a card for a Dude (task 015). File: `core/ops/add_card.gd`. Used for Junk from
enemies (Skeleton Intern, Hall Monitor Golem, Boag Imp), Brews (Special Brownie) and cards.

| Field | Type | Meaning |
| --- | --- | --- |
| `card_id` | text | The card definition to copy, for example `junk_paperwork`. Must be a card in `data/cards/`; the ruleset build reports one that is not |
| `to` | text | `draw_pile`, `discard_pile` or `hand`: where each copy goes |
| `shuffle_in` | bool, optional (default `false`) | Only with `to: "draw_pile"`. `true` puts each copy at a random position of the draw pile instead of on top |
| `count` | int, 1 or more, optional (default 1) | Copies made for each Dude it lands on |

- **Lands on:** the actor when the actor is a Dude (a card, a Brew, a card trigger), whatever the
  card's `target` is, so "Deal 1 damage. Add 2 Paperwork to your hand" on a `target: "enemy"` card
  works. In an enemy move: every Dude among the intent's targets. Passed Out Dudes get nothing.
- **Each copy** gets a new `card_uid` (from `next_uid`) and joins the Dude's `cards`, not upgraded.
  A card whose definition `lasts` `"run"` (the default) also joins the end of the run `deck`; a
  `"fight"` card does not and is removed when the fight ends (see "Card triggers" below).
- **Where it goes:** `draw_pile`: on top (the next card drawn), or with `shuffle_in` at a position
  from top to bottom, each equally likely, drawn from the **receiving** Dude's `shuffle` stream (one
  draw per copy, in order). `discard_pile`: on top of the discard pile. `hand`: the end of the hand;
  this is not a draw, so `on_draw` does not run.
- **Events:** `card_created` per copy (`to` = the pile).
- **Enemy intents:** a move with `add_card` needs a target, so its intent is aimed at a Dude.

Examples: Skeleton Intern's `{ "op": "add_card", "card_id": "junk_paperwork", "to": "draw_pile",
"shuffle_in": true }`; Hall Monitor Golem's `{ "op": "add_card", "card_id": "junk_detention", "to":
"discard_pile" }`; Special Brownie's `{ "op": "add_card", "card_id": "junk_hangover", "to":
"discard_pile" }`.

### `lose_hype`

The actor loses Hype (task 015, Hangover). File: `core/ops/lose_hype.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 0 or more | Hype lost |

- **Lands on:** the actor, when it is a Dude. Enemies have no Hype: nothing happens.
- Hype stops at 0: a Dude with less Hype than `amount` loses what they have.
- **Events:** `hype_changed` (`delta` = minus the Hype actually lost), only when Hype changes.

Example: `{ "op": "lose_hype", "amount": 1 }` (Hangover's `on_draw`).

### `heal`

Restore HP to each target (task 021). File: `core/ops/heal.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 0 or more | HP restored to each target, capped at its `max_hp` |

- **Lands on:** `targets`. A Passed Out Dude is not healed (waking is another rule).
- **Events:** `healed` (`amount` = HP actually restored, `hp` = new value), only when HP changes.

Example: `{ "op": "heal", "amount": 10 }` (Light Beer).

### `gain_stat`

Change a stat (task 021). File: `core/ops/gain_stat.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `stat` | text | `swole`, `chill`, `clout`, `max_hp`, `hype_per_turn`, `draw_per_turn` or `brew_slots` (`core/schema/gear_def.gd` `STATS`). Enemies only have `swole` |
| `amount` | int, not 0 | Change; negative lowers the stat |
| `duration` | text, optional | `"fight"`: undone when the fight ends (recorded in `combat.fight_stat_changes`). Absent: permanent for the run |

- **Lands on:** `targets` that have the stat. Floors: `max_hp` 1; `hype_per_turn`, `draw_per_turn`,
  `brew_slots` 0. Swole, Chill and Clout may go negative. Lowering `max_hp` below `hp` lowers `hp`.
- Raising `max_hp` does not raise `hp` (Gallon Jug; task 021 log).
- `duration: "fight"` outside a fight does nothing.
- **Events:** `stat_changed` (`delta`, `value`), only when the stat changes.

Example: `{ "op": "gain_stat", "stat": "swole", "amount": 3, "duration": "fight" }` (Protein Shake).

### `remove_debuffs`

No fields (task 021). File: `core/ops/remove_debuffs.gd`. Each target loses every stack of every
debuff (G27: `exposed`, `foggy`, `hungover`, `noodle_arms`; `core/combat/statuses.gd` `DEBUFFS`).
**Events:** `status_changed` per debuff removed. Example: `{ "op": "remove_debuffs" }` (Hair of the Dog).

### `tap_cards`

Tap cards in the actor's hand (task 021). File: `core/ops/tap_cards.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `card_type` | text | One of `core/schema/card_def.gd` `TYPES`: every card of this type in the hand is Tapped |

- **Lands on:** the actor's own hand (a Dude; enemies do nothing), in hand order, to `tapped_pile`.
- **Events:** `card_moved` (`hand` -> `tapped_pile`) per card.

Example: `{ "op": "tap_cards", "card_type": "junk" }` (Hair of the Dog).

### `prevent_pass_out`

Hold a Dude up once (task 021). File: `core/ops/prevent_pass_out.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `hp` | int, 1 or more | HP the Dude is left at instead of passing out |

- **Lands on:** `targets` that are Dudes not Passed Out. Sets `combat.pass_out_saves[player_id]`. The
  next time that Dude would pass out this fight, HP becomes `hp` (capped at `max_hp`) and the save is
  used up (`pass_out_prevented`). A second use before then replaces the first; saves do not stack.
- Outside a fight it does nothing.

Example: `{ "op": "prevent_pass_out", "hp": 1 }` (Smelling Salts, solo).

## Powers (task 013)

A card of `type: "power"` is played like any card (cost, `card_played`, its `effects` if any),
then goes to its Dude's `powers` list (`card_moved` with `to: "powers"`) instead of a pile, and is
active for the rest of the fight. The next fight starts with no Powers. What it does is its
definition's `power_triggers` (shape: `core/schema/card_def.gd`); a Power whose trigger effects
fail `Ops.check()` is `unplayable`. File: `core/combat/powers.gd`.

| `when` | Fires | May use `target: "subject"` |
| --- | --- | --- |
| `turn_start` | Once per turn, after every Dude's Refresh, before the player phase. Not on the turn the Power is played | No |
| `enemy_buffed` | Each time an enemy gains a buff (G10): Guard (a `guard_changed` with a positive delta on an enemy) or Swole (no op raises an enemy's Swole yet) | Yes: that enemy |
| `enemy_grossed_out` | Each time an enemy is Grossed Out (a `grossed_out` event), whatever caused it | Yes: that enemy |

| `target` | Lands on |
| --- | --- |
| `subject` | The enemy the trigger is about; skipped if it has died since |
| `all_enemies` | Every enemy in the fight when it fires |
| `self` | The Dude who played the Power |

- The Dude who played the Power is the actor, so Ick from a Power adds that Dude's Clout (G5).
  Trigger effects are not attack damage and count as from a card (Hungover).
- Order: triggers react after each op, to that op's events in order; for each, Dudes in seat
  order, each Dude's Powers oldest first, each Power's triggers in definition order. Two copies of a
  Power both fire. A Passed Out Dude's Powers do not fire.
- **Events:** `power_triggered` (`player_id`, `card_uid`, `when`, `subject_id`), then the
  effects' own events. Trigger effects can set off further triggers (Reply Guy's Ick can Gross Out
  an enemy, which fires Friend Zone).

## Card triggers (task 015)

Optional card definition fields (`core/schema/card_def.gd`) for cards that act without being
played. Rules: `core/combat/card_triggers.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `on_draw` | list of effects | Run right after the copy is drawn into its owner's hand (Refresh, or any rules draw) |
| `on_end_of_turn_in_hand` | list of effects | Run at End of turn if the copy is in its owner's hand, before the hand is discarded |
| `play_limit_in_hand` | int, 0 or more | While the copy is in hand, its owner may play at most this many cards this turn (`cards_played_this_turn`); further plays are rejected `unplayable` |
| `lasts` | `"run"` (default) or `"fight"` | `"fight"`: when the fight ends (won or lost) the copy leaves the Dude's `cards`, `deck` and piles, with `card_removed` |
| `removable` | bool (default `true`) | `false`: cannot be removed at Baileys (read by task 025) |

- Trigger effects use the same ops as `effects`. The owner is the actor and the only target, damage
  is not attack damage, and they count as from a card (Hungover). They stop once the fight is
  decided; an effect with a bad op or fields is skipped.
- A Bedbugs draw at Refresh or a Burn at End of turn can Pass Out the last Dude. The fight then
  ends at once: no player phase or no enemy phase.
- Every rules draw (Refresh and the `draw` op) goes through `CardTriggers.draw_in_place`, not
  `Piles.draw_in_place`, so `on_draw` runs.

The six Junk cards (GDD "Junk cards") as data, rarity `special` (G17):

| Card | Cost | Fields |
| --- | --- | --- |
| Hangover | -1 | `"on_draw": [{"op": "lose_hype", "amount": 1}]`, `"lasts": "run"` |
| Regret | -1 | `"removable": false`, `"lasts": "run"` |
| Bedbugs | -1 | `"on_draw": [{"op": "self_damage", "amount": 1}]`, `"lasts": "run"` |
| Paperwork | 1 | `"effects": []`, `"keywords": ["tapped"]`, `"lasts": "fight"` |
| Detention | -1 | `"play_limit_in_hand": 4`, `"lasts": "fight"` |
| Burn | -1 | `"on_end_of_turn_in_hand": [{"op": "self_damage", "amount": 2}]`, `"lasts": "fight"` |

## Gear (task 021)

Format: `core/schema/gear_def.gd`. Rules: `core/combat/gear_triggers.gd`.

- **`stats`** are added once when the Gear is gained (`gear_gained`, then `stat_changed`), including
  starting Gear. Gear is never lost in the slice.
- **Order:** Dudes in seat order, each Dude's Gear in the order gained, each Gear's triggers in
  definition order. A Passed Out Dude's Gear does not fire.
- **A trigger whose effects use an op the core lacks, or bad fields, is skipped whole.**
  `GearTriggers.check(definition)` reports these for content tests.
- **Effects from Gear** are not attack damage (G3) and not "from cards" (G4). Each fire emits
  `gear_triggered` first.

### Gear trigger points (`when`)

| `when` | Fires |
| --- | --- |
| `fight_start` | Once per fight, after `fight_started` (draw piles already shuffled), before turn 1's intents and Refresh, so before Hype is filled and the first hand drawn |
| `first_turn` | Once per fight, right after every Dude's turn-1 Refresh (Hype filled, hand drawn), before the player phase takes requests |
| `fight_end` | Once per fight that is **won**, at the end of the request that ended it, after `fight_ended`. Fight-only stat changes are taken back first (win or loss) |
| `card_played` | After the owner's card has resolved and gone to its pile, unless the fight is over. Optional filters `card_type`, `min_cost` |
| `ick_applied` | Each time an effect run by the owner (card, Brew, Gear) adds Ick to an enemy: once per enemy, with that enemy as `trigger_target` and the Ick added (Clout included, G5) as the stacks for `amount_per_stack`. Its own effects do not set off `ick_applied` again |

Optional `hp_below_percent` (1..100): fires only while `hp × 100 < max_hp × percent`.

### Trigger targets (`target`)

`self` (the owner), `all_enemies`, `all_dudes` (not Passed Out, seat order), `trigger_target` (the
Ick's enemy, or the played card's targets; only with `ick_applied` and `card_played`).

### Modifiers (`modifiers`)

| `kind` | `amount` | Read by |
| --- | --- | --- |
| `card_damage` | Added to the base damage of every hit of each `damage` effect on the owner's cards that match `card_type` / `min_cost` (before Swole, so the damage order applies to it) | `core/combat/play.gd` |
| `shop_price_percent` | Baileys prices are this percent of normal, rounded down; all Baileys prices, card removal included (G26). `GearTriggers.shop_price()` | Run lane (task 025) |
| `fight_dolla_bills_percent` | Dolla Bills from fights are this percent of normal, rounded down. `GearTriggers.fight_dolla_bills()` | Run lane (task 025) |

Several modifiers of one `_percent` kind multiply, rounded down once at the end.

## Brews (task 021)

Format: `core/schema/brew_def.gd`. Rules: `core/combat/brews.gd`. The `use_brew` request:

- Costs no Hype; any time in the player phase (also after pressing Ready). `cards_played_this_turn`
  does not change.
- Refused: `empty_slot` (no Brew at that index; `brews` is packed, so any index past the last Brew),
  `unplayable` (unknown Brew, empty effects, or an op the core lacks), `bad_target`.
- Applied: the Brew leaves its slot (later Brews move down), `brews_drunk` + 1, `brew_used`, then its
  effects run like a card's (the drinker's Gear reacts to them). Not attack damage, not from a card.
- `party_size` 1 and a `solo` variant: its target and effects are used instead.
- Targets: `none`, `self`, `enemy`, `all_enemies`, `all_dudes` (`target_id` ""), `ally` (not built:
  `bad_target`).

## Not built yet

Ops for the other Dudes' mechanics and for Side Quests (task 025). A card or Brew with an op the
core does not have is `unplayable`, and a Gear trigger with one is skipped.
