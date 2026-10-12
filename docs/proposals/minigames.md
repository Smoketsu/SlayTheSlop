# Proposal: Side Quests become party minigames

- Author: Agent A, at Smoketsu's request (2026-10-12): "a small proposal for one of the nodes to be
  like minigames, possibly converting the side quest into mario party style minigames. I think it
  will give the game a lot of identity."
- Status: **open.** This changes the design, so it needs Smoketsu and steamjgrube to answer M1–M7.
  The GDD is not edited; if accepted, the owner updates it.
- GDD version read: 0.5 ("Node types", "Example Side Quests", "Rules that change in co-op", "Random
  streams", "Tone and humor")

## The idea in one paragraph

A Side Quest node stays a "safe or dumb" choice, because that choice is the joke. But the dumb
option stops being a coin flip and becomes a 15–30 second minigame: sink the cups, trace the tattoo,
carry the couch up the stairs. How well you play decides the outcome, on a ladder from "nailed it" to
"catastrophe". In co-op every player who went dumb plays the same minigame at the same time, Mario
Party style. Everyone gets their own result, and the best score gets a bonus while the worst gets a
little extra punishment. Players who went safe watch and heckle with emotes.

## Why this shape

- **Keeps what works.** Each Side Quest is still one data file with a safe and a dumb option. The
  five GDD Side Quests become the first five minigames, so no content is thrown away.
- **Gives the node identity.** The map gets a node you look forward to that isn't a fight, a shop or
  a rest. In co-op it is the part that creates stories ("he missed every cup").
- **Fits the architecture.**
  - The rules core stays pure: it never runs a real-time game.
  - The minigame is played in the client and produces a single bounded integer, its **score**.
  - The client sends the score as a request. The core turns score into effects using tiers written in
    data, so the reward logic stays deterministic, testable and the same for the bots.
  - The minigame's layout (cup positions, the tattoo shape, the falling snacks) is seeded from the run's
    `side_quest` stream. Everyone gets the same layout, and a replay is reproducible given the scores.

## Proposed rules

1. **Choosing.** As today: each player picks safe or dumb for themselves (GDD co-op rule). Picking
   dumb still counts toward `dumb_options_taken`.
2. **Playing.**
   - Players who picked dumb play the Side Quest's minigame together, for a fixed time.
   - Solo, it is you against the target tiers.
   - Controls are one button or the mouse, so it works for anyone, and a practice screen shows the
     controls first.
3. **Scoring.**
   - Each minigame reports a score from 0 to 100.
   - The Side Quest's data maps score bands to effect lists, for example:
     - 0–24: "Disaster";
     - 25–59: "Meh";
     - 60–89: "Nice";
     - 90–100: "LEGENDARY".
4. **Co-op ranking.** If two or more players played, the top score also gets the band above theirs,
   called **Bragging Rights** (a small bonus: Dolla Bills or a Brew). The lowest score gets the
   Side Quest's **Loser** effect (usually a Junk card such as Hangover). Ties share.
5. **Skipping.** A player who skips a minigame gets the "Disaster" band. They picked dumb.
6. **No rerolls.** The `side_quest` stream rule stays: reloading a save cannot reroll a layout or
   an outcome.

## First five minigames (the GDD's Side Quests)

| Side Quest | Minigame | How it plays (15–30 s) | Bands (example) |
| --- | --- | --- | --- |
| The Beer Pong Table | **Beer Pong** | Aim and power with a timing bar; 6 throws at a cup triangle. Score = cups sunk | Disaster: lose 50 Dolla Bills and gain a Hangover. LEGENDARY: +100 Dolla Bills |
| Gas-Station Sushi | **Sushi Roulette** | A conveyor of sketchy rolls; tap only the least-sketchy ones before they pass. Memory and reflexes | Nice: heal 25. Disaster: Hungover for 3 turns next fight |
| 3 a.m. Tattoo | **Steady Hand** | Trace a tattoo outline with the mouse while the room spins. Score = accuracy | LEGENDARY: a random Gear. Disaster: a permanent Regret card ("it says MOM with three Ms") |
| Free Couch on the Curb | **Couch Carry** | Keep the couch balanced up three flights of stairs (left and right to balance, the stairs tilt) | Nice: full heal. Disaster: Bedbugs |
| The Unlabeled Brownie | **Munchies** | Catch falling snacks, dodge the sketchy ones; the screen gets foggier as you go | Nice: upgrade 2 random cards. Disaster: start the next fight with 2 Foggy |

All of the above follows "Rules for writers": the joke is on the Dudes, and weed and drinking
humour stays outside Baileys, where everything is Shake.

## What it needs (if accepted)

| Lane | Work |
| --- | --- |
| Contract (both people) | Side Quest shape: an optional `minigame` field on the dumb option (`{"game": id, "bands": [{"min": int, "label": text, "effects": [...]}], "bragging_rights": [...], "loser": [...]}`). A new request `minigame_score {reward_id, score: 0..100}`, and events for the bands and the ranking. Additive, so existing Side Quest files still load |
| Run (A) | Wait for every dumb player's score (with a host-side timeout in co-op, like the turn timer), map scores to bands, apply the ranking, reuse the existing Side Quest operations. Tests with fixed scores, and bots that submit a seeded score |
| Client (B) | A minigame framework: an intro card, a practice screen, a countdown, a play area seeded from the state, results with a ranking podium. Then the minigames themselves, two first (Beer Pong, Couch Carry), the rest after a playtest |
| Content (B) | Bands per Side Quest, in data |
| Art (B, task 063's guide) | A splash per minigame, plus small sprites |

A first slice is about one core task, one contract PR, the framework and two minigames, enough to
put in front of playtesters. The other three follow if it lands.

## Risks

- **Scope.** Each minigame is a small game. Cap them at one mechanic each, and reuse the framework.
- **Balance.** A skilled player can farm the good bands. Keep rewards near today's expected value,
  and let the bot balance sim (task 022) submit scores to check it.
- **Cheating in co-op.** A client could send 100. Same stance as the GDD on host trust: co-op, low
  incentive. A later version could have the host check a replay of inputs.
- **Accessibility.** Some players hate twitch games. M5 offers an option.

## Questions for the people

- **M1. Shape:** dumb option becomes a minigame (recommended), or a new node type ("Rager") beside
  Side Quests, or replace Side Quests entirely?
- **M2. Ranking in co-op:** Bragging Rights and a Loser effect (recommended), or purely individual
  results with no ranking?
- **M3. Players who picked safe:** spectate and emote (recommended), or join for a small prize?
- **M4. First two minigames:** Beer Pong and Couch Carry (recommended), or others?
- **M5. Accessibility:** an option to "auto-play" a minigame for a fixed "Meh" result?
- **M6. Timing:** build after milestone 3 (co-op works first), or a solo slice before it, so outside
  playtesters see it?
- **M7. Names:** the "LEGENDARY" band and the "Bragging Rights" and "Loser" labels are placeholders.
  Writers' choice.
