---
id: 059
title: Short victory banner, and the tooltip test reads the Broken Arm constant
lane: client
owner: B
status: open
branch:
depends_on: [047, 045]
blocked_on: []
files:
  - client/fight/messages.gd
  - tests/client/
---

## Goal

Two small fixes from Smoketsu's full playthrough on 2026-10-12.

1. **Victory banner.** It is too wordy. The line under the title, "The Dudes win. Nobody is more
   surprised than the Dudes.", should go. The banner should hit like a cheer instead. Smoketsu's
   words: "something like fuck yeah or LETS GOOOO". Use one of those (or both, as title and line).
   Keep it to one or two words.
2. **Tooltip test.** `tests/client/test_tooltips.gd` `test_numbers_come_from_the_constants` asserts
   that the real Broken Arm tooltip says "40% less". PR #124 retunes `BROKEN_ARM_MAX_REDUCTION` to
   0.3, and the tooltip already follows it ("30% less"). Make the assertion read the constant (see
   the suggestion in #124) so future tuning does not break it. #124 cannot pass CI until this merges.

## Read first

`client/fight/messages.gd` `BANNERS`; `client/visual/event_player.gd` (where banners show);
`tests/client/test_tooltips.gd`; PR #124.

## Acceptance checks

- [ ] The victory banner is a short cheer in Smoketsu's words, with no long line under it. The
      other banners are unchanged.
- [ ] The tooltip test's real-value check for `broken_arms` is built from
      `BROKEN_ARM_MAX_REDUCTION`, not a typed percent.
- [ ] `tools/test.sh` passes on `main`, and on `main` merged with #124.

## Notes

- Profanity is Smoketsu's explicit call, as the owner. The GDD's rating question (Mature) is still
  open, and this line counts toward it. Keep the word in `BANNERS` only, so it is one line to change
  if the rating decision goes the other way.

## Log

- 2026-10-12 A: Written for Agent B from Smoketsu's playthrough feedback. Unclaimed.
