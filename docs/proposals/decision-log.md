# Decision log

Decisions the two people have made, with the date and who made them, so any of them can be
revisited later. Agent B keeps this file; either agent may add rows in its own PR.

**To revisit a decision:** change its row's `Revisit?` cell to a short note (or open a proposal),
then the owning agent changes the code or data in its own lane.

## 2026-10-10: every suggested default accepted

steamjgrube (Person B), 2026-10-10: "go with all defaults and log decisions for later".
Smoketsu (Person A) had already accepted G1–G31. So every gap below now stands at its suggested
default, agreed by both people, and the code on `main` is built that way. Nothing here is
final: each row can be reopened.

| Id | Question | Default now in force | Source | Revisit? |
| --- | --- | --- | --- | --- |
| G1 | When does "1 stack per turn" wear off? | at the end of the bearer's own turn. Dudes lose a stack at End of turn (step 4); each enemy loses a stack right after it acts in the enemy phase. Foggy, which matters at Refresh, loses its stack after the Refresh it affected. | `solo-slice-rule-gaps.md` | |
| G2 | Does Guard get used up? | yes. Guard absorbs damage and is reduced by the amount absorbed. | `solo-slice-rule-gaps.md` | |
| G3 | What counts as "attack damage" | only `damage` effects on Attack cards, Bro Moves and enemy attack moves. Self-damage (Skull Bash, Pickup Line), Burn, Bedbugs, Chrome Dome's glare and Noise Complaint ignore them. | `solo-slice-rule-gaps.md` | |
| G4 | Hungover rounding. | add Chill first, then multiply, then round down (the same order the damage list uses). | `solo-slice-rule-gaps.md` | |
| G5 | Clout and Ick. | once per application. "Apply 2 Ick" with 1 Clout applies 3. "Apply 4 Ick to all enemies" applies 4 + Clout to each enemy. | `solo-slice-rule-gaps.md` | |
| G6 | Grossed Out timing. | checked as soon as Ick is applied. At or above the threshold, Ick resets to 0, the threshold rises by `ICK_THRESHOLD_STEP`, and the enemy skips its next action. Its current intent is shown as skipped. Ick applied while it is already waiting to skip still… | `solo-slice-rule-gaps.md` | |
| G7 | Armless. | when its last arm breaks, the enemy's next move that deals damage is skipped (non-attack moves still happen). Breaking arms on an enemy with `arm_count` 0, or past its count, does nothing. | `solo-slice-rule-gaps.md` | |
| G8 | Empty draw pile and hand size. | when the draw pile is empty and a draw is needed, shuffle the discard pile (with the player's `shuffle` stream) into the draw pile. If both are empty, the draw does nothing. No hand size limit in the slice. | `solo-slice-rule-gaps.md` | |
| G9 | Chrome Dome: | per hit, so Sewer Gator's Death Roll (3 hits) takes 9. | `solo-slice-rule-gaps.md` | |
| G10 | Reply Guy: | Swole and Guard gained by an enemy, and any later status marked as a buff. Healing is not a buff. | `solo-slice-rule-gaps.md` | |
| G11 | Enemy moves. | the rule applies to random choice only; scripted patterns are written as data and followed exactly. | `solo-slice-rule-gaps.md` | |
| G12 | Chad's ordinary turn. | turn 1 Keg Stand starts if he has 2 Pledges. Otherwise he alternates Rush on every third turn with a 12-damage "Paddle Swat" on other turns. He starts Keg Stand whenever 2 Pledges are alive and he is not already charging. The 12 and the swat are invented… | `solo-slice-rule-gaps.md` | |
| G13 | Does Chad start with Pledges? | yes, 2 Goblin Pledges, like Goblin Shot-Caller. | `solo-slice-rule-gaps.md` | |
| G14 | "About 30 cards". | = 14 existing Tom + 16 new Tom cards (Junk and the Bro Move not counted). New cards come to you as a proposal (task 012) first. | `solo-slice-rule-gaps.md` | |
| G15 | Upgrades. | task 012 proposes upgrade values for all Tom cards for you to approve; until then Lift is only offered for cards with an upgrade. | `solo-slice-rule-gaps.md` | |
| G16 | Which 10 Gear. | Unused Gym Membership (starting), Arm Wrestling Table, Whole Can of Body Spray, Lifting Belt, Lucky Lighter, Gallon Jug, Backwards Cap, Participation Trophy, Championship Ring, Medical Card; plus the 3 Boss Gear as Chad's reward (13 in total). | `solo-slice-rule-gaps.md` | |
| G17 | Junk card rarity and pools. | add rarity `special` for Junk and Bro Move cards (never offered as rewards or in the shop), and add owner `ethan` when Ethan is built. | `solo-slice-rule-gaps.md` | |
| G18 | Map shape. | rows plus a boss row, 2–4 nodes per row, each node linking to 1–2 nodes in the next row. Row 1 is always Brawls and the row before the boss is always The Tailgate. Shares are rounded to whole nodes per floor. | `solo-slice-rule-gaps.md` | |
| G19 | Encounters. | Brawls draw from {Goblin Pledge ×2, Goblin Bouncer, Keg Slime, Dorm Rats ×3, Skeleton Intern, Boo-zer, Kobold RA, Goblin Pledge + Skeleton Intern}; the first two Brawls only use Pledges, Bouncer or Intern. Rivals are one of the three floor 1 Rivals. Mimic… | `solo-slice-rule-gaps.md` | |
| G20 | Starting Dolla Bills. | Starting Dolla Bills. | `solo-slice-rule-gaps.md` | |
| G21 | Card reward rarity odds, and prices "by rarity". | rewards 60% common, 35% uncommon, 5% rare; Baileys cards 50 / 75 / 150, Gear 150 / 225 / 300 (common / uncommon / rare); Shake 50 (common), 65 (uncommon), 75 (rare). Baileys stock: 5 cards, 2 Gear, 2 Shake. | `solo-slice-rule-gaps.md` | |
| G22 | Run numbers that are not in the constants table. | These GDD numbers will be added to `data/constants.json` under these names unless you prefer others (additive, no rule change): `BASE_BREW_SLOTS` 3, `CARD_REWARD_CHOICES` 3, `BRAWL_DOLLA_MIN` / `_MAX` 10 / 20, `BRAWL_BREW_CHANCE` 0.4, `RIVAL_DOLLA_MIN` /… | `solo-slice-rule-gaps.md` | |
| G23 | Betting more than you have. | the dumb option is not offered below 50 Dolla Bills. | `solo-slice-rule-gaps.md` | |
| G24 | "A random Gear" | the same pool as Loot nodes (general and the Dude's own Gear, not Boss Gear, nothing already owned), using the `side_quest` stream. | `solo-slice-rule-gaps.md` | |
| G25 | "Start the next fight with ..." | the status is stored as pending on the Dude and applied when the next fight starts. This needs a new Dude state field; Agent A adds it in a contract PR. | `solo-slice-rule-gaps.md` | |
| G26 | Medical Card's 20% off. | it applies to every Baileys price including removal; round down. | `solo-slice-rule-gaps.md` | |
| G27 | What is a debuff? | Exposed, Noodle Arms, Hungover and Foggy. Broken Arm and Ick are on enemies only and never count. | `solo-slice-rule-gaps.md` | |
| G28 | Rarity of starting and Boss Gear. | rarity `starter` for starting Gear and `boss` for Boss Gear; neither is ever offered at Baileys or as Loot. | `solo-slice-rule-gaps.md` | |
| G29 | Does Baileys say which Brew a Shake is? | yes, by name and effect; "Shake" is only the shop's label. Also note that the Brew "Protein Shake" will sit under a "Shake" label; the people may want to rename one of them. | `solo-slice-rule-gaps.md` | |
| G30 | When does an enemy's Guard reset? | an enemy's Guard drops to 0 at the start of its own action in the enemy phase, before it acts. | `solo-slice-rule-gaps.md` | |
| G31 | How do the node shares and the fixed rows fit together? | apply the GDD shares to the whole floor (rows 1..7, not the entrance or the boss), round by largest remainder with ties in GDD table order, and count the fixed rows toward their type. Because a pre-boss row of 4 Tailgates would exceed the 12% share, the… | `solo-slice-rule-gaps.md` | |
| G32 | Friend Zone: which Grossed Out enemies become Exposed? | (a). Exposed 2 = 2 stacks, so it lasts through 2 of the players' turns. Reading (b) is a data change in the card (an `if` condition on the second effect). | `solo-slice-rule-gaps.md` | |
| G33 | Chest Bump's 20 damage: one enemy or all? | the 20 damage goes to one enemy the player picks, and the arm break to every enemy. The `use_bro_move` request therefore carries an optional `target_id`; the client (task 018) must send it, or the request is refused as `bad_target`. | `solo-slice-rule-gaps.md` | |
| G34 | Powers: duplicates and Passed Out Dudes. | every copy played works on its own (two Reply Guys apply 2 Ick twice), and a Passed Out Dude's Powers do not fire until he wakes. | `solo-slice-rule-gaps.md` | |
| G35 | Goblin Pledge: when does it check "last goblin standing", and what counts as a goblin? | it checks when it picks its intent (turn flow step 1), so the players see the call coming. The call replaces its hit that turn. It can call again every time it is the last goblin; there is no once-per-fight limit. "Goblin" means any enemy whose data has… | `solo-slice-rule-gaps.md` | |
| G36 | When do summoned enemies join and act? | each new enemy joins at the right end of the fight. It has no intent until the next turn's intents, so it first acts the turn after it arrives. | `solo-slice-rule-gaps.md` | |
| G37 | Keg Slime's split. | it checks for a split after the card or enemy action that did the damage, not in the middle of a multi-hit. It splits when it is above 0 HP and at or below half its max HP. A hit that kills it outright leaves nothing. The halves are fresh: no statuses, Ick… | `solo-slice-rule-gaps.md` | |
| G38 | Dorm Rats fleeing. | fleeing is the rat's action in turn 4's enemy phase. Its intent is shown at turn 4's start. A rat that is Grossed Out on turn 4 flees one turn later. A fight where every remaining enemy fled ends as "won". The haul is tracked per player. A Passed Out Dude… | `solo-slice-rule-gaps.md` | |
| G39 | Does stealing ignore Guard? | yes. The steal happens whatever Guard the Dude has; only the bite's damage meets Guard. | `solo-slice-rule-gaps.md` | |
| G40 | Boo-zer's Faded. | the cap (`FADED_MAX_DAMAGE`) applies to every hit, attack or not, thorns included. It applies after damage order step 5's rounding and before Guard. Faded is a status with 1 stack, switched at the start of each turn, and it never wears off by itself. Which… | `solo-slice-rule-gaps.md` | |
| G41 | Kobold RA's Noise Complaint. | it fires once per turn, right after the player's 5th card resolves. It is not attack damage (G3), and Guard absorbs it. Each Kobold complains once. It still fires while the Kobold is waiting to skip an action (Grossed Out). | `solo-slice-rule-gaps.md` | |
| G42 | Sewer Gator: when does its Swole arrive? | Swole for each hit that got past Guard. It is added after the whole Death Roll, so the roll's own hits use the old Swole. Three unblocked hits give +6 for next time. | `solo-slice-rule-gaps.md` | |
| G43 | Goblin Shot-Caller's turn. | on its every-other turn it first replaces a dead Pledge if fewer than 2 are standing; otherwise it gives Swole. "All goblins" includes the Shot-Caller itself. Its escort Pledges stand to its right. | `solo-slice-rule-gaps.md` | |
| G44 | Goblin King Chad's priorities. | a charge already in progress; Keg Stand (when 2 Pledges are standing); Rage Cage (below 50% HP); Rush (every third turn); Paddle Swat. So below 50% HP, with 2 Pledges up, he still starts a Keg Stand. Below 50% HP he never Rushes. This changes the GDD's… | `solo-slice-rule-gaps.md` | |
| G45 | Keg Stand's timing and lifters. | the charge starts when he picks his intent. The start turn and the next turn are the 2 charging turns, and the hit is the third turn's intent. The lifters are the first 2 Pledges, left to right, when the charge starts. A Pledge summoned later doesn't lift,… | `solo-slice-rule-gaps.md` | |
| G46 | "Kill both and he falls." | the moment the second lifter dies, the charge ends and he gains Exposed 2. He skips his next action, which is the current turn's charging or hitting action. His next intent after that is chosen normally. | `solo-slice-rule-gaps.md` | |
| G47 | Grossed Out on Keg Stand's hit turn. | the skip wastes the hit, and the charge still ends. | `solo-slice-rule-gaps.md` | |
| G48 | Snap City's "now Armless". | An enemy that was already Armless before the hit still counts as "now Armless". | `solo-slice-rule-gaps.md` | |
| G49 | When do thorns fire? | Thorns fire even when Guard absorbs the whole hit. They also fire after the hit Passes Out the Dude. | `solo-slice-rule-gaps.md` | |
| G50 | The Bro Move. | The Bro Move is not a card play. It ignores Detention's limit and does not fill the Bro Meter. | `solo-slice-rule-gaps.md` | |
| G51 | Stat floors. | Gear and Brew stat changes (`gain_stat`) stop at a floor for some stats: `max_hp` never goes below 1. Lowering max HP below current HP lowers HP too. `hype_per_turn`, `draw_per_turn` and `brew_slots` never go below 0. Swole, Chill and Clout have no floor. | `solo-slice-rule-gaps.md` | |
| G52 | Fight-only stats after a loss. | Stat changes that last for one fight (Protein Shake) are reverted when the fight ends, whether it was won or lost. | `solo-slice-rule-gaps.md` | |
| I1 | Gallon Jug, "+8 Max HP". | Does current HP rise too? Built: no, only `max_hp` rises (a Dude at 80/80 is at 80/88). Data could add a `heal` 8 next to it. | `item-rule-gaps.md` | |
| I2 | Championship Ring, "Attacks that cost 2 or more Hype deal 4 more damage". | Per hit or per card, and where in the damage order? Built: +4 to the base damage of every hit, before Swole, so Noodle Arms, Broken Arm and Exposed apply to it (Double Arm Day 9×2 becomes 13×2). "X"-cost cards never count. | `item-rule-gaps.md` | |
| I3 | Whole Can of Body Spray, "the target takes 2 damage per stack applied". | Built: the stacks are the Ick actually added, Clout included (G5: "Apply 2 Ick" with 1 Clout applies 3, so 6 damage); one hit of 2 × stacks; not attack damage (G3: no Swole, no Exposed); it fires for Ick from Tom's cards, Brews and Gear, and also when that… | `item-rule-gaps.md` | |
| I4 | Order of end-of-fight Gear. | Built: Gear fires in the order it was gained, so Unused Gym Membership (starting) heals before Participation Trophy checks "below 50% HP". | `item-rule-gaps.md` | |
| I5 | Which fights count for "after every fight" / "end a fight". | Built: only won fights (a lost fight ends the run); a Passed Out Dude's Gear does not fire. | `item-rule-gaps.md` | |
| I6 | Party Bowl, "Every player heals 8 HP". | Built: Passed Out Dudes are not healed. | `item-rule-gaps.md` | |
| I7 | Beer Helmet, "Start each fight with a Hangover card in your draw pile". | the Hangover from Beer Helmet lasts this fight only; this needs a core-lane option on `add_card` (for example `"lasts": "fight"`), task 015's op. | `item-rule-gaps.md` | |
| I8 | Smelling Salts, solo. | Built: the save lasts until used or the fight ends; drinking a second one first does not stack (still one save). Co-op waking ("wake a Passed Out teammate at 25% HP") is not built; in co-op the Brew is refused as `unplayable` until it is. | `item-rule-gaps.md` | |
| I9 | Brew slots. | `dude_state.brews` is a packed list, so drinking slot 0 of [A, B] leaves [B] in slot 0. Built: any slot index with no Brew, including one past `brew_slots`, is refused as `empty_slot` (no separate reject code). | `item-rule-gaps.md` | |

**Accepting a default that is not built yet.** I7's default (Beer Helmet's Hangover lasts one fight
only) is not what `main` does today: `main` adds a run-long Hangover every fight. It needs a `lasts`
option on the core's `add_card` op (Agent A's lane) and then a data change in `beer_helmet.json`
(Agent B). Every other default above matches what is built.

## Other defaults accepted the same day

| Decision | Default now in force | Source | Revisit? |
| --- | --- | --- | --- |
| G53: trigger depth | `MAX_TRIGGER_DEPTH` = 8: Power triggers may nest at most 8 deep, so a self-feeding Power can't loop forever (Reply Guy → Gross Out → Friend Zone needs 2) | #53, task 031 | |
| G54: "Upgrade 2 random cards" with fewer than 2 upgradable | The Unlabeled Brownie upgrades as many as can be (0, 1 or 2), drawn on the `side_quest` stream; the 2 Foggy still applies | `solo-slice-rule-gaps.md`, #66, task 025 | |
| G55: what may be skipped or repeat | A card reward may be skipped (`choose_reward` -1); the Boss Gear pick, The Tailgate and a Side Quest may not. A node's Side Quest is drawn on the `side_quest` stream; Side Quests and encounters may repeat on a floor | `solo-slice-rule-gaps.md`, #66, task 025 | |
| G56: what offers draw from | Card offers come from the Dude's own pool only (no neutral, starter or special cards), never the same card twice in one offer, each slot drawing a rarity with G21's odds among rarities that still have a card; Baileys cards use the same odds; Gear and Brews are drawn equally likely, and Baileys never stocks the same item twice | `solo-slice-rule-gaps.md`, #66, task 025 | |
| G57: rounding "30% of max HP" | Nap's heal (`TAILGATE_NAP_HEAL`) and the revive HP (`REVIVE_HP_FRACTION`) both round down; a revived Dude wakes with at least 1 HP | `solo-slice-rule-gaps.md`, #66, task 025 | |
| G58: Brews from fights | A Mimic Cooler fight at a Loot node gives only its dropped Brew (no Loot Gear, no Brawl reward); dropped Brews go to every Dude, each from their own `rewards` stream; a Brew reward with every slot full is lost (`brew_not_kept`), no swap screen; at Baileys a Shake can't be bought with every slot full | `solo-slice-rule-gaps.md`, #66, task 025 | |
| G59: co-op run rules not built yet | Each player gets their own random Gear from their own stream and `gear_first_pick` never changes; Spotting at Baileys, `EXTRA_ENEMY_PARTY_SIZE`'s extra enemy and the Designated Driver's rotation are not built | `solo-slice-rule-gaps.md`, #66, task 025 | |
| G60: more than one removal per Baileys visit | Allowed, as the GDD is written: a Dude may remove again at the same visit at the risen price (75, +25 each time) | `solo-slice-rule-gaps.md`, #66, task 025 | |
| G61: is "Goblin Pledge + Skeleton Intern" an early Brawl? | Yes: a group made only of Pledges, Bouncer or Intern is early; the content lane marks it `"early": true` in `data/encounters/` | `solo-slice-rule-gaps.md`, #66, task 025 | |
| Data format | JSON, shaped like the GDD's example card, parsed with `core/schema/json_values.gd` (closes task 001's last open check) | `CLAUDE.md` Tech stack | |
| Junk: cards created mid-fight | A card with no `lasts` lasts the run, even when `add_card` creates it during a fight | #42 decision 1 | |
| Junk: Hangover from Beer Helmet | Superseded by I7's default: the Beer Helmet Hangover lasts one fight only | #42 decision 2 | |
| Junk: Hangover at Refresh | A Hangover drawn at Refresh costs Hype that same turn | #42 decision 3 | |
| Junk: Detention | Counts cards played before it reached the hand; several don't stack (smallest limit wins); the Bro Move is not counted | #42 decision 4 | |
| Junk: self-damage Pass Out | Bedbugs or Burn Passing Out the last Dude loses the fight at once; a Passed Out Dude's triggers don't run | #42 decision 5 | |
| Junk: fight-only cards | Removed when the fight ends, won or lost | #42 decision 6 | |

**G54–G61 are agreed by both people and built on `main`.** They were found while building the run
flow (task 025, #66), and #66 has merged, so `main` is built that way. steamjgrube (Person B)
accepted each default on 2026-10-10 ("go with all defaults and log decisions for later"). Smoketsu
(Person A) agreed through a standing instruction, "go with default for now on everything, I agree
with steamjgrube on all", relayed by Agent A in its review of #74 on 2026-10-10. Their `Answer:`
lines in `solo-slice-rule-gaps.md` are Agent A's to fill in.

## Decisions specific to Agent B's work

| Decision | What was decided | By | Revisit? |
| --- | --- | --- | --- |
| G14: the 30 cards | 30 = Tom's 14 GDD cards + **16 new Tom cards**. The new cards come to both people as a proposal first (task 012). This replaces steamjgrube's earlier "ditch the cards" (closed PR #2) | steamjgrube, 2026-10-10 ("we need those 16 new tom cards back") | |
| Enemy placeholders (task 010) | Values the GDD does not give, kept as Agent A's fixtures built them: Foam Slime hits for 3; Goblin Shot-Caller's ordinary move deals 10; "Checks ID" is the Goblin Bouncer's hit (not its Guard move); the Skeleton Intern's Paperwork turn also hits; Boo-zer's Faded cycle starts as in the fixture | default (steamjgrube: accept all defaults) | |
| G29: Shake and Protein Shake | Baileys shows each Brew's own name and effect; "Shake" is only the shop's label. The Brew "Protein Shake" keeps its name for now | default | |
