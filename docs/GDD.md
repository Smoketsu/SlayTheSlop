# Dungeon Dudes — Game Design Document

Oct 10, 2026 · @Nate DeMarino

## Overview

Dungeon Dudes is a roguelike deckbuilder for 1–4 players online, in which five fantasy frat bros brawl through a frat-house crypt, a smoked-out den and a music festival, one bad decision at a time.

Players pick a Dude, build a deck during the run, and fight turn-based card battles against goblins, ghosts and worse. Death ends the run. Unlocks carry over.

| Item | Decision |
| --- | --- |
| Genre | Roguelike deckbuilder, turn-based |
| Players | 1–4, online co-op (solo fully supported) |
| Run length | 45–60 min solo, 60–90 min co-op |
| Platform | PC first; controller-friendly UI so console is possible later |
| Art | 2D, bold cartoon, readable at a glance |
| Content rating target | Mature: crude humor, alcohol and weed references, no nudity, no slurs |

### Design pillars

1. **Deckbuilding first.** Every joke sits on top of a rule that would be fun with the jokes removed.
2. **Better with the boys.** Co-op is designed in from day one: shared turns, team buffs, combos between Dudes.
3. **The Dudes are the punchline.** The humor is degenerate, and the Dudes are always the ones it lands on.
4. **Five Dudes, five games.** Each Dude has a signature mechanic no one else touches.

### Launch content targets

| Content | Launch target | In this document |
| --- | --- | --- |
| Playable Dudes | 5 | 5, with starter decks and sample cards |
| Cards | 60 per Dude + 20 neutral (320) | 14 per Dude |
| Gear (passive items) | 80 | 29 |
| Brews (single-use items) | 20 | 8 |
| Enemies | 24 normal + 9 Rivals (elites) | All 33 |
| Bosses | 7 (two per floor + final) | All 7 |
| Side Quests (events) | 30 | 5 examples |

## Tone and humor

The game laughs at the Dudes, never with them: they are confident, loud, wrong about everything, and somehow still winning.

The setting is a fantasy kingdom that works exactly like a college campus. The dungeon is under the frat house. The second floor is just a guy named Dylan's place. Nobody has done laundry since the Second Age.

### Where the degeneracy comes from

- **Bad decisions as mechanics.** Gambling Side Quests, gas-station sushi, 3 a.m. tattoos. The risky option is always the funny one.
- **Drinking and smoking as resources.** Brews are potions, edibles are a gamble, smoke makes everyone Foggy, and the final boss is the morning after.
- **Unearned confidence.** Card names and barks are the Dudes narrating their own greatness while getting bitten by a cooler.
- **Laziness.** Rest sites are a couch on a curb. Upgrading a card is "hitting the gym once".

### Rules for writers

- The butt of every joke is a Dude, a monster, or an institution. Never a real-world group of people.
- No slurs, no sexual content, no jokes that need a victim to work.
- Tom's "anti-female" kit is written as **repellence**: he is so off-putting that everything in the dungeon, of any gender or species, loses the will to fight. The mechanic is called Ick, and Tom thinks it is charisma.
- Each Dude gets about 40 short combat barks. Barks react to teammates in co-op, which is where most of the comedy lives.

### Glossary of themed terms

| Standard deckbuilder term | Dungeon Dudes term |
| --- | --- |
| Energy | Hype |
| Block | Guard |
| Gold | Beer Money |
| Relic | Gear |
| Potion | Brew |
| Elite | Rival |
| Event | Side Quest |
| Rest site | The Tailgate |
| Shop | Baileys |
| Exhaust | Tapped |
| Ascension level | Keg Level |

## Music and audio

Every floor has its own sound, and all of it is original music written in a style; no licensed tracks are assumed.

| Floor | Sound |
| --- | --- |
| The Basement | A house party heard through the ceiling: muffled bass and a bouncing ping-pong ball. In fights, the bass comes down into the room |
| Dylan's Keep | Slow stoner rock under the 8-bit overworld loop from Dylan's TV. Fight music is a chiptune battle theme. The victory jingle belongs to Dylan's game, not yours |
| Firefly Music Festival | The sound of a summer 2013 festival, changing with the stage you are at |
| The Drive Home | The car radio, turned down low because everyone has a headache. It keeps losing the station |

### Firefly stages

The real Firefly 2013 ran June 21–23 in The Woodlands at Dover International Speedway, Delaware. Red Hot Chili Peppers, Tom Petty and the Heartbreakers, Vampire Weekend and Foster the People headlined ([CBS News](https://www.cbsnews.com/news/2013-firefly-music-festival-lineup-unveiled/)). The rest of the bill mixed indie rock, synth-pop, folk revival, EDM and hip-hop ([full lineup](https://music.mxdwn.com/2013/02/21/news/firefly-music-festival-announces-2013-lineup-including-red-hot-chili-peppers-tom-petty-the-heartbreakers-vampire-weekend-and-more/amp/)).

Floor 3 borrows that mix. Each node type is a stage with its own genre.

| Node on floor 3 | Style | 2013 reference points for the composer |
| --- | --- | --- |
| Brawl (side stages) | Indie rock and synth-pop | Vampire Weekend, Passion Pit, MGMT, Yeah Yeah Yeahs |
| Rival (the big field) | Arena funk-rock and heartland rock | Red Hot Chili Peppers, Tom Petty and the Heartbreakers |
| Baileys and Side Quests | Hip-hop | Kendrick Lamar, Public Enemy, Action Bronson |
| The Tailgate (campground) | Stomp-clap folk on acoustic instruments | The Lumineers, The Avett Brothers, Edward Sharpe and the Magnetic Zeros |
| Boss (main stage) | Whatever the headliner plays: big-room EDM or a full folk band | Calvin Harris, Zedd, Krewella |

The real artists are style references only. No real act appears or is named in the game, and the festival bosses are invented.

## Run structure

A run is three floors of about 15 nodes each, then a final boss; the party picks a branching path and every node changes the deck, the wallet or the hit points.

### The loop

1. Pick a Dude (co-op: each player picks one; no duplicates by default).
2. Choose the next node on the floor map.
3. Resolve the node: fight, shop, rest or gamble.
4. Take the reward: a card, Beer Money, Gear or a Brew.
5. Repeat until the floor boss, then pick one of three Boss Gear and descend.
6. Win or pass out. Earn Rep either way, which unlocks new cards, Gear and Dudes.

### Floors

| Floor | Name | Flavor | Enemy theme |
| --- | --- | --- | --- |
| 1 | The Basement | Crypt under the frat house, sticky floors | Goblins, slimes, rats, one ghost |
| 2 | Dylan's Keep | A smoked-out den. Dylan is on the couch playing Dragon Quest and hitting a bong. He is not involved | Weed, boags, gym equipment, video games |
| 3 | Firefly Music Festival | A three-day festival in the woods, summer 2013 | Festival workers and attendees |
| Final | The Drive Home | The next day. One car, hours of highway, nobody feeling good. Consequences. | The Hangover |

### Node types

| Node | What happens | Share of a floor |
| --- | --- | --- |
| Brawl | Normal fight. Reward: 1 of 3 cards, 10–20 Beer Money, 40% chance of a Brew | 45% |
| Rival | Elite fight. Reward: a Gear, 25–35 Beer Money, 1 of 3 cards | 10% |
| Side Quest | A short choice with a safe option and a dumb option | 20% |
| The Tailgate | Nap (heal 30% of max HP) or Lift (upgrade one card) | 12% |
| Baileys | Buy cards, Gear and Brews; pay to remove a card | 8% |
| Loot | Free Gear from an unattended cooler | 5% |
| Boss | End of the floor. Reward: 1 of 3 Boss Gear, full heal | 1 per floor |

### Example Side Quests

| Side Quest | Safe option | Dumb option |
| --- | --- | --- |
| The Beer Pong Table | Walk away | Bet 50 Beer Money: 50% to double it, 50% to lose it and gain a Hangover card |
| Gas-Station Sushi | Skip it | Heal 25 HP; 35% chance to start the next fight with Hungover for 3 turns |
| 3 a.m. Tattoo | Go to bed | Gain a random Gear and a permanent Regret card |
| Free Couch on the Curb | Leave it | Full heal; 30% chance to add Bedbugs, a junk card that deals 1 damage when drawn |
| The Unlabeled Brownie | Politely decline | Eat it: upgrade 2 random cards, and start the next fight with 2 Foggy |

## Combat rules

Each turn a player draws 5 cards and spends 3 Hype to play them, while enemies show in advance what they will do and to whom.

### Turn flow

1. **Intents.** Every enemy shows its next action and, for attacks, which Dude it is aiming at.
2. **Refresh.** Each player's Guard drops to 0, Hype refills to 3, and they draw 5 cards.
3. **Player phase.** Players play cards. In co-op all players act at the same time.
4. **End of turn.** Unplayed cards are discarded. Puppets act. Auras and end-of-turn effects trigger.
5. **Enemy phase.** Enemies act left to right, then choose new intents.

### Stats

Every Dude has the same six stats. Gear and cards change them.

| Stat | Meaning | Base value |
| --- | --- | --- |
| Max HP | Hit points carried between fights | 62–80 by Dude |
| Swole | Added to every hit of every attack | 0 |
| Chill | Added to Guard gained from each card | 0 |
| Clout | Added to the Dude's signature effect: Tom's Ick, Cheney's Aura values, Nate's Bugs, Grube's Puppet actions, Ethan's Rolls | 0 |
| Hype per turn | Card-playing resource, refills each turn | 3 |
| Draw per turn | Cards drawn at Refresh | 5 |

### Damage order

1. Start with the card's base damage and add the attacker's Swole.
2. Multiply by 0.75 if the attacker has Noodle Arms.
3. Multiply by the Broken Arm reduction if the attacker is an enemy.
4. Multiply by 1.5 if the target is Exposed.
5. Round down, subtract the target's Guard, and remove the rest from HP.

### Statuses

| Status | On | Effect | Wears off |
| --- | --- | --- | --- |
| Exposed | Anyone | Takes 50% more attack damage | 1 stack per turn |
| Noodle Arms | Anyone | Deals 25% less attack damage | 1 stack per turn |
| Hungover | Dudes | Gains 25% less Guard from cards | 1 stack per turn |
| Foggy | Dudes | Draws 1 fewer card at Refresh | 1 stack per turn |
| Broken Arm (Tom) | Enemies | With k of n arms broken, attack damage is multiplied by 1 − 0.4 × k ÷ n. At n of n the enemy is Armless and loses its next attack, once per fight | Never |
| Ick (Tom) | Enemies | At its Ick threshold the enemy is Grossed Out: it skips its next action, Ick resets to 0, and its threshold rises by 3 | On trigger |
| Bugs (Nate) | Enemies | At the start of its turn the enemy takes damage equal to its Bugs | 1 stack per turn |

Ick thresholds start at 5 for normal enemies, 8 for Rivals and 12 for bosses. Most enemies have 2 arms. Slimes and some ghosts have none, so Tom needs both halves of his kit.

### Card types and keywords

| Term | Meaning |
| --- | --- |
| Attack | Deals damage |
| Skill | One-off effect: Guard, draw, debuff, summon |
| Power | Lasts the rest of the fight |
| Aura | Cheney only. A Power that affects every player. He holds 2 at a time; a third replaces the oldest |
| Junk | Unplayable or harmful card added by enemies and bad decisions: Hangover, Regret, Paperwork, Bedbugs, Burn |
| Tapped | After play, the card is removed for the rest of the fight |
| Pocketed | The card is not discarded at end of turn |
| Crunch N | Nate only. Strain N of his Abs for a bonus |
| Pull | Grube only. A Puppet takes its action immediately |
| Crash N | Ethan only. After the card resolves, his turn ends and he Naps for N turns |
| Roll | Ethan only. Roll a 20-sided die; the card says what each result does |
| Scaffolding | Ethan only. Guard that is not removed at Refresh, up to 25 |
| Assist | The card can target a teammate. In solo play it targets yourself |

### Bro Meter

The Bro Meter is a shared 0–10 gauge that rewards teamwork. It gains 1 whenever a player attacks an enemy that a different player debuffed this turn. In solo play it gains 1 for every third card played in a turn.

At 10, any one player may empty it to play their Dude's Bro Move for free.

| Dude | Bro Move | Effect |
| --- | --- | --- |
| Tom | Chest Bump | Deal 20 damage. Break 1 arm on every enemy |
| Cheney | Shots! Shots! Shots! | Every player gains 2 Hype and draws 2 cards |
| Nate | Ctrl+Alt+Delete | Every enemy loses all buffs and gains 5 Bugs |
| Grube | Encore | Fill every empty Puppet slot with a Pledge, then Pull all Puppets |
| Ethan | Natural 20 | Deal 20 damage to all enemies. His next Crash card this fight does not cause a Nap |

## Online multiplayer

Co-op is 2–4 players over the internet, each with their own Dude, deck, hand, Hype and HP, sharing one map, one fight and one Bro Meter.

### Rules that change in co-op

| Area | Rule |
| --- | --- |
| Turns | All players act at once in the player phase. Cards resolve in the order the host receives them |
| Ending the turn | The enemy phase starts when every player presses Ready or the turn timer ends (default 90 s, host can set 45 s to unlimited) |
| Enemy targeting | Each attack intent shows the portrait of the Dude it targets. Area attacks hit everyone |
| Hands | Teammates can see each other's hands and can ping a card to say "I'm about to play this" |
| Passing out | A Dude at 0 HP is Passed Out and skips turns. They wake at 30% HP if the team wins the fight. If everyone passes out, the run ends |
| Card rewards | Every player gets their own pick of 3 cards from their own Dude's pool |
| Beer Money | Earned and spent individually. Players can Spot a teammate any amount at Baileys |
| Gear | One Gear per player from Rival fights and Loot nodes, drafted in turn. First pick rotates each time |
| Map path | Players vote on the next node. Ties go to the Designated Driver, a role that rotates each floor |
| Side Quests | Each player chooses for themselves, so one Dude can get the tattoo while three watch |

### Difficulty scaling

Enemy HP grows more slowly than party damage, and extra bodies and extra attacks make up the difference.

| Players | Enemy HP multiplier | Extra enemies per Brawl | Targets of a single-target attack |
| --- | --- | --- | --- |
| 1 | 1.0 | 0 | 1 |
| 2 | 1.8 | 0 | 1 |
| 3 | 2.6 | 1 | 2 |
| 4 | 3.4 | 1 | 2 |

Ick thresholds scale with the HP multiplier, rounded up. Broken Arm does not scale, since arm counts are fixed.

### Built for teams

- **Assist cards.** Roughly 1 card in 6 can target a teammate: Guard, Hype, card draw, debuff removal.
- **Cross-Dude combos.** Tom breaks arms so Grube's Puppets survive. Cheney's Auras feed Nate's expensive Tech cards. Nate strips enemy buffs before Tom's big hits.
- **Bro Meter.** Fills only when two different players work on the same enemy.
- **Emotes.** "Send it", "Bro...", "My bad", "Sick!". Bound to the D-pad, no text chat required. Voice is left to the platform.

### Sessions

- **Lobby.** The host creates a room and shares a 6-character code or a platform invite. Guests may pick any Dude the host has unlocked.
- **Saving.** The run is saved after every node. The same party can resume it later from the host's save.
- **Disconnects.** A dropped player's Dude auto-plays Guard cards and ends its turn. The player has 5 minutes to rejoin before the party is offered the choice to continue without them.
- **Leaving for good.** If a player leaves, enemy scaling drops to the new party size from the next node.
- **No drop-in mid-run** at launch. Party size is fixed at floor 1 because decks and scaling are built from there.

## Tom, the Enforcer

Tom is the starting Dude: a large bald man who shuts enemies down by breaking their arms and by being so off-putting they stop wanting to fight.

| Attribute | Value |
| --- | --- |
| Unlocked | From the start |
| Max HP | 80 |
| Role | Front-line bruiser and control |
| Difficulty | Easy |
| Look | Huge, bald, sleeveless tunic, no neck |
| Starting Gear | Unused Gym Membership: heal 6 HP after every fight |
| Signature mechanics | Broken Arm and Ick |

### How Tom plays

- **Broken Arm** weakens an enemy's attacks for the whole fight and cancels one attack when every arm is broken. Best against big single hitters.
- **Ick** builds toward a skipped enemy turn. Tom's Ick cards are his attempts at charm: unwanted opinions, bad lines, long replies. It works on everything, including slimes.
- Enemies with no arms, such as slimes, can only be controlled with Ick. Two-armed enemies get both treatments.

### Starter deck (10 cards)

4 Punch, 4 Flex, 1 Arm Bar, 1 Well, Actually.

### Sample cards

| Card | Type | Cost | Rarity | Effect |
| --- | --- | --- | --- | --- |
| Punch | Attack | 1 | Starter | Deal 6 damage |
| Flex | Skill | 1 | Starter | Gain 5 Guard |
| Arm Bar | Attack | 2 | Starter | Deal 8 damage. Break 1 arm |
| Well, Actually | Skill | 0 | Starter | Apply 2 Ick |
| Wrist Lock | Attack | 1 | Common | Deal 5 damage. If the target has a Broken Arm, draw 1 card |
| Chrome Dome | Skill | 1 | Common | Gain 7 Guard. This turn, enemies that hit Tom take 3 damage from the glare |
| Skull Bash | Attack | 1 | Common | Deal 10 damage. Tom takes 2 damage |
| Unsolicited Advice | Skill | 1 | Common | Apply 3 Ick and 1 Noodle Arms |
| Cast Party | Skill | 1 | Uncommon | Gain 4 Guard for every Broken Arm on all enemies |
| Snap City | Attack | 2 | Uncommon | Deal 14 damage. Break 1 arm. If the target is now Armless, gain 1 Hype |
| Pickup Line | Skill | 1 | Uncommon | Apply 4 Ick to all enemies. Tom takes 3 damage from the response |
| Reply Guy | Power | 1 | Uncommon | Whenever an enemy gains a buff, apply 2 Ick to it |
| Double Arm Day | Attack | 3 | Rare | Deal 9 damage twice. Each hit breaks 1 arm |
| Friend Zone | Power | 2 | Rare | At the start of each turn, apply 1 Ick to all enemies. Grossed Out enemies also become Exposed for 2 turns |

### Build directions

- **Orthopedic Surgeon.** Stack Broken Arm fast, then live off Cast Party and Wrist Lock.
- **Repellent.** Chain Ick so the most dangerous enemy never gets a turn.
- **Head First.** Self-damage attacks like Skull Bash with HP-based payoffs. High risk, very Tom.

## Cheney, the Chapter President

Cheney makes everyone richer in Hype and Beer Money, runs team-wide Auras, and spends the surplus on the most expensive attacks in the game.

| Attribute | Value |
| --- | --- |
| Unlocked | Beat any floor 1 boss |
| Max HP | 70 |
| Role | Economy, support, burst damage |
| Difficulty | Medium |
| Look | Popped collar under chainmail, boat shoes, never carries his own bag |
| Starting Gear | Dad's Credit Card: +1 Hype on the first turn of each fight, +5 Beer Money after each fight |
| Signature mechanics | Resource generation and Auras |

### How Cheney plays

- **Resource generation.** Cheney makes Hype for himself and teammates, and turns fights into Beer Money.
- **Auras** are Powers that affect every player. He holds 2 at a time, and playing a third replaces the oldest. Clout raises Aura values by 1 per point.
- **Big attacks.** His damage cards cost 2, 3 or X Hype and hit harder per card than anyone's. Early turns set up; later turns cash in.

### Starter deck (10 cards)

4 Punch, 4 Flex, 1 Keg Toss, 1 Pregame.

### Sample cards

| Card | Type | Cost | Rarity | Effect |
| --- | --- | --- | --- | --- |
| Punch | Attack | 1 | Starter | Deal 6 damage |
| Flex | Skill | 1 | Starter | Gain 5 Guard |
| Keg Toss | Attack | 2 | Starter | Deal 13 damage |
| Pregame | Skill | 0 | Starter | Gain 1 Hype. Tapped |
| Shotgun | Skill | 1 | Common | Draw 1 card. Next turn, gain 2 Hype |
| Liquid Courage | Skill, Assist | 1 | Common | Target Dude gains 2 Swole this turn. Draw 1 card |
| Good Vibes | Aura | 1 | Common | At end of turn, every player gains 3 Guard |
| Bar Tab | Attack | 1 | Common | Deal 8 damage. Gain 5 Beer Money |
| Round on Me | Skill | 1 | Uncommon | Every other player gains 1 Hype. In solo play, gain 2 Hype. Tapped |
| Main Character Energy | Aura | 2 | Uncommon | Every player's attacks deal 2 more damage per hit |
| Bottle Service | Attack | 3 | Uncommon | Deal 26 damage. If this kills the target, gain 15 Beer Money |
| Trust Fund | Aura | 3 | Rare | At Refresh, Cheney gains 1 Hype. Every second turn, each other player gains 1 Hype |
| Make It Rain | Attack | 1 | Rare | Spend up to 40 Beer Money. Deal that much damage, split evenly among all enemies. Tapped |
| Keg Stand | Attack | X | Rare | Deal 8 damage to a random enemy, X times |

### Build directions

- **Whale.** Generate Hype early, then play 3-cost and X-cost attacks every turn.
- **Vibe Curator.** Swap Auras to match the fight; strongest in a full party.
- **Old Money.** Hoard Beer Money and convert it into damage with Make It Rain and money-scaling Gear.

## Nate, the Hacker

Nate hacks enemies from inside a permanent cloud of smoke, and he has a flawless six-pack of abs that he has never trained for and uses as armor.

| Attribute | Value |
| --- | --- |
| Unlocked | Beat any floor 2 boss |
| Max HP | 68 |
| Role | Damage over time, enemy disruption |
| Difficulty | Hard |
| Look | Open robe, perfect abs, red eyes, a glowing spell-tablet, a vape pen on a lanyard |
| Starting Gear | RGB Ab Roller: the first time each fight Nate has 0 Abs ready, 2 Abs recover |
| Signature mechanics | The Six-Pack (his abs), Bugs and Hacks |

### How Nate plays

- **The Six-Pack.** Nate's abs are a gauge of 6. At Refresh he gains Guard equal to the Abs he has ready, because hits bounce off them.
- **Crunch.** Many Tech cards have a Crunch bonus that strains Abs. Strained Abs give no Guard and do not recover on their own, so Nate trades defense for power all fight.
- **Baked.** His weed cards are strong and cheap but make him Foggy, so he draws fewer cards next turn.
- **Bugs** are damage over time. Clout adds 1 to every Bugs application.
- **Hacks** change what an enemy is about to do: weaken an intent, cancel it, or steal a buff.

### Starter deck (10 cards)

4 Punch, 3 Flex, 1 Ping, 1 Brute Force, 1 Wake and Bake. Nate has one fewer Flex because his abs do that job.

### Sample cards

| Card | Type | Cost | Rarity | Effect |
| --- | --- | --- | --- | --- |
| Punch | Attack | 1 | Starter | Deal 6 damage |
| Flex | Skill | 1 | Starter | Gain 5 Guard |
| Ping | Attack | 0 | Starter | Deal 3 damage. Apply 1 Bug |
| Brute Force | Attack | 2 | Starter | Deal 10 damage. Crunch 1: deal 6 more and apply 2 Bugs |
| Wake and Bake | Skill | 1 | Starter | Draw 3 cards. Gain 1 Foggy |
| DDoS | Attack | 1 | Common | Deal 2 damage 4 times. Crunch 1: 6 times instead |
| Firewall | Skill | 1 | Common | Gain 8 Guard. Crunch 1: this Guard is kept through the next Refresh |
| Munchies | Skill | 1 | Common | Recover 2 Abs. Gain 4 Guard |
| Phishing | Skill | 1 | Uncommon | Hack: steal one buff from an enemy |
| Sudo | Skill | 1 | Uncommon | Hack: change an enemy's intent to its weakest action. Tapped |
| Short-Term Memory Leak | Power | 1 | Uncommon | At end of turn, apply 1 Bug to all enemies |
| Have You Tried Turning It Off | Skill, Assist | 0 | Uncommon | Remove all debuffs from target Dude. Tapped |
| Zero Day | Attack | 2 | Rare | Deal damage equal to 3 times the target's Bugs. Tapped |
| Blue Dream Screen | Skill | 2 | Rare | Hack: cancel an enemy's intent. Rivals and bosses deal half damage this turn instead. Nate gains 1 Foggy. Tapped |

### Build directions

- **Shredded.** Keep all 6 Abs ready, skip the Crunch bonuses, and win slowly behind free Guard.
- **Burnout.** Crunch everything, recover with Munchies, and overwhelm with boosted Tech attacks.
- **Bug Farm.** Stack Bugs with Ping and Short-Term Memory Leak, then finish with Zero Day.

## Grube, the Master of Puppets

Grube never throws a punch he can make someone else throw: from deep in the couch he summons Puppets, pulls their strings, and eventually pulls the enemy's too.

| Attribute | Value |
| --- | --- |
| Unlocked | Win a run with any Dude |
| Max HP | 62 |
| Role | Summoner |
| Difficulty | Hard |
| Look | Bathrobe, sunglasses indoors, strings trailing from every finger, a haze that follows him from room to room |
| Starting Gear | Tangled Strings: start each fight with 1 Pledge in play |
| Signature mechanics | Puppets and Pull |

### How Grube plays

- **Puppets** sit in 3 slots beside Grube. Each has its own HP and takes one action at the end of every turn. They last until destroyed or the fight ends.
- **Pull** makes a Puppet act immediately, on top of its end-of-turn action.
- **Sacrifice.** Several cards destroy a Puppet for a payoff. Pledges are cheap for a reason.
- Area attacks hit Puppets. Single-target attacks hit Grube unless a Couch-Locked Roommate is in play. Clout adds 1 to every Puppet action.
- Grube himself does as little as possible. His card art is him on a couch, mid-exhale, while someone else does the work.

### Puppets

| Puppet | HP | End-of-turn action | Special |
| --- | --- | --- | --- |
| Pledge | 6 | Deal 3 damage to a random enemy | The default summon |
| Sock Puppet | 10 | Grube gains 4 Guard |  |
| Lookout | 5 | Apply 1 Exposed to the enemy with the most HP |  |
| Couch-Locked Roommate | 16 | Deal 2 damage to a random enemy by throwing the remote | Has not moved in hours. Single-target attacks aimed at Grube hit him instead |

### Starter deck (10 cards)

4 Punch, 4 Flex, 1 Rush Week, 1 Pull the Strings.

### Sample cards

| Card | Type | Cost | Rarity | Effect |
| --- | --- | --- | --- | --- |
| Punch | Attack | 1 | Starter | Deal 6 damage |
| Flex | Skill | 1 | Starter | Gain 5 Guard |
| Rush Week | Skill | 1 | Starter | Summon a Pledge |
| Pull the Strings | Skill | 1 | Starter | Pull one Puppet. Draw 1 card |
| Sock It to 'Em | Skill | 1 | Common | Summon a Sock Puppet |
| Blame the Pledge | Skill | 1 | Common | Gain 6 Guard. Move one of your debuffs to a Puppet |
| Hazing | Attack | 1 | Common | Destroy a Puppet. Deal damage equal to twice its remaining HP |
| Smoke Circle | Attack | 1 | Common | Deal 4 damage, plus 3 for each Puppet in the rotation |
| Post a Lookout | Skill | 1 | Uncommon | Summon a Lookout |
| Couch Lock | Skill | 2 | Uncommon | Summon a Couch-Locked Roommate |
| Cut the Strings | Skill | 0 | Uncommon | Destroy a Puppet. Gain 2 Hype and draw 2 cards |
| Puff, Puff, Pull | Skill | 2 | Uncommon | Pull every Puppet |
| Dance, Puppet | Skill | 2 | Rare | An enemy uses its intended attack on another enemy you choose. Bosses gain 2 Noodle Arms instead. Tapped |
| Master of Puppets | Power | 3 | Rare | Gain 1 Puppet slot. The first time each turn a Puppet is destroyed, summon a Pledge |

### Build directions

- **Full House.** Fill every slot, park a Couch-Locked Roommate in front, and let end-of-turn actions do the work.
- **Pledge Master.** Summon cheap Pledges and spend them on Hazing and Cut the Strings.
- **Puppeteer.** Stack Pull effects on one strong Puppet and turn enemies on each other.

## Ethan, the Foreman

Ethan works construction all day and plays Warhammer and Dungeons & Dragons all night, so he has the strongest abilities in the game and falls asleep right after using them.

| Attribute | Value |
| --- | --- |
| Unlocked | Have Dudes pass out 10 times in total, across any runs |
| Max HP | 76 |
| Role | Burst damage with downtime |
| Difficulty | Medium |
| Look | Hi-vis vest over a wizard robe, hard hat, tool belt holding a dice bag and a half-painted miniature |
| Starting Gear | Hard Hat: the first time each fight Ethan starts a Nap, he gains 8 Scaffolding |
| Signature mechanics | Crash, Scaffolding and Rolls |

### How Ethan plays

- **Crash.** His biggest cards have Crash N. After one resolves, his turn ends and he Naps for N turns: no draw, no Hype, no cards. He has been up since 5 a.m.
- **Napping is not Passed Out.** He still has HP, his Powers and Scaffolding keep working, and he wakes on his own. In co-op, any Assist card played on him wakes him early.
- **Scaffolding** is Guard he builds that is not removed at Refresh, up to 25. It is how he survives his own Naps.
- **Rolls.** His tabletop cards roll a 20-sided die and the result sets the effect. Clout adds 1 to every roll.
- The rhythm is build, blast, sleep: put up Scaffolding, play one enormous Crash card, and nap behind the wall while it pays off.

### Starter deck (10 cards)

4 Punch, 4 Flex, 1 Put Up Scaffolding, 1 Fireball.

### Sample cards

| Card | Type | Cost | Rarity | Effect |
| --- | --- | --- | --- | --- |
| Punch | Attack | 1 | Starter | Deal 6 damage |
| Flex | Skill | 1 | Starter | Gain 5 Guard |
| Put Up Scaffolding | Skill | 1 | Starter | Gain 6 Scaffolding |
| Fireball | Attack | 2 | Starter | Deal 16 damage to all enemies. Crash 1 |
| Nail Gun | Attack | 1 | Common | Deal 3 damage 3 times |
| Roll for Initiative | Skill | 0 | Common | Roll. On 11 or more, draw 2 cards. Otherwise draw 1 |
| Lunch Break | Skill | 1 | Common | Gain 5 Scaffolding. Heal 3 HP |
| Measure Twice | Skill | 1 | Common | Your next Roll this turn is made twice and keeps the higher result |
| Critical Hit | Attack | 2 | Uncommon | Roll. Deal damage equal to the roll plus 6. On a 20, deal 40 instead |
| Saving Throw | Skill, Assist | 1 | Uncommon | Roll for target Dude. On 10 or more, remove all their debuffs and give 10 Guard. Otherwise give 5 Guard |
| Load-Bearing Wall | Power | 2 | Uncommon | Whenever Ethan starts a Nap, he gains 10 Scaffolding |
| Wrecking Ball | Attack | 3 | Uncommon | Remove all of the target's Guard, then deal 30 damage. Crash 1 |
| Power Nap | Power | 1 | Rare | When Ethan wakes from a Nap, he gains 2 Hype and draws 2 extra cards |
| Meteor Swarm | Attack | 3 | Rare | Deal 12 damage to all enemies 3 times. Crash 2. Tapped |

### Build directions

- **Demolition.** Stack Scaffolding, then end fights with Wrecking Ball and Meteor Swarm before the Nap matters.
- **Dice Goblin.** Rolls, Measure Twice and Clout. Every turn is a gamble he insists is skill.
- **Power Napper.** Load-Bearing Wall and Power Nap turn sleeping into the strongest part of his turn cycle.

### Ethan in co-op

Ethan asks the most of his team. Teammates cover him while he naps, wake him with Assist cards when the timing matters, and get a cleared board in return.

## Items

Items come in two kinds: Gear is permanent for the run and changes a Dude's stats or how their attacks work, and Brews are single-use drinks and edibles held in 3 slots.

### General Gear

Any Dude can find these. In co-op, Gear belongs to the player who drafts it.

| Gear | Rarity | Changes | Effect |
| --- | --- | --- | --- |
| Lifting Belt | Common | Stat | +1 Swole |
| Lucky Lighter | Common | Stat | +1 Chill |
| Puka Shell Necklace | Common | Stat | +1 Clout |
| Gallon Jug | Common | Stat | +8 Max HP |
| Backwards Cap | Common | Draw | Draw 2 extra cards on the first turn of each fight |
| Fanny Pack | Common | Brews | +1 Brew slot |
| Pre-Workout | Uncommon | Hype | +1 Hype on the first turn of each fight. Take 3 damage at the start of each fight from the jitters |
| Wraparound Shades | Uncommon | Attacks | Exposed you apply lasts 1 turn longer |
| Beer Goggles | Uncommon | Rewards | Card rewards offer 4 cards instead of 3. One of them has its text hidden |
| Participation Trophy | Uncommon | Healing | If you end a fight below 50% HP, heal 8 |
| Fake ID | Uncommon | Shop | Prices at Baileys are 20% lower |
| Spotter's Gloves | Uncommon | Co-op | When you give Guard to a teammate, gain half that much. Solo: Assist cards give 2 more Guard |
| Championship Ring | Rare | Attacks | Attacks that cost 2 or more Hype deal 4 more damage |
| Protein Bucket | Rare | Stat | +2 Swole, −1 Chill |
| Speaker Tower | Rare | Attacks | Your first Attack each turn also hits every other enemy for half damage |
| Group Chat | Rare | Co-op | The first time each turn a teammate plays a 0-cost card, draw 1. Solo: triggers on your own first 0-cost card |

### Boss Gear

After each floor boss, every player picks 1 of 3. Each one is strong and has a cost.

| Gear | Upside | Downside |
| --- | --- | --- |
| Beer Helmet | +1 Hype per turn | Start each fight with a Hangover card in your draw pile |
| Dad's Platinum Card | +1 Hype per turn | You no longer earn Beer Money from fights |
| Cursed Intramural Trophy | +1 Draw per turn | Every enemy starts each fight with 1 Swole |

### Dude Gear

These only appear for their owner and change the Dude's signature mechanic.

| Gear | Dude | Rarity | Effect |
| --- | --- | --- | --- |
| Arm Wrestling Table | Tom | Uncommon | Every enemy starts the fight with 1 Broken Arm |
| Whole Can of Body Spray | Tom | Rare | When Tom applies Ick, the target takes 2 damage per stack applied |
| Aux Cord | Cheney | Rare | +1 Aura slot |
| Money Clip | Cheney | Uncommon | At the start of each fight, gain 1 Hype per 100 Beer Money held, up to 3 |
| Mechanical Keyboard | Nate | Rare | Tech attacks that hit more than once hit 1 extra time |
| Eight-Pack Genetics | Nate | Uncommon | The Six-Pack has 8 Abs instead of 6 |
| Extra Strings | Grube | Rare | +1 Puppet slot |
| Pledge Pin | Grube | Uncommon | Pledges are summoned with 4 more HP and deal 2 more damage |
| Loaded Dice | Ethan | Uncommon | Rolls of 5 or less count as 6 |
| Safety Vest | Ethan | Rare | While Napping, Ethan takes half damage |

### Brews

Drinking a Brew costs no Hype and can be done at any point in the player phase.

| Brew | Rarity | Effect |
| --- | --- | --- |
| Light Beer | Common | Heal 10 HP |
| Energy Drink | Common | Draw 3 cards |
| Protein Shake | Common | Gain 3 Swole for this fight |
| Shot of Courage | Common | Apply 3 Exposed to all enemies |
| Special Brownie | Uncommon | Gain 2 Hype. Add a Hangover card to your discard pile |
| Hair of the Dog | Uncommon | Remove all your debuffs and Tap every Junk card in your hand |
| Party Bowl | Uncommon | Every player heals 8 HP |
| Smelling Salts | Rare | Wake a Passed Out teammate at 25% HP. Solo: the next time you would pass out this fight, stay at 1 HP instead |

### Prices at Baileys

| Item | Beer Money |
| --- | --- |
| Card | 50–150 by rarity |
| Gear | 150–300 by rarity |
| Brew | 50–75 |
| Remove a card | 75, rising by 25 each time |

## Enemies

The roster is 24 normal enemies and 9 Rivals across three floors, and each one is built to pressure a specific habit: hoarding money, spamming cards, leaning on one mechanic.

HP values are for solo play; co-op applies the multiplier from the multiplayer section. The Arms column is the cap for Tom's Broken Arm. Each enemy has 2–4 moves and never repeats one three times in a row.

### Floor 1: The Basement

| Enemy | Tier | HP | Arms | Behavior |
| --- | --- | --- | --- | --- |
| Goblin Pledge | Normal | 12 | 2 | Hits for 5. If it is the last goblin standing, calls one more Goblin Pledge |
| Goblin Bouncer | Normal | 28 | 2 | Alternates 8 Guard with a 9-damage hit. Checks ID: applies 1 Noodle Arms |
| Keg Slime | Normal | 24 | 0 | Hits for 7. At half HP, splits into two Foam Slimes with 10 HP each |
| Dorm Rats (pack of 3) | Normal | 8 each | 2 | Each bite deals 3 and steals 5 Beer Money. They flee on turn 4; kill them to get it back |
| Skeleton Intern | Normal | 18 | 2 | Hits for 6. Every other turn, shuffles Paperwork into the target's deck |
| Boo-zer | Normal | 16 | 0 | A ghost. Every other turn it is Faded and takes at most 1 damage per hit. Hits for 8 |
| Mimic Cooler | Normal | 30 | 0 | Disguised as a Loot node. Bites for 12. Always drops a Brew |
| Kobold RA | Normal | 22 | 2 | Noise Complaint: a player who plays 5 or more cards in a turn takes 5 damage. Hits for 6 |
| Goblin Shot-Caller | Rival | 60 | 2 | Arrives with 2 Goblin Pledges. Every other turn gives all goblins 2 Swole or replaces a dead Pledge |
| Hall Monitor Golem | Rival | 75 | 2 | Every third card a player plays in a turn adds Detention to their discard pile. Hits for 14 |
| Sewer Gator in a Letterman Jacket | Rival | 68 | 2 | Death Roll: 5 damage 3 times. Gains 2 Swole whenever it deals unblocked damage |

### Floor 2: Dylan's Keep

Dylan is scenery. He sits on the couch behind every fight on this floor, playing Dragon Quest and hitting a bong. He cannot be targeted, never attacks, and does not know the party is there. The enemies are not his. They just sort of accumulate at his place.

Two things he does affect everyone in the room:

- **Bong rip.** Every fourth turn the room fills with smoke. Every Dude gains 1 Foggy and every enemy gains 1 Noodle Arms.
- **Level up.** About every sixth turn Dylan wins a battle in his game. A fanfare plays and one random character, Dude or enemy, heals 5.

Enemies here are built from weed, boags, gym equipment and video games.

| Enemy | Tier | HP | Arms | Behavior |
| --- | --- | --- | --- | --- |
| Dumbbell Twins (pair) | Normal | 20 each | 0 | Each hits for 7. When one dies, the other is unbalanced and Exposed for 2 turns |
| Bench Press Mimic | Normal | 55 | 0 | Pins a Dude under the bar: their Attacks cost 1 more next turn. Any Assist card played on them counts as a spot and frees them. Hits for 12 |
| Boag Imp | Normal | 22 | 2 | "Got a boag?" Bums a random card from the target's hand and keeps it until it dies. Flicks ash for 5 and adds a Burn card |
| Ashtray Golem | Normal | 46 | 2 | Gains 2 Guard for every card left in players' hands at end of turn. Hits for 9. Tips over when killed: a Burn card to every player |
| Bong Water Slime | Normal | 30 | 0 | Hits for 6 and applies 1 Hungover. Splashes any Dude who lands a hit of 10 or more: they gain 1 Foggy |
| Secondhand Smoke Wraith | Normal | 28 | 0 | Every other turn it is Hazy and takes half damage. Applies 2 Foggy |
| Rage-Quit Goblin | Normal | 32 | 2 | Tilted: gains 1 Swole each time it is hit. At 5 Swole it throws its controller for 15 and resets to 0 |
| Lag Sprite | Normal | 26 | 0 | Lag: the first card each player plays every turn resolves at end of turn instead. Hits for 7 |
| The Smith Machine | Rival | 110 | 2 | Fixed path: attacks the same Dude every turn until that Dude holds 15 Guard at once. Adds a plate each turn for 2 Swole |
| Hookah Hydra | Rival | 100 | 4 | Its 4 hoses count as arms. Hits once per unbroken hose for 5; each Broken Arm removes one hit. Every third turn it exhales: 2 Foggy to every player |
| Speedrunner Lich | Rival | 95 | 2 | Acts twice every third turn. From turn 7 it gains 3 Swole per turn, because this is taking too long |

### Floor 3: Firefly Music Festival

Every enemy here is festival staff or an attendee. What species they are under the flower crowns is an art decision.

| Enemy | Tier | HP | Arms | Behavior |
| --- | --- | --- | --- | --- |
| Wristband Checker | Normal | 60 | 2 | Worker. Picks one Dude each turn: that Dude's first Attack deals no damage, denied at the gate. Hits for 12 |
| Golf Cart Security | Normal | 85 | 2 | Worker. Escort: while he stands, single-target cards cannot target other enemies. Runs a Dude over for 14 |
| Flower Crown Dryad | Normal | 50 | 2 | Attendee. Good Vibes Only: heals every enemy for 6 each turn. Hits for 8 |
| The Mosh Pit | Normal | 90 | 0 | Attendees, counted as one enemy with too many arms to break. Hits every Dude and Puppet for 5 and gains 1 Swole per turn |
| Totem Pole Guy | Normal | 55 | 2 | Attendee carrying a 12-foot sign. While he lives, enemy intents are hidden. Hits for 9 |
| Overpriced Vendor | Normal | 45 | 2 | Worker. $14 lemonade: every player loses 5 Beer Money per turn. Hits for 1 per 10 Beer Money the target holds, minimum 6 |
| Crowd Surfer | Normal | 40 | 2 | Attendee. On odd turns he is up on the crowd and cannot be hit by single-target cards. On even turns he lands on a random Dude for 18 |
| Porta-Potty Mimic | Normal | 65 | 0 | Traps a Dude inside for a turn: they draw 2 fewer cards and gain 2 Hungover. Bites for 14 |
| The Sound Guy | Rival | 150 | 2 | Worker. Each turn he mutes one card type for every player, announced a turn ahead. Feedback screech: 10 damage to all |
| Beer Tent Kraken | Rival | 160 | 8 | Worker. Hits 8 times for 3. Each Broken Arm removes one hit. Every third turn it pours itself one and heals 15 |
| Front-Row Superfan | Rival | 170 | 2 | Attendee. Has held the rail since Thursday. Hits for 20 and Taps a random card in the target's hand. Encore: the first time it dies, it returns with 40 HP and 4 Swole |

### Junk cards

| Card | Effect | Lasts |
| --- | --- | --- |
| Hangover | Unplayable. When drawn, lose 1 Hype | Run |
| Regret | Unplayable. Cannot be removed at Baileys | Run |
| Bedbugs | Unplayable. When drawn, take 1 damage | Run |
| Paperwork | Costs 1 Hype. Does nothing. Tapped | Fight |
| Detention | Unplayable. While it is in your hand, you can play at most 4 cards this turn | Fight |
| Burn | Unplayable. If it is in your hand at end of turn, take 2 damage | Fight |

## Bosses

There are seven bosses: each floor rolls one of two, and every run ends against The Hangover.

HP is for solo play. Boss Ick thresholds start at 12, and 15 for The Hangover.

| Boss | Floor | HP | Arms | Core gimmick |
| --- | --- | --- | --- | --- |
| Goblin King Chad | 1 | 140 | 2 | Kill his Pledges to interrupt the Keg Stand |
| The Rat King of the Dumpster | 1 | 150 | 0 | Steals your cards and hides behind them |
| Rack Daddy, the Squat Rack Golem | 2 | 250 | 2 | Adds weight every turn until the party makes him fail a lift |
| The Hotbox Djinn | 2 | 230 | 0 | Fills the room with smoke and offers wishes that cost you |
| DJ Bassilisk | 3 | 350 | 2 | Builds to a Drop the whole party has to brace for |
| The Barnfire Collective | 3 | 95 each, 4 members | 2 each | A stomp-clap folk band; the order you kill them in matters |
| The Hangover | Final | 500 | 0 | Scales with every bad decision made this run |

### Goblin King Chad

President of the rival house, Gamma Omicron Beta.

- **Rush.** Every third turn he summons 2 Goblin Pledges.
- **Keg Stand.** His Pledges lift him and he charges for 2 turns, then hits one Dude for 30. Each Pledge killed during the charge removes 10 damage. Kill both and he falls: he skips a turn and is Exposed for 2.
- **Below 50% HP.** Rage Cage: 6 damage 3 times, every turn he is not charging.

### The Rat King of the Dumpster

Forty rats in one varsity jacket. No arms worth breaking, so Tom needs Ick.

- **Hoard.** Each turn he steals one card from every player's discard pile and gains 3 Guard per card hoarded.
- **Swarm.** 4 damage 4 times, spread across random Dudes and Puppets.
- **At 50% HP.** The hoard spills. Every stolen card returns to its owner's hand and costs 0 that turn.

### Rack Daddy, the Squat Rack Golem

A squat rack that got tired of being used for curls. Dylan has never touched it.

- **Progressive overload.** He adds a plate every turn for 2 Swole.
- **Max lift.** Every fourth turn he gets under the bar and charges for 1 turn, then slams it for 30 damage to all players.
- **Failed lift.** If the party deals 40 damage to him during the charge, he drops the bar: he takes 20 damage, loses every plate and is Exposed for 2 turns. The 40 scales with party size.
- **No spotter.** Each Broken Arm lowers the damage needed to fail the lift by 10.

### The Hotbox Djinn

He comes out of the bong on Dylan's table. Dylan passes it back without looking. No arms, so Tom needs Ick.

- **Smoke level.** A gauge from 0 to 10 that rises by 2 every turn. At 5 or more, every player gains 1 Foggy each turn. At 10 the party is Greened Out: every player discards their hand and the gauge resets to 0.
- **Open a window.** Any single hit of 15 damage or more lowers the smoke by 3.
- **Three wishes.** Three times per fight he offers every player a wish: heal 10, gain 2 Hype, or draw 2 cards. He gains 2 Swole for each wish taken. Saying no is free.

### DJ Bassilisk

The festival's EDM headliner, an invented act, and an actual basilisk behind the decks.

- **Build-up.** For 3 turns a Drop meter climbs while he hits one Dude for 12 per turn.
- **The Drop.** On the fourth turn, 30 damage to every player. The cycle then repeats, and each Drop is 10 bigger than the last.
- **On the beat.** Each build-up turn shows a beat count from 2 to 4. A player who plays exactly that many cards that turn takes half damage from the next Drop.
- **Stone gaze, below 50% HP.** A Dude who ends a turn with no Guard starts the next turn with 1 less Hype.

### The Barnfire Collective

An invented four-piece stomp-clap folk band. Each member has 95 HP and one job.

| Member | Job |
| --- | --- |
| Banjo | His attacks hit twice |
| Kick Drum | Gives every member 5 Guard each turn |
| Upright Bass | His attacks apply 1 Exposed |
| Tambourine | Heals the most damaged member for 8 each turn |

- **Stomp and clap.** On Stomp turns every member attacks for 8. On Clap turns the whole band gains 1 Swole.
- **Solos.** When a member dies, their job is gone and the survivors gain 2 Swole.
- **Going solo.** The last member standing acts twice per turn.

### The Hangover

A cosmic headache made of everything the party did this weekend. It rides in the car with them the whole way home.

- **It remembers.** It gains 10 HP for every Brew drunk this run and 1 Swole for every Dumb option taken in a Side Quest, up to 8.
- **Phase 1, Packing the Car.** Sunlight deals 6 damage to all players, rising by 2 each turn. Every other turn it shuffles a Hangover card into each deck.
- **Phase 2, at 60% HP: The Quiet Stretch.** It splits into one Personal Hangover per player, each with 100 HP. Nobody in the car is talking: players can only target their own, and Assist cards are disabled. Auras still work. In solo play there is one, and it copies the Dude's starter attacks.
- **Phase 3, The Drive-Thru.** When every Personal Hangover is dead, it re-forms at 40% HP. The party is back together, so the Bro Meter fills twice as fast. Every third turn it presents The Bill: damage to all players equal to 10% of the party's total Beer Money.

## Meta progression

Between runs, players earn Rep, which unlocks Dudes, cards and Gear into the pool; nothing bought between runs makes a Dude numerically stronger.

### Unlocking Dudes

| Dude | Unlock condition |
| --- | --- |
| Tom | Available from the start |
| Cheney | Beat any floor 1 boss |
| Nate | Beat any floor 2 boss |
| Grube | Win a run with any Dude |
| Ethan | Have Dudes pass out 10 times in total, across any runs |

In co-op, guests can play any Dude the host has unlocked, and every player in the party gets credit for unlock conditions met during the run.

### Rep

- Rep is earned at the end of every run, win or lose: per node cleared, per boss beaten, with a bonus for Keg Level.
- Each Dude has a 10-level Rep track. Every level adds 3 cards and 1 Gear to that Dude's reward pool.
- New players therefore start with about half of each pool, which keeps early runs readable.

### Keg Levels

Keg Levels are the difficulty ladder: 15 levels per Dude, each adding one permanent modifier on top of the ones before.

| Keg Level | Added modifier |
| --- | --- |
| 1 | Rival nodes are 50% more common |
| 2 | Enemies have 10% more HP |
| 3 | Start each run with a Hangover card |
| 5 | A Nap at the Tailgate heals 20% instead of 30% |
| 8 | Boss Gear offers 2 choices instead of 3 |
| 10 | Start each run with a Regret card |
| 12 | Prices at Baileys are 15% higher |
| 15 | The Hangover starts the fight in Phase 2 with one extra Personal Hangover |

In co-op, the run uses the host's Keg Level. A win raises each player's level for the Dude they played, up to one above the run's level.

### Other long-term hooks

- **Thirsty Thursday.** A weekly fixed-seed run with special modifiers and separate solo and party leaderboards.
- **Cosmetics.** Outfits (toga, jersey, bathrobe), card backs and emotes are earned through play.
- **The Trophy Shelf.** A record of every boss kill, Dude win and worst decision, viewable by friends.

## Technical design

The game runs on one deterministic rules core with no rendering in it; in co-op the host's copy is the authority, and other players send requests and receive results.

### Architecture decisions

| Area | Decision | Why |
| --- | --- | --- |
| Engine | Godot 4 (proposed, see open questions) | Strong 2D, free, exports to PC and consoles |
| Rules core | A separate module that takes a game state and a request and returns a new state plus a list of events | Runs identically in solo, on the host, and in automated balance tests |
| Authority | Host-authoritative for launch | Turn-based co-op against AI has little cheating incentive, and it avoids server costs |
| Transport | Platform relay with reliable, ordered messages | No port forwarding. Turn-based play tolerates 300 ms of latency |
| Content | Cards, enemies, Gear and Brews are data files, not code | Designers can add and tune content without a programmer |
| Randomness | One run seed split into independent streams | Reproducible runs, weekly seeds, replayable bug reports |
| Saving | Full state snapshot written by the host after every node | Resume later; recover from a host crash |

### How a card gets played in co-op

1. A player's client sends a `play_card` request to the host.
2. The host's rules core checks it: the card is in that player's hand, they have the Hype, the target is legal.
3. If valid, the core applies it and produces events such as damage dealt, status applied or enemy died.
4. The host sends the events to every client, which animate them in order.
5. If invalid, the host sends `reject` to that client only and nothing changes.
6. At the end of each turn, clients compare a hash of their state with the host's. On a mismatch the host sends a full snapshot.

Two players can aim at an enemy that dies to the first card. The second card is rejected, its Hype is not spent, and the client prompts for a new target.

### Network messages

| Message | Direction | Fields |
| --- | --- | --- |
| `join_lobby` | Client to host | `room_code`: the 6-character lobby code. `player_name`: display name. `client_version`: build number, so mismatched builds are refused |
| `pick_dude` | Client to host | `dude_id`: which Dude the player wants |
| `vote_node` | Client to host | `node_id`: the map node the player votes for |
| `play_card` | Client to host | `card_uid`: the specific card copy. `target_id`: the chosen enemy, Dude or Puppet, or empty. `crunch`: true if the player pays the Crunch cost. `seq`: see below |
| `use_brew` | Client to host | `slot`: which Brew slot, 0–3. `target_id`: target if the Brew needs one. `seq` |
| `use_bro_move` | Client to host | `seq` |
| `set_ready` | Client to host | `ready`: true when the player is done with the turn |
| `choose_reward` | Client to host | `reward_id`: which reward screen. `choice_index`: which option, or −1 to skip |
| `ping_card` / `emote` | Client to host | `card_uid` or `emote_id`. Relayed to all players; no effect on game state |
| `events` | Host to all | `state_version`: counter that rises by 1 per applied request. `list`: ordered events to animate |
| `reject` | Host to one client | `seq`: the request refused. `reason`: short code such as `no_hype` or `bad_target` |
| `snapshot` | Host to one or all | `state`: the complete game state. `state_version` |

`seq` is a per-client counter that starts at 0 and rises by 1 with every request. It lets the host ignore duplicates and lets the client match a `reject` to the request that caused it.

### Example card definition

```json
{
  "id": "tom_arm_bar",
  "name": "Arm Bar",
  "owner": "tom",
  "type": "attack",
  "rarity": "starter",
  "cost": 2,
  "target": "enemy",
  "effects": [
    { "op": "damage", "amount": 8, "hits": 1 },
    { "op": "apply_status", "status": "broken_arm", "stacks": 1 }
  ],
  "keywords": [],
  "crunch": null,
  "upgrade": { "effects[0].amount": 11 }
}
```

### Card definition fields

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | Text | Unique key in the form owner\_card\_name. Never changes after release, because saves refer to it |
| `name` | Text | Name shown on the card |
| `owner` | Text | Which pool the card belongs to: `tom`, `cheney`, `nate`, `grube`, `neutral` or `junk` |
| `type` | Text | `attack`, `skill`, `power`, `aura` or `junk` |
| `rarity` | Text | `starter`, `common`, `uncommon` or `rare`. Sets reward odds and shop price |
| `cost` | Number or text | Hype needed to play. `"x"` spends all remaining Hype. −1 means unplayable |
| `target` | Text | What the player must select: `enemy`, `all_enemies`, `self`, `ally`, `puppet` or `none` |
| `effects` | List | Operations run in order. Each has an `op` name and that operation's own values |
| `effects.op` | Text | The operation: `damage`, `guard`, `apply_status`, `draw`, `gain_hype`, `summon`, `pull`, `hack` and so on |
| `effects.amount` | Number | Base size of the effect before Swole, Chill or Clout |
| `effects.hits` | Number | How many times a damage effect repeats |
| `effects.status` / `effects.stacks` | Text / number | Which status to apply and how many stacks |
| `keywords` | List | Any of `tapped`, `pocketed`, `assist`, `tech` |
| `crunch` | Object or null | Nate only. `abs`: Abs strained. `effects`: operations added when the cost is paid |
| `upgrade` | Object | Field paths and their new values after the card is Lifted at a Tailgate |

### Dude state (one per player, during a run)

| Variable | Type | Meaning |
| --- | --- | --- |
| `player_id` | Text | The network player who controls this Dude |
| `dude_id` | Text | Which Dude this is |
| `hp` / `max_hp` | Number | Current and maximum hit points |
| `guard` | Number | Damage absorbed before HP. Reset to 0 at Refresh |
| `hype` | Number | Hype left to spend this turn |
| `hype_per_turn` | Number | Hype granted at Refresh. Base 3 |
| `draw_per_turn` | Number | Cards drawn at Refresh. Base 5 |
| `swole` / `chill` / `clout` | Number | The three bonus stats defined in the combat rules |
| `statuses` | Map | Status name to stack count, for example Exposed 2 |
| `draw_pile` / `hand` / `discard_pile` / `tapped_pile` | Lists of `card_uid` | Where each card copy currently is |
| `card_uid` | Text | Identifies one physical copy of a card in this run, so two Punches can be told apart |
| `cards_played_this_turn` | Number | Used by Noise Complaint, Detention, card limits and the solo Bro Meter |
| `gear` | List | Ids of Gear owned |
| `brews` / `brew_slots` | List / number | Brews held and how many can be held. Base 3 slots |
| `beer_money` | Number | Currency held |
| `passed_out` | True or false | True at 0 HP. The Dude skips turns until woken |
| `ready` | True or false | True once the player has ended their turn |
| `abs_ready` / `abs_max` | Number | Nate only. Abs ready to give Guard, and the size of the Six-Pack. Base 6 |
| `auras` / `aura_slots` | List / number | Cheney only. Active Auras, oldest first, and how many he can hold. Base 2 |
| `puppets` / `puppet_slots` | List / number | Grube only. Puppets in play, each with its own `hp` and `statuses`, and the slot count. Base 3 |

### Enemy fields

| Variable | Type | Meaning |
| --- | --- | --- |
| `id` / `name` | Text | Unique key and display name |
| `floor` | Number | Which floor it appears on, 1–3, or 4 for the final boss |
| `tier` | Text | `normal`, `rival` or `boss`. Sets rewards and the base Ick threshold |
| `max_hp` | Number | Solo hit points before the party-size multiplier |
| `arm_count` | Number | How many arms can be broken. 0 makes it immune to Broken Arm |
| `moves` | List | Each move has an `id`, a `weight` for random choice, an intent icon, and `effects` like a card |
| `hp` / `guard` / `statuses` | As for Dudes | Current combat values |
| `broken_arms` | Number | Arms broken so far, from 0 to `arm_count` |
| `armless_used` | True or false | True once the enemy has lost an attack to being Armless, so it only happens once |
| `ick` / `ick_threshold` | Number | Current Ick and the value at which it is Grossed Out |
| `intent` | Object | `move_id`: the move it will use next. `target_ids`: who it is aimed at |

### Run state

| Variable | Type | Meaning |
| --- | --- | --- |
| `run_seed` | Number | The seed every random stream is derived from |
| `party_size` | Number | Players in the run, 1–4. Drives all scaling |
| `keg_level` | Number | Difficulty level for the run, 0–15 |
| `floor` / `node_index` | Number | Where the party is on the map |
| `map` | Graph | The nodes of the current floor and the paths between them |
| `bro_meter` | Number | Shared gauge, 0–10 |
| `designated_driver` | `player_id` | Who breaks map-vote ties this floor |
| `gear_first_pick` | `player_id` | Who drafts first at the next Gear reward |
| `brews_drunk` | Number | Brews used this run. Adds HP to The Hangover |
| `dumb_options_taken` | Number | Dumb Side Quest choices this run. Adds Swole to The Hangover |
| `state_version` | Number | Rises by 1 with every applied request. Orders events and detects missed messages |

### Random streams

| Stream | Used for | Why it is separate |
| --- | --- | --- |
| `map` | Floor layouts | Same seed always gives the same map |
| `encounters` | Which enemies and bosses appear | Not changed by what players do in fights |
| `rewards`, one per player | Card, Gear and Brew offers | One player skipping a reward does not change another's |
| `shuffle`, one per player | Deck shuffles | Playing more cards does not reorder a teammate's deck |
| `combat_ai` | Enemy move and target choice | Keeps fights reproducible from a log |
| `side_quest` | Gambles and random outcomes | Outcomes cannot be rerolled by reloading |

### Tuning constants

All balance numbers live in one data file so they can be changed without touching code.

| Constant | Value | Meaning |
| --- | --- | --- |
| `BASE_HYPE` | 3 | Hype per turn before Gear |
| `BASE_DRAW` | 5 | Cards drawn per turn before Gear |
| `EXPOSED_MULT` | 1.5 | Damage multiplier against an Exposed target |
| `NOODLE_MULT` | 0.75 | Damage multiplier for an attacker with Noodle Arms |
| `HUNGOVER_MULT` | 0.75 | Guard multiplier for a Hungover Dude |
| `BROKEN_ARM_MAX_REDUCTION` | 0.4 | Attack reduction when every arm is broken |
| `ICK_BASE_NORMAL` / `_RIVAL` / `_BOSS` | 5 / 8 / 12 | Starting Ick thresholds by tier |
| `ICK_THRESHOLD_STEP` | 3 | Added to an enemy's threshold each time it is Grossed Out |
| `BRO_METER_MAX` | 10 | Bro Meter value needed for a Bro Move |
| `HP_SCALE_PER_EXTRA_PLAYER` | 0.8 | Enemy HP added per player beyond the first, as a fraction of solo HP |
| `EXTRA_ENEMY_PARTY_SIZE` | 3 | Party size at which Brawls gain one enemy |
| `MULTI_TARGET_PARTY_SIZE` | 3 | Party size at which single-target attacks hit 2 Dudes |
| `REVIVE_HP_FRACTION` | 0.3 | HP a Passed Out Dude wakes with after a won fight |
| `TURN_TIMER_SECONDS` | 90 | Default co-op turn timer |
| `REJOIN_GRACE_SECONDS` | 300 | How long a disconnected player's seat is held |

### Fields added for Ethan

| Name | Where | Type | Meaning |
| --- | --- | --- | --- |
| `crash` | Card definition | Number or null | Turns Ethan Naps after the card resolves. Null on cards without Crash |
| `roll` | Card effect operation | Object | `sides`: size of the die, 20 by default. `outcomes`: list of result ranges and the effects each one runs |
| `scaffolding` | Dude state | Number | Ethan only. Guard that survives Refresh. Capped at `SCAFFOLDING_MAX` |
| `nap_turns` | Dude state | Number | Ethan only. Turns of Nap left. Above 0 he skips his draw, Hype and card plays and is marked `ready` automatically |
| `skip_next_nap` | Dude state | True or false | Ethan only. Set by his Bro Move. The next Crash card clears it instead of starting a Nap |
| `dice`, one per player | Random stream | Stream | All die rolls. Separate so a roll never changes a shuffle or an enemy's move |
| `SCAFFOLDING_MAX` | Tuning constant | 25 | Most Scaffolding Ethan can hold |
| `NAP_WAKE_ON_ASSIST` | Tuning constant | True | Whether an Assist card played on a Napping Ethan wakes him |

### Documentation standard

- Every data field, state variable and tuning constant is added to the tables above in the same change that introduces it.
- Code comments on each variable repeat the meaning given here.
- Every design or code change gets a row in the change log at the end of this document, with what changed and why.

## Scope, milestones and open questions

Build solo Tom on floor 1 first, prove co-op with two Dudes second, and only then scale to five Dudes and three floors.

### Milestones

No dates are set yet. Each phase has a gate that must pass before the next one starts.

| Phase | Contents | Gate |
| --- | --- | --- |
| 1. Paper prototype | Tom's starter deck and 15 more cards against floor 1 enemies, on printed cards | Fights are fun with no art and no jokes |
| 2. Solo slice | Tom, floor 1, 30 cards, 10 Gear, one boss, placeholder art | Outside playtesters finish the floor and start a second run unprompted |
| 3. Co-op prototype | Tom and Cheney, 2 players over the internet, host authority, floor 1 | A full floor with no desync and no confusion about whose turn it is |
| 4. Alpha | All 5 Dudes, 3 floors, all 7 bosses, 4-player co-op, half-size card pools | A 4-player run can be completed start to finish |
| 5. Beta | Full card pools, Keg Levels, reconnect, save and resume, final art and barks | Win rates per Dude and per party size sit inside target bands |
| 6. Launch | Weekly seeded run, leaderboards, localization |  |

### Risks

| Risk | Mitigation |
| --- | --- |
| Balance across 1–4 players | Scaling lives in three tuning constants; automated bot runs on the rules core measure win rates per party size |
| Simultaneous turns feel chaotic | Card pings, visible teammate hands, and events that always animate in host order |
| Screen clutter with 4 Dudes, Puppets and enemies | Puppets render at half size in a row under Grube; test at 4 players from the co-op prototype onward |
| 320 cards is a large content load | Cards are data-driven; half-size pools at alpha, and pools grow through the Rep tracks |
| Humor lands as mean instead of dumb | The writers' rules in the tone section, plus playtests with people outside the friend group |

### Open questions

- [ ] Engine: confirm Godot 4 or choose another.
- [ ] Hosting: is host authority acceptable at launch, or are dedicated servers required?
- [ ] Can two players pick the same Dude, for example an optional "All Toms" mode?
- [ ] Rating: the weed and alcohol humor points to Mature. Confirm that is acceptable.
- [ ] Business model: a one-time purchase is assumed. Confirm.
- [ ] If the Dudes, Dylan or Baileys are named after real people or places, get their written approval before release.
- [ ] Firefly, Dragon Quest, Warhammer and Dungeons & Dragons are real brands. Check whether a commercial release can name them, or pick stand-in names.
- [ ] Is drop-in joining mid-run needed, or is a fixed party fine?
- [ ] Is competitive play wanted later, such as two parties racing the same seed?

## Change log

| Version | Date | Change | Reason |
| --- | --- | --- | --- |
| 0.4 | 2026-10-10 | Final floor renamed from The Afterparty to The Drive Home. The Hangover's phases renamed to Packing the Car, The Quiet Stretch and The Drive-Thru. Rules unchanged | Requested re-theme |
| 0.3 | 2026-10-10 | Fifth Dude added: Ethan, the Foreman, with Crash, Scaffolding and Rolls, 14 cards, 2 Gear, a Bro Move and an unlock condition. New fields: crash, roll, scaffolding, nap\_turns, skip\_next\_nap, dice stream, SCAFFOLDING\_MAX, NAP\_WAKE\_ON\_ASSIST. Card target raised from 260 to 320 | New character requested |
| 0.2 | 2026-10-10 | Floor 2 is now Dylan's Keep and floor 3 is Firefly Music Festival, each with 11 new enemies and 2 new bosses. The Haunted Quad, The Dean's Keep and their enemies and bosses are removed | Requested re-theme |
| 0.2 | 2026-10-10 | Nate's Six-Pack is his abs. Cans and Crack are replaced by Abs and Crunch. Data fields renamed: `crack` to `crunch`, `cans` to `abs_ready`, `cans_max` to `abs_max` | The six-pack was meant as abs, not drinks |
| 0.2 | 2026-10-10 | Weed theming added: Nate's Baked cards and Foggy cost, Grube's Lookout and Couch-Locked Roommate, Special Brownie and Party Bowl, a new Side Quest | Requested re-theme |
| 0.2 | 2026-10-10 | Shop renamed from Sketchy Dan's Van to Baileys | Requested |
| 0.2 | 2026-10-10 | Music and audio section added, with floor 3 styled on the 2013 Firefly lineup | Requested |
| 0.1 | 2026-10-10 | First draft of all sections: rules, co-op, 4 Dudes, items, enemies, bosses, technical design | Initial design from the project brief |
