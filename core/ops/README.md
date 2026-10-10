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

Each op says whether it uses `targets` or the actor.

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
  Swole, no multipliers). Self-damage, Burn and the like will be their own ops (task 013).
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

## Not built yet

`draw`, `gain_hype`, `self_damage` and the rest of Tom's card ops (task 013), Gear and Brew effects
(task 021). Until then, cards using them are `unplayable`.
