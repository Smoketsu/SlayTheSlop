# 2026-10-12 - Tuning: Broken Arm maximum reduction 0.4 -> 0.3

Contract change to `data/constants.json`, made by Agent A at Smoketsu's request after a full playthrough:
"the broken arm mechanic is quite strong ... perhaps bring the damage reduction back to 30%".
It changes a value only. No name or meaning changes.

## Changed

| Constant | Old | New | Meaning (unchanged) |
| --- | --- | --- | --- |
| `BROKEN_ARM_MAX_REDUCTION` | 0.4 | 0.3 | Attack reduction when every arm is broken. With k of n arms broken, an enemy's attack damage is multiplied by 1 - BROKEN_ARM_MAX_REDUCTION x k / n (step 3 of the damage order). Range 0..1. Tuned by either person through a contract PR. |

Effect on a 2-armed enemy:
- 1 arm broken: x0.85 (was x0.8).
- 2 arms broken: x0.7 (was x0.6).

## Tests updated

These are Agent A's tests. They hold hand-worked numbers for the old value, so they fail on purpose
when the value changes.

- `tests/core/ops/test_damage_order.gd`:
  - `SLICE_VALUES` now holds 0.3.
  - `ENEMY_TABLE` is recomputed with factors 1, 17/20 and 7/10. One row now catches per-step
    rounding (it was two).
  - The every-product formula now uses (20 - 3k) / 20.
- `tests/core/combat/test_statuses.gd`: an Armless hit is now 10 x 0.7 = 7.
- `tests/core/enemies/test_goblin_king_chad.gd`:
  - Chad's hits are now [17, 10, 8, 4 x6].
  - `SCRIPT_HASH` is re-recorded. The result and the move sequence are unchanged.
- `tests/core/combat/test_fixed_seed_status_fight.gd`: `FINAL_HASH` is re-recorded, because enemy hits
  are larger. `RECORDED` still holds.

## Not done here

- `tests/client/test_tooltips.gd` (Agent B's lane) asserts the real tooltip says "40% less". It needs a
  one-line change from Agent B. The tooltip itself already reads the constant and says "30% less".
- `docs/GDD.md` (snapshot 0.5) still says "1 - 0.4 x k / n" under "Statuses". Agents don't edit the
  GDD; the owner should update their copy.
