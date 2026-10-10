# Proposal: rule gaps that block the solo slice

- Author: Agent A, task 001
- Status: **waiting for answers** from both people
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
Answer:

**G2. Does Guard get used up?** Step 5 says "subtract the target's Guard".
Suggested: yes. Guard absorbs damage and is reduced by the amount absorbed.
Answer: **accept** (Smoketsu, Person A, 2026-10-10). steamjgrube may object on this PR.

**G3. What counts as "attack damage"** for Exposed and Noodle Arms?
Suggested: only `damage` effects on Attack cards, Bro Moves and enemy attack moves. Self-damage
(Skull Bash, Pickup Line), Burn, Bedbugs, Chrome Dome's glare and Noise Complaint ignore them.
Answer:

**G4. Hungover rounding.** "Gains 25% less Guard from cards": Guard × 0.75, rounded how?
Suggested: add Chill first, then multiply, then round down (the same order the damage list uses).
Answer:

**G5. Clout and Ick.** Clout is "added to Tom's Ick". Once per application or once per stack?
Suggested: once per application. "Apply 2 Ick" with 1 Clout applies 3. "Apply 4 Ick to all
enemies" applies 4 + Clout to each enemy.
Answer:

**G6. Grossed Out timing.** Suggested: checked as soon as Ick is applied. At or above the
threshold, Ick resets to 0, the threshold rises by `ICK_THRESHOLD_STEP`, and the enemy skips its
next action. Its current intent is shown as skipped. Ick applied while it is already waiting to
skip still counts toward the new threshold.
Answer:

**G7. Armless.** "Loses its next attack, once per fight." Suggested: when its last arm breaks,
the enemy's next move that deals damage is skipped (non-attack moves still happen). Breaking arms
on an enemy with `arm_count` 0, or past its count, does nothing.
Answer:

**G8. Empty draw pile and hand size.** The GDD says neither.
Suggested: when the draw pile is empty and a draw is needed, shuffle the discard pile (with the
player's `shuffle` stream) into the draw pile. If both are empty, the draw does nothing. No hand
size limit in the slice.
Answer: **accept** (Smoketsu, Person A, 2026-10-10). steamjgrube may object on this PR.

**G9. Chrome Dome:** "enemies that hit Tom take 3 damage". Per hit or per attack?
Suggested: per hit, so Sewer Gator's Death Roll (3 hits) takes 9.
Answer:

**G10. Reply Guy:** "Whenever an enemy gains a buff". Which things are buffs?
Suggested: Swole and Guard gained by an enemy, and any later status marked as a buff. Healing is not a buff.
Answer:

**G11. Enemy moves.** "Never repeats one three times in a row": does that apply to scripted moves
too (Goblin Bouncer alternates)? Suggested: the rule applies to random choice only; scripted
patterns are written as data and followed exactly.
Answer:

## Goblin King Chad (blocks tasks 019, 010)

**G12. Chad's ordinary turn.** The GDD gives Rush (every third turn), Keg Stand (charge 2 turns,
then 30) and Rage Cage (below 50% HP). It does not say what he does on other turns above 50% HP,
or when Keg Stand starts.
Suggested: turn 1 Keg Stand starts if he has 2 Pledges. Otherwise he alternates Rush on every
third turn with a 12-damage "Paddle Swat" on other turns. He starts Keg Stand whenever 2 Pledges
are alive and he is not already charging. The 12 and the swat are invented and need your number.
Answer:

**G13. Does Chad start with Pledges?** Suggested: yes, 2 Goblin Pledges, like Goblin Shot-Caller.
Answer:

## Content counts (block tasks 006, 008, 012, 014)

**G14. "About 30 cards".** The GDD has 14 Tom cards and 6 Junk cards. Do the 30 include Junk and
the Bro Move? How many new Tom cards should be designed? Suggested: 30 = 14 existing Tom + 16 new
Tom cards (Junk and the Bro Move not counted). New cards come to you as a proposal (task 012) first.
Answer:

**G15. Upgrades.** Only Arm Bar has an upgrade (8 → 11 damage). Lift needs one for every card.
Suggested: task 012 proposes upgrade values for all Tom cards for you to approve; until then Lift
is only offered for cards with an upgrade.
Answer:

**G16. Which 10 Gear.** Suggested: Unused Gym Membership (starting), Arm Wrestling Table, Whole
Can of Body Spray, Lifting Belt, Lucky Lighter, Gallon Jug, Backwards Cap, Participation Trophy,
Championship Ring, Medical Card; plus the 3 Boss Gear as Chad's reward (13 in total).
Answer:

**G17. Junk card rarity and pools.** Junk cards have no rarity in the GDD's list
(`starter/common/uncommon/rare`), and the card owner list has no `ethan`.
Suggested: add rarity `special` for Junk and Bro Move cards (never offered as rewards or in the
shop), and add owner `ethan` when Ethan is built.
Answer:

## Run structure (block tasks 023, 025)

**G18. Map shape.** About 15 nodes with the share table. Suggested: 7 rows plus a boss row, 2–4
nodes per row, each node linking to 1–2 nodes in the next row. Row 1 is always Brawls and the row
before the boss is always The Tailgate. Shares are rounded to whole nodes per floor.
Answer:

**G19. Encounters.** Which enemy groups make up a floor 1 Brawl and Rival fight?
Suggested: Brawls draw from {Goblin Pledge ×2, Goblin Bouncer, Keg Slime, Dorm Rats ×3, Skeleton
Intern, Boo-zer, Kobold RA, Goblin Pledge + Skeleton Intern}; the first two Brawls only use
Pledges, Bouncer or Intern. Rivals are one of the three floor 1 Rivals. Mimic Cooler replaces a
Loot node 1 time in 4.
Answer:

**G20. Starting Dolla Bills.** Not stated. Suggested: 99.
Answer:

**G21. Card reward rarity odds, and prices "by rarity".** Suggested: rewards 60% common, 35%
uncommon, 5% rare; Baileys cards 50 / 75 / 150, Gear 150 / 225 / 300 (common / uncommon / rare);
Shake 50 (common), 65 (uncommon), 75 (rare). Baileys stock: 5 cards, 2 Gear, 2 Shake.
Answer:

**G22. Run numbers that are not in the constants table.** These GDD numbers will be added to
`data/constants.json` under these names unless you prefer others (additive, no rule change):
`BASE_BREW_SLOTS` 3, `CARD_REWARD_CHOICES` 3, `BRAWL_DOLLA_MIN` / `_MAX` 10 / 20,
`BRAWL_BREW_CHANCE` 0.4, `RIVAL_DOLLA_MIN` / `_MAX` 25 / 35, `TAILGATE_NAP_HEAL` 0.3,
`CARD_REMOVE_BASE` 75, `CARD_REMOVE_STEP` 25, `BRO_METER_SOLO_CARDS` 3.
Answer:

## Side Quests and items (block tasks 014, 016, 021, 025)

Found while writing the content tasks.

**G23. Betting more than you have.** The Beer Pong Table bets 50 Dolla Bills. Suggested: the dumb
option is not offered below 50 Dolla Bills.
Answer:

**G24. "A random Gear"** (3 a.m. Tattoo). From which pool? Suggested: the same pool as Loot nodes
(general and the Dude's own Gear, not Boss Gear, nothing already owned), using the `side_quest` stream.
Answer:

**G25. "Start the next fight with ..."** (Gas-Station Sushi, The Unlabeled Brownie). Suggested: the
status is stored as pending on the Dude and applied when the next fight starts. This needs a new
Dude state field; Agent A adds it in a contract PR.
Answer:

**G26. Medical Card's 20% off.** Does it apply to card removal, and how do prices round?
Suggested: it applies to every Baileys price including removal; round down.
Answer:

**G27. What is a debuff?** (Hair of the Dog, and Nate's later cards.) Suggested: Exposed, Noodle
Arms, Hungover and Foggy. Broken Arm and Ick are on enemies only and never count.
Answer:

**G28. Rarity of starting and Boss Gear.** Unused Gym Membership and the three Boss Gear have no
rarity in the GDD. Suggested: rarity `starter` for starting Gear and `boss` for Boss Gear; neither
is ever offered at Baileys or as Loot.
Answer:

**G29. Does Baileys say which Brew a Shake is?** Suggested: yes, by name and effect; "Shake" is
only the shop's label. Also note that the Brew "Protein Shake" will sit under a "Shake" label;
the people may want to rename one of them.
Answer:
