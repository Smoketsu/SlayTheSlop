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
  Swole, no multipliers). Self-damage is its own op (`self_damage`, task 013); Burn and the like
  will be too.
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
- **Events:** `deck_shuffled`, `card_moved` (`draw_pile` -> `hand`) per card.
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

The actor takes damage. File: `core/ops/self_damage.gd`. Task 013.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 0 or more | Damage taken |

- **Lands on:** the actor (Dude or enemy), whatever the card's `target` is.
- **Not attack damage** (G3): no Swole, Noodle Arms, Broken Arm or Exposed. Exactly `amount`,
  through the actor's Guard first (G2), then HP, which stops at 0. A Dude at 0 HP is Passed Out.
  `amount` 0 does nothing.
- **Events:** `damage_dealt` with `source_id` = `target_id` = the actor, then `dude_passed_out` or
  `enemy_died` at 0 HP.
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

## Not built yet

Gear and Brew effects (task 021), Junk card ops (task 015). Until then, cards using them are
`unplayable`.
