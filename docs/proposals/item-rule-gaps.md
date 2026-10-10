# Proposal: Gear and Brew rules the GDD does not state (task 021)

- Author: Agent A, task 021
- Status: **open.** Each item below is built as its suggested default, so the slice can run; a person
  answers "accept" or gives the rule, and Agent A changes the code if the answer differs.
- GDD version read: 0.5

Ids (I1, I2 ...) are stable; task files refer to them.

**I1. Gallon Jug, "+8 Max HP".** Does current HP rise too?
Built: no, only `max_hp` rises (a Dude at 80/80 is at 80/88). Data could add a `heal` 8 next to it.
Answer:

**I2. Championship Ring, "Attacks that cost 2 or more Hype deal 4 more damage".** Per hit or per card,
and where in the damage order? Built: +4 to the base damage of every hit, before Swole, so Noodle
Arms, Broken Arm and Exposed apply to it (Double Arm Day 9×2 becomes 13×2). "X"-cost cards never
count. Answer:

**I3. Whole Can of Body Spray, "the target takes 2 damage per stack applied".** Built: the stacks are
the Ick actually added, Clout included (G5: "Apply 2 Ick" with 1 Clout applies 3, so 6 damage); one
hit of 2 × stacks; not attack damage (G3: no Swole, no Exposed); it fires for Ick from Tom's cards,
Brews and Gear, and also when that Ick Grosses the enemy Out. Answer:

**I4. Order of end-of-fight Gear.** Built: Gear fires in the order it was gained, so Unused Gym
Membership (starting) heals before Participation Trophy checks "below 50% HP". Answer:

**I5. Which fights count for "after every fight" / "end a fight".** Built: only won fights (a lost
fight ends the run); a Passed Out Dude's Gear does not fire. Answer:

**I6. Party Bowl, "Every player heals 8 HP".** Built: Passed Out Dudes are not healed. Answer:

**I7. Beer Helmet, "Start each fight with a Hangover card in your draw pile".** Built as data: an
`add_card` of `junk_hangover` shuffled into the draw pile (`shuffle_in`) at `fight_start`. Problem:
Hangover is run-long Junk (task 015), so as written the run deck gains one Hangover per fight. Suggested:
the Hangover from Beer Helmet lasts this fight only; this needs a core-lane option on `add_card`
(for example `"lasts": "fight"`), task 015's op. Answer:

**I8. Smelling Salts, solo.** Built: the save lasts until used or the fight ends; drinking a second one
first does not stack (still one save). Co-op waking ("wake a Passed Out teammate at 25% HP") is not
built; in co-op the Brew is refused as `unplayable` until it is. Answer:

**I9. Brew slots.** `dude_state.brews` is a packed list, so drinking slot 0 of [A, B] leaves [B] in
slot 0. Built: any slot index with no Brew, including one past `brew_slots`, is refused as
`empty_slot` (no separate reject code). Answer:
