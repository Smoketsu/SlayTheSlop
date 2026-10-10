# Proposal: rule gaps that block the solo slice

- Author: Agent A, task 001
- Status: **answered.** Every gap accepted as suggested (Smoketsu, Person A, 2026-10-10, in agreement with steamjgrube).
- GDD version read: 0.5

## Why

Milestone 2 needs rules the GDD does not state, or states two ways. CLAUDE.md says agents must not
invent rules, so each gap below has a **suggested default**, and the tasks that depend on it are
blocked until a person writes an answer. Answer under each gap: "accept", or the rule you want.
Gaps that need a GDD change should then go into the owner's GDD, and the next exported snapshot
should replace this file.

Ids (G1, G2 ...) are stable; task files refer to them.

## Combat rules (block tasks 009, 011, 013)

**G1. When does "1 stack per turn" wear off?** Exposed, Noodle Arms, Hungover and Foggy.
Suggested: at the end of the bearer's own turn. Dudes lose a stack at End of turn (step 4); each
enemy loses a stack right after it acts in the enemy phase. Foggy, which matters at Refresh,
loses its stack after the Refresh it affected.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G2. Does Guard get used up?** Step 5 says "subtract the target's Guard".
Suggested: yes. Guard absorbs damage and is reduced by the amount absorbed.
Answer: **accept** (Smoketsu, Person A, 2026-10-10). steamjgrube may object on this PR.

**G3. What counts as "attack damage"** for Exposed and Noodle Arms?
Suggested: only `damage` effects on Attack cards, Bro Moves and enemy attack moves. Self-damage
(Skull Bash, Pickup Line), Burn, Bedbugs, Chrome Dome's glare and Noise Complaint ignore them.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G4. Hungover rounding.** "Gains 25% less Guard from cards": Guard × 0.75, rounded how?
Suggested: add Chill first, then multiply, then round down (the same order the damage list uses).
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G5. Clout and Ick.** Clout is "added to Tom's Ick". Once per application or once per stack?
Suggested: once per application. "Apply 2 Ick" with 1 Clout applies 3. "Apply 4 Ick to all
enemies" applies 4 + Clout to each enemy.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G6. Grossed Out timing.** Suggested: checked as soon as Ick is applied. At or above the
threshold, Ick resets to 0, the threshold rises by `ICK_THRESHOLD_STEP`, and the enemy skips its
next action. Its current intent is shown as skipped. Ick applied while it is already waiting to
skip still counts toward the new threshold.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G7. Armless.** "Loses its next attack, once per fight." Suggested: when its last arm breaks,
the enemy's next move that deals damage is skipped (non-attack moves still happen). Breaking arms
on an enemy with `arm_count` 0, or past its count, does nothing.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G8. Empty draw pile and hand size.** The GDD says neither.
Suggested: when the draw pile is empty and a draw is needed, shuffle the discard pile (with the
player's `shuffle` stream) into the draw pile. If both are empty, the draw does nothing. No hand
size limit in the slice.
Answer: **accept** (Smoketsu, Person A, 2026-10-10). steamjgrube may object on this PR.

**G9. Chrome Dome:** "enemies that hit Tom take 3 damage". Per hit or per attack?
Suggested: per hit, so Sewer Gator's Death Roll (3 hits) takes 9.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G10. Reply Guy:** "Whenever an enemy gains a buff". Which things are buffs?
Suggested: Swole and Guard gained by an enemy, and any later status marked as a buff. Healing is not a buff.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G11. Enemy moves.** "Never repeats one three times in a row": does that apply to scripted moves
too (Goblin Bouncer alternates)? Suggested: the rule applies to random choice only; scripted
patterns are written as data and followed exactly.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

## Goblin King Chad (blocks tasks 019, 010)

**G12. Chad's ordinary turn.** The GDD gives Rush (every third turn), Keg Stand (charge 2 turns,
then 30) and Rage Cage (below 50% HP). It does not say what he does on other turns above 50% HP,
or when Keg Stand starts.
Suggested: turn 1 Keg Stand starts if he has 2 Pledges. Otherwise he alternates Rush on every
third turn with a 12-damage "Paddle Swat" on other turns. He starts Keg Stand whenever 2 Pledges
are alive and he is not already charging. The 12 and the swat are invented and need your number.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G13. Does Chad start with Pledges?** Suggested: yes, 2 Goblin Pledges, like Goblin Shot-Caller.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

## Content counts (block tasks 006, 008, 012, 014)

**G14. "About 30 cards".** The GDD has 14 Tom cards and 6 Junk cards. Do the 30 include Junk and
the Bro Move? How many new Tom cards should be designed? Suggested: 30 = 14 existing Tom + 16 new
Tom cards (Junk and the Bro Move not counted). New cards come to you as a proposal (task 012) first.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G15. Upgrades.** Only Arm Bar has an upgrade (8 → 11 damage). Lift needs one for every card.
Suggested: task 012 proposes upgrade values for all Tom cards for you to approve; until then Lift
is only offered for cards with an upgrade.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G16. Which 10 Gear.** Suggested: Unused Gym Membership (starting), Arm Wrestling Table, Whole
Can of Body Spray, Lifting Belt, Lucky Lighter, Gallon Jug, Backwards Cap, Participation Trophy,
Championship Ring, Medical Card; plus the 3 Boss Gear as Chad's reward (13 in total).
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G17. Junk card rarity and pools.** Junk cards have no rarity in the GDD's list
(`starter/common/uncommon/rare`), and the card owner list has no `ethan`.
Suggested: add rarity `special` for Junk and Bro Move cards (never offered as rewards or in the
shop), and add owner `ethan` when Ethan is built.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

## Run structure (block tasks 023, 025)

**G18. Map shape.** About 15 nodes with the share table. Suggested: 7 rows plus a boss row, 2–4
nodes per row, each node linking to 1–2 nodes in the next row. Row 1 is always Brawls and the row
before the boss is always The Tailgate. Shares are rounded to whole nodes per floor.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G19. Encounters.** Which enemy groups make up a floor 1 Brawl and Rival fight?
Suggested: Brawls draw from {Goblin Pledge ×2, Goblin Bouncer, Keg Slime, Dorm Rats ×3, Skeleton
Intern, Boo-zer, Kobold RA, Goblin Pledge + Skeleton Intern}; the first two Brawls only use
Pledges, Bouncer or Intern. Rivals are one of the three floor 1 Rivals. Mimic Cooler replaces a
Loot node 1 time in 4.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G20. Starting Dolla Bills.** Not stated. Suggested: 99.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G21. Card reward rarity odds, and prices "by rarity".** Suggested: rewards 60% common, 35%
uncommon, 5% rare; Baileys cards 50 / 75 / 150, Gear 150 / 225 / 300 (common / uncommon / rare);
Shake 50 (common), 65 (uncommon), 75 (rare). Baileys stock: 5 cards, 2 Gear, 2 Shake.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G22. Run numbers that are not in the constants table.** These GDD numbers will be added to
`data/constants.json` under these names unless you prefer others (additive, no rule change):
`BASE_BREW_SLOTS` 3, `CARD_REWARD_CHOICES` 3, `BRAWL_DOLLA_MIN` / `_MAX` 10 / 20,
`BRAWL_BREW_CHANCE` 0.4, `RIVAL_DOLLA_MIN` / `_MAX` 25 / 35, `TAILGATE_NAP_HEAL` 0.3,
`CARD_REMOVE_BASE` 75, `CARD_REMOVE_STEP` 25, `BRO_METER_SOLO_CARDS` 3.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

## Side Quests and items (block tasks 014, 016, 021, 025)

Found while writing the content tasks.

**G23. Betting more than you have.** The Beer Pong Table bets 50 Dolla Bills. Suggested: the dumb
option is not offered below 50 Dolla Bills.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G24. "A random Gear"** (3 a.m. Tattoo). From which pool? Suggested: the same pool as Loot nodes
(general and the Dude's own Gear, not Boss Gear, nothing already owned), using the `side_quest` stream.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G25. "Start the next fight with ..."** (Gas-Station Sushi, The Unlabeled Brownie). Suggested: the
status is stored as pending on the Dude and applied when the next fight starts. This needs a new
Dude state field; Agent A adds it in a contract PR.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G26. Medical Card's 20% off.** Does it apply to card removal, and how do prices round?
Suggested: it applies to every Baileys price including removal; round down.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G27. What is a debuff?** (Hair of the Dog, and Nate's later cards.) Suggested: Exposed, Noodle
Arms, Hungover and Foggy. Broken Arm and Ick are on enemies only and never count.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G28. Rarity of starting and Boss Gear.** Unused Gym Membership and the three Boss Gear have no
rarity in the GDD. Suggested: rarity `starter` for starting Gear and `boss` for Boss Gear; neither
is ever offered at Baileys or as Loot.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

**G29. Does Baileys say which Brew a Shake is?** Suggested: yes, by name and effect; "Shake" is
only the shop's label. Also note that the Brew "Protein Shake" will sit under a "Shake" label;
the people may want to rename one of them.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

## Found while building the combat skeleton (task 007)

**G30. When does an enemy's Guard reset?** The GDD's Refresh drops each player's Guard to 0, but
nothing resets enemy Guard, so as written it piles up for the whole fight (the Goblin Bouncer gains 8
every other turn). Suggested: an enemy's Guard drops to 0 at the start of its own action in the
enemy phase, before it acts.
Answer: **accept** (Smoketsu, Person A, 2026-10-10; agreed with steamjgrube).

## Found while building the floor map (task 023)

**G31. How do the node shares and the fixed rows fit together?** G18 says shares are "rounded to
whole nodes per floor" and fixes row 1 as all Brawls and the pre-boss row as all The Tailgate, but
not how those fixed rows count toward the shares.
Suggested (as built in task 023): apply the GDD shares to the whole floor (rows 1..7, not the
entrance or the boss), round by largest remainder with ties in GDD table order, and count the fixed
rows toward their type. Because a pre-boss row of 4 Tailgates would exceed the 12% share, the
pre-boss row's size is drawn only from sizes the share can hold (about half 2 nodes, half 3).
The alternative (Slay the Spire's) applies the shares only to rows 2..6, which allows any row size
but gives floors far more Brawls and Tailgates than the GDD table says.
Answer: **accept** under Smoketsu's standing instruction to take the defaults (2026-10-10). Confirm or change.

## Found while building Tom's card ops (task 013)

Built as suggested so the slice can play; each is one data or one-line change if the people
answer differently. Not yet answered.

**G32. Friend Zone: which Grossed Out enemies become Exposed?** "At the start of each turn, apply 1
Ick to all enemies. Grossed Out enemies also become Exposed for 2 turns." It can mean (a) any enemy
that is Grossed Out while Friend Zone is active, whatever caused it, (b) only enemies Grossed Out by
Friend Zone's own start-of-turn Ick, or (c) enemies already waiting to skip at the start of a turn.
Suggested (as built in task 013): (a). Exposed 2 = 2 stacks, so it lasts through 2 of the players'
turns. Reading (b) is a data change in the card (an `if` condition on the second effect).
Answer:

**G33. Chest Bump's 20 damage: one enemy or all?** "Deal 20 damage. Break 1 arm on every enemy."
Ethan's Bro Move says "to all enemies" explicitly; Chest Bump does not. Suggested (as built): the 20
damage goes to one enemy the player picks, and the arm break to every enemy. The `use_bro_move`
request therefore carries an optional `target_id`; the client (task 018) must send it, or the
request is refused as `bad_target`.
Answer:

**G34. Powers: duplicates and Passed Out Dudes.** The GDD says a Power "lasts the rest of the
fight" but not whether two copies of the same Power both work, or whether a Passed Out Dude's
Powers keep working (it says so only for Ethan's Nap, which "is not Passed Out"). Suggested (as
built): every copy played works on its own (two Reply Guys apply 2 Ick twice), and a Passed Out
Dude's Powers do not fire until he wakes.
Answer:

## Found while building the floor 1 enemies and Goblin King Chad (tasks 017 and 019)

Each gap below was built as suggested so the slice can play. Each is also described in its task file (`docs/tasks/017-floor1-enemy-behaviors.md` and `docs/tasks/019-goblin-king-chad.md`) and in the header of the code file that runs it. Agent B asked for them to be listed here in the review of #50. None is answered yet.

**G35. Goblin Pledge: when does it check "last goblin standing", and what counts as a goblin?**
- Suggested (as built): it checks when it picks its intent (turn flow step 1), so the players see the call coming. The call replaces its hit that turn.
- It can call again every time it is the last goblin; there is no once-per-fight limit.
- "Goblin" means any enemy whose data has the tag `goblin`. Goblin King Chad and the Goblin Bouncer have that tag, so a Pledge never calls while either of them is alive.

Answer:

**G36. When do summoned enemies join and act?** This covers the Pledge's call, Shot-Caller's replacement and Chad's Rush.
- Suggested (as built): each new enemy joins at the right end of the fight.
- It has no intent until the next turn's intents, so it first acts the turn after it arrives.

Answer:

**G37. Keg Slime's split.** "At half HP, splits into two Foam Slimes with 10 HP each."
- Suggested (as built): it checks for a split after the card or enemy action that did the damage, not in the middle of a multi-hit. It splits when it is above 0 HP and at or below half its max HP.
- A hit that kills it outright leaves nothing.
- The halves are fresh: no statuses, Ick or Guard carry over. They take the Keg Slime's position.
- If it splits during the player phase, the halves pick intents at once and act that turn.

Answer:

**G38. Dorm Rats fleeing.** "They flee on turn 4 with what they stole."
- Suggested (as built): fleeing is the rat's action in turn 4's enemy phase. Its intent is shown at turn 4's start.
- A rat that is Grossed Out on turn 4 flees one turn later.
- A fight where every remaining enemy fled ends as "won".
- The haul is tracked per player. A Passed Out Dude still gets their Dolla Bills back when a rat is killed.

Answer:

**G39. Does stealing ignore Guard?** "Each bite steals 5 Dolla Bills."
- Suggested (as built): yes. The steal happens whatever Guard the Dude has; only the bite's damage meets Guard.

Answer:

**G40. Boo-zer's Faded.** "Every other turn it is Faded and takes at most 1 damage per hit."
- Suggested (as built): the cap (`FADED_MAX_DAMAGE`) applies to every hit, attack or not, thorns included. It applies after damage order step 5's rounding and before Guard.
- Faded is a status with 1 stack, switched at the start of each turn, and it never wears off by itself.
- Which turn the cycle starts on is left to the data (Agent B's task 010).

Answer:

**G41. Kobold RA's Noise Complaint.** "5 damage to a player who plays 5 or more cards in a turn."
- Suggested (as built): it fires once per turn, right after the player's 5th card resolves.
- It is not attack damage (G3), and Guard absorbs it.
- Each Kobold complains once.
- It still fires while the Kobold is waiting to skip an action (Grossed Out).

Answer:

**G42. Sewer Gator: when does its Swole arrive?** "Gains 2 Swole whenever it deals unblocked damage."
- Suggested (as built): 2 Swole for each hit that got past Guard. It is added after the whole Death Roll, so the roll's own hits use the old Swole. Three unblocked hits give +6 for next time.

Answer:

**G43. Goblin Shot-Caller's turn.**
- Suggested (as built): on its every-other turn it first replaces a dead Pledge if fewer than 2 are standing; otherwise it gives Swole.
- "All goblins" includes the Shot-Caller itself.
- Its escort Pledges stand to its right.

Answer:

**G44. Goblin King Chad's priorities.**
- Suggested (as built), highest first:
  1. a charge already in progress;
  2. Keg Stand (when 2 Pledges are standing);
  3. Rage Cage (below 50% HP);
  4. Rush (every third turn);
  5. Paddle Swat.
- So below 50% HP, with 2 Pledges up, he still starts a Keg Stand.
- Below 50% HP he never Rushes. This changes the GDD's "every third turn" for that phase.

Answer:

**G45. Keg Stand's timing and lifters.**
- Suggested (as built): the charge starts when he picks his intent. The start turn and the next turn are the 2 charging turns, and the hit is the third turn's intent.
- The lifters are the first 2 Pledges, left to right, when the charge starts. A Pledge summoned later doesn't lift, and its death doesn't count.
- A lifter killed at any time from the start turn's intent until the hit removes 10 from the hit.

Answer:

**G46. "Kill both and he falls."**
- Suggested (as built): the moment the second lifter dies, the charge ends and he gains Exposed 2.
- He skips his next action, which is the current turn's charging or hitting action.
- His next intent after that is chosen normally.

Answer:

**G47. Grossed Out on Keg Stand's hit turn.**
- Suggested (as built): the skip wastes the hit, and the charge still ends.

Answer:

## Smaller interpretations made while building (tasks 013, 015, 017 and 021)

Agent B listed these in the review of #50 as not yet recorded anywhere a person would see them. Each is built as described.

**G48. Snap City's "now Armless".** An enemy that was already Armless before the hit still counts as "now Armless".
Answer:

**G49. When do thorns fire?** Thorns fire even when Guard absorbs the whole hit. They also fire after the hit Passes Out the Dude.
Answer:

**G50. The Bro Move.** The Bro Move is not a card play. It ignores Detention's limit and does not fill the Bro Meter.
Answer:

**G51. Stat floors.** Gear and Brew stat changes (`gain_stat`) stop at a floor for some stats:
- `max_hp` never goes below 1. Lowering max HP below current HP lowers HP too.
- `hype_per_turn`, `draw_per_turn` and `brew_slots` never go below 0.
- Swole, Chill and Clout have no floor.

Answer:

**G52. Fight-only stats after a loss.** Stat changes that last for one fight (Protein Shake) are reverted when the fight ends, whether it was won or lost.
Answer:

## Found while guarding Power triggers (task 031)

Agent B's review of #50 noted that a Power can set itself off. Built as suggested so data can never
hang a fight; answered below.

**G53. Powers that set each other off: how deep may a chain go?** Power trigger effects can set off
more triggers, and the GDD says nothing about a limit. Reply Guy's Ick can Gross Out an enemy, which
fires Friend Zone: a legitimate chain of 2. A Power that feeds itself (for example "whenever an
enemy gains a buff, it gains 1 Swole", which is another buff) would fire forever and hang the game.
No slice card does this, but content could.
- Suggested (as built in task 031): at most `MAX_TRIGGER_DEPTH` triggers nest in one chain,
  suggested value 8 (`data/constants.json`). A trigger set off by a card, enemy move, Brew, Gear
  trigger or the start of a turn is depth 1; a trigger set off by its effects is depth 2; and so
  on. Past the cap, effects still happen but set off no further trigger, silently (no event).
- A draw inside a trigger stays in the same chain: a card drawn that way runs its `on_draw` at
  that trigger's depth.
- Each event sets off each matching trigger once (task 031 also fixed a draw's `on_draw` events
  setting triggers off twice).
- Alternatives: a smaller or larger cap; a once-per-op limit (each Power fires at most once per
  card or move, however the chain loops); or a content rule (no Power may react to what its own
  effects cause), checked by data validation instead of the core.
Answer: accept, with `MAX_TRIGGER_DEPTH` = 8 (steamjgrube, Person B, 2026-10-10: "go with all defaults";
approved in the review of #53 and recorded in `docs/proposals/decision-log.md`, #54).

## Found while building the run flow (task 025)

G14–G26 answer most of the run. Each gap below is a point the GDD and those answers leave open; each
is built as suggested (the most conservative reading found) so the slice can run, and each is one
data or small code change if the people answer differently. None is answered yet.

**G54. "Upgrade 2 random cards" with fewer than 2 that can be upgraded** (The Unlabeled Brownie).
Lift and the Brownie only upgrade cards whose upgrade is not empty (G15), and today only Arm Bar has one.
Suggested (as built): upgrade as many as can be (0, 1 or 2), drawn on the `side_quest` stream; the
2 Foggy still applies.
Answer:

**G55. What may be skipped, and what may repeat.**
- Suggested (as built): a card reward may be skipped (`choose_reward` -1, GDD); the Boss Gear pick
  ("1 of 3 Boss Gear"), The Tailgate ("Nap or Lift") and a Side Quest (it has a safe option) may not.
- Which Side Quest a node holds is drawn on the `side_quest` stream (the GDD's stream for "gambles and
  random outcomes"; `encounters` is for enemies). Side Quests and encounters may repeat on a floor:
  the GDD has no rule against it.
Answer:

**G56. What card, Gear and Brew offers draw from.**
- Suggested (as built): card offers draw from the Dude's own pool only ("from their own Dude's
  pool"); neutral cards are never offered, because the GDD does not say where they appear. Starter
  and special cards are never offered or sold.
- One offer never shows the same card twice. Each slot draws a rarity with G21's odds among the
  rarities that still have a card left, so a pool with no rare card never offers one.
- Baileys cards use the same odds as card rewards (G21 gives odds for rewards only).
- Gear (Loot, Rival rewards, Baileys, 3 a.m. Tattoo) and Brews (Brawl rewards, Mimic drops, Baileys)
  have no rarity odds in the GDD: each is drawn equally likely. Baileys never stocks the same item twice.
Answer:

**G57. Rounding of "30% of max HP".** Nap heals `TAILGATE_NAP_HEAL` of max HP; a Passed Out Dude wakes
at `REVIVE_HP_FRACTION` of max HP after a won fight. Suggested (as built): both round down, like the
damage order; a revived Dude wakes with at least 1 HP.
Answer:

**G58. Brews that come from fights.**
- Suggested (as built): a Mimic Cooler fight at a Loot node gives only the Brew it drops: no Loot Gear
  (G19 says it *replaces* the Loot) and no Brawl reward.
- Dropped Brews (`combat.brews_dropped`) go to every Dude, each drawn from their own `rewards` stream.
- A Brew reward with every Brew slot full is lost (`brew_not_kept`); there is no swap screen. At
  Baileys a Shake with every slot full cannot be bought.
Answer:

**G59. Co-op rules the run flow does not build yet** (networking is out of scope, but these are
written down so they are not forgotten).
- "Gear: One Gear per player from Rival fights and Loot nodes, drafted in turn. First pick rotates
  each time." Built: each player gets their own random Gear from their own stream; `gear_first_pick`
  never changes.
- "Players can Spot a teammate any amount at Baileys": not built.
- `EXTRA_ENEMY_PARTY_SIZE` ("Brawls gain one enemy" at 3 players): which enemy is not stated; not built.
- The Designated Driver "rotates each floor": only floor 1 exists.
Answer:

**G60. Removing more than one card per Baileys visit.** GDD: "Remove a card: 75, rising by 25 each
time". Suggested (as built, as written): a Dude may remove again at the same visit, at the risen price.
(Slay the Spire allows one removal per shop; say so if that is wanted.)
Answer:

**G61. Is "Goblin Pledge + Skeleton Intern" an early Brawl?** G19: "the first two Brawls only use
Pledges, Bouncer or Intern". Suggested (as built in the test fixtures): yes, a group made only of
those enemies is early. The content lane marks it with `"early": true` in `data/encounters/`.
Answer:
