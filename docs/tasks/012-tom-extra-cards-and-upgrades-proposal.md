---
id: 012
title: Proposal - Tom's new slice cards and an upgrade for every Tom card
lane: content
owner: B
status: in_review
branch: b/012-tom-cards-proposal
depends_on: [006]
blocked_on: []
files:
  - docs/proposals/tom-slice-cards.md
  - docs/tasks/          # only for the follow-up tasks, after both people have answered
---

## Goal

A proposal, `docs/proposals/tom-slice-cards.md`, with the new Tom cards that take the slice to about
30 cards (16 if G14's suggested default is accepted) and an upgrade value for every Tom card, so
Lift works on the whole deck. **No card data is written in this task.** Card files wait until both
people have answered the proposal.

## Read first

GDD "Tom, the Enforcer" (card table, "How Tom plays", "Build directions"), "Card types and keywords",
"Built for teams" (Assist, about 1 card in 6), "Rules for writers", "Example card definition",
"Card definition fields"; G14 and G15 in `docs/proposals/solo-slice-rule-gaps.md`; task 006's card
files and `core/ops/README.md` (from task 007), so the proposal knows which ops already exist.

## Acceptance checks

- [ ] `docs/proposals/tom-slice-cards.md` exists with the header of `solo-slice-rule-gaps.md`: author, status "waiting for answers", GDD version read, a "Why" section, and an `Answer:` line under every card and every upgrade group.
- [ ] One row per new card, as many as G14's answer says: `id` (`tom_<name>`), name, type, cost, rarity, target, effect text in the GDD's wording style, the ops it needs, and which build direction it serves (Orthopedic Surgeon, Repellent or Head First).
- [ ] A count of the full Tom pool by rarity (starter, common, uncommon, rare) and by type, with the 14 GDD cards included, and a count of Assist cards against the GDD's "about 1 card in 6".
- [ ] An upgrade for every Tom card (the 14 GDD cards and every new one), written as the card's `upgrade` field paths, e.g. `{"effects[0].amount": 11}`. Arm Bar's is exactly the GDD's (8 to 11 damage).
- [ ] Every op used appears in `core/ops/README.md`, or is listed in a section "Ops this needs from Agent A" with its fields and meaning. No new status, keyword or rule is introduced; anything that would need one is listed as a question instead.
- [ ] Every card has a one-line note saying who the joke lands on (Tom, a monster or an institution).
- [ ] `grep -inwE "girl|girls|woman|women|lady|ladies|she|her|chick|babe" docs/proposals/tom-slice-cards.md` prints nothing.
- [ ] `grep -inE "firefly|dragon quest|warhammer|dungeons" docs/proposals/tom-slice-cards.md` prints nothing.
- [ ] `git diff --name-only main` lists only the proposal and this task's `docs/changes/` file; nothing under `data/`.

## Notes

- Ick is repellence that works on every enemy alike: unwanted opinions, bad lines, long replies.
  Tom thinks it is charisma. Never write it as hostility toward women, and keep lines non-sexual
  (Pickup Line already sits close to that edge; new cards should not go further).
- Every number in the proposal is a starting value for the people to accept or change. Say so in the
  "Why" section; do not argue balance as settled.
- Head First has only Skull Bash and Pickup Line today. "HP-based payoffs" needs a condition op on
  Tom's own HP, which does not exist yet; list it as an op request rather than designing around it.
- Chest Bump (the Bro Move) and Junk are not counted in the 30 if G14's default holds. Whether the Bro
  Move gets an upgrade is not in G15; ask rather than propose one silently.
- After both people answer: write a content task (next free even id, 028 or above) for the card
  files, and, if new ops were approved, a core task for Agent A with the exact ops and fields.

## Log
- 2026-10-10 B: Claimed. Every gap in `blocked_on` is answered (steamjgrube accepted all defaults; see `docs/proposals/decision-log.md`). Starts once task 006 merges (depends_on).
- 2026-10-10 B: Proposal written: `docs/proposals/tom-slice-cards.md`, waiting for both people's
  answers. 16 new cards (6 common, 6 uncommon, 4 rare), an upgrade for all 30 Tom cards (Arm Bar
  exactly the GDD's), pool counts by rarity, type and build, an Assist count (1 of 30), a joke line
  per card, and three requests for Agent A (`ally` targets, a `self_damaged` Power trigger,
  `damage_from_missing_hp`). 13 of 16 cards use only existing ops. Started from the draft in closed
  PR #2, redone against the ops task 013 built. Both greps in the checks print nothing. Not ticked:
  "`git diff --name-only main` lists only the proposal" holds once 006 (#59) merges, since this
  branch stacks on it. After the answers: a content task (even id ≥ 028) for the card files, and a
  core task for any accepted new op.
