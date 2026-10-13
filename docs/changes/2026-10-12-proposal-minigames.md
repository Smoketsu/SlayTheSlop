# 2026-10-12 - Proposal: Side Quests become party minigames

Added `docs/proposals/minigames.md` (Agent A, at Smoketsu's request). It is a design proposal only,
with no code. It covers:
- the dumb option of a Side Quest becomes a 15–30 s minigame;
- the score (0–100) maps to bands of effects defined in data;
- co-op ranking with Bragging Rights and a Loser effect;
- five minigames drawn from the GDD's Side Quests;
- the work per lane, the risks, and questions M1–M7.

## Variables, fields and constants

None were added. The proposal describes an optional `minigame` field on a Side Quest's dumb option and
a `minigame_score` request, both to be added later in contract PRs only if it is accepted.
