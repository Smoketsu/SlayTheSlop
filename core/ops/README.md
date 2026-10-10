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
- **Each hit** (GDD "Damage order"): step 1, `amount` + the attacker's `swole` (never below 0).
  Steps 2–4 (Noodle Arms, Broken Arm, Exposed) are **not applied yet** (task 009). Step 5: the
  target's Guard absorbs the damage and is reduced by what it absorbed (G2), the rest comes off HP,
  HP stops at 0. At 0 HP an enemy dies (removed from the fight) and a Dude is Passed Out.
- **Events per hit:** `damage_dealt` (`amount` = damage after Swole, `blocked` = Guard used,
  `hp_lost`), then `enemy_died` or `dude_passed_out` if it reached 0 HP. Guard used up by a hit has
  no separate `guard_changed`.
- **Enemy intents:** a move with `damage` needs a target, so its intent is aimed at a Dude.

Example: `{ "op": "damage", "amount": 8, "hits": 1 }`.

### `guard`

The actor gains Guard. File: `core/ops/guard.gd`.

| Field | Type | Meaning |
| --- | --- | --- |
| `amount` | int, 0 or more | Base Guard gained, before Chill |

- **Lands on:** the actor (the Dude playing the card, or the enemy using the move), whatever the
  card's `target` is. So "Deal 6 damage. Gain 3 Guard" on a `target: "enemy"` card works.
- A Dude adds their `chill`, once per `guard` effect. Enemies have no Chill. Hungover is not
  applied yet (task 009).
- Dudes' Guard drops to 0 at Refresh. Enemy Guard is never reset (the GDD does not say when it
  should be; raised in task 007's log).
- **Events:** `guard_changed` (`delta` = Guard gained, `guard` = new total), only when it changes.
- **Enemy intents:** a move with only `guard` effects has no targets.

Example: `{ "op": "guard", "amount": 5 }`.

## Not built yet

`apply_status` (Broken Arm, Ick, Exposed ...: task 009), `draw`, `gain_hype`, `self_damage` and the
rest of Tom's card ops (task 013), Gear and Brew effects (task 021). Until then, cards using them
are `unplayable`.
