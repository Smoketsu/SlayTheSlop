# Proposal: networking for the co-op prototype (GDD milestone 3)

- Author: Agent A, at Smoketsu's request (2026-10-12)
- Status: **open.** Needs answers from Smoketsu and steamjgrube (questions N1–N7 at the end). No
  networking code starts until they are answered.
- GDD version read: 0.5 ("Online multiplayer", "Sessions", "Technical design": "Authority",
  "Transport", "How a card gets played in co-op", "Network messages")

## What the GDD already decides

- **Authority:** host-authoritative. The host runs the rules core, and players send requests.
- **Transport:** "Platform relay with reliable, ordered messages. No port forwarding." Turn-based
  play tolerates 300 ms of latency.
- **Message list:** `join_lobby`, `pick_dude`, the game requests, `events`, `reject`, `snapshot`.
  Each request has a per-client `seq`; the host keeps a `state_version`.
- **Desync check:** at the end of each turn, clients compare a hash of their state with the host's.
  On a mismatch the host sends a full snapshot.
- **Sessions:** a 6-character room code, a host save after every node, rejoining within 5 minutes,
  and no drop-in mid-run.

Milestone 3 is Tom and Cheney, 2 players over the internet, floor 1. Its gate is a full floor with no
desync and no confusion about whose turn it is.

## What is already built for it

- **Core:** `Core.apply(ruleset, state, request) -> {state, events, reject}` and `Core.validate()`.
  It is pure and deterministic. Requests already carry `player_id` and `seq`, and the state carries
  `state_version`.
- **Hash and snapshots:** `core/run/save/` has `Snapshot.state_hash()` and a byte-exact snapshot
  round trip (task 027).
- **Gateway:** the client only ever talks to a "gateway" object with the same `apply()`.
  `client/fight/fight_screen.gd` notes that co-op will swap in a network gateway.
- **Co-op rules:** 2–4 Dudes, party scaling, the co-op Bro Meter, enemy targeting, ally cards and
  map votes are already in the core.
- **Bots:** headless bots (task 022) could play for a disconnected Dude: the GDD's "auto-plays Guard
  cards". They live in `tools/bots/`, which the export presets leave out of the game, so the bot the
  host uses has to move into the game's own code. That is a small move, and it needs both lanes to agree.

## Proposed design

### 1. One protocol, swappable transports

A small `net/` layer sits between the client and the core. It has three parts:

- **`Transport` interface:** `host(room) / join(room_code) / send(peer, bytes) / poll() -> messages`,
  with reliable, ordered delivery.
  - The first implementation uses Godot's built-in `ENetMultiplayerPeer`. It is free and needs no
    extra dependency, and it works on a LAN or over a VPN such as Tailscale. This is for development
    and the milestone 3 gate.
  - A platform relay implementation (section 3) replaces it before outside co-op testing. Nothing
    above the transport changes.
- **`HostSession`:** owns the authoritative state. For each incoming request it:
  1. drops duplicates by `seq`;
  2. runs `Core.apply`;
  3. on success, broadcasts `{state_version, request, events}`;
  4. on failure, sends `reject` to the sender only;
  5. writes the save after every node, as the solo client does now.
- **`ClientSession`:** a network gateway with the same interface as the local one. It sends requests
  and receives `events` messages. **It also applies the same accepted request to its own copy of the
  state with its own core.** The core is deterministic, so both copies stay identical without
  shipping state. At the end of each turn the client sends its `state_hash`. On a mismatch the host
  sends a `snapshot` and the client replaces its state. This is the GDD's step 6, and it costs very
  little bandwidth.

Messages are the GDD's table, encoded as JSON text with `core/schema/json_values.gd`. That keeps
ints as ints and 64-bit values as strings, as the save already does. A `hello` handshake checks
`client_version` and the data's content hash, so mismatched builds or data are refused at the door.

### 2. Things the core needs (rules lane, small)

Each of these is a schema addition: an additive contract PR.

- **`turn_timeout` request:** the host sends it when the turn timer expires (`TURN_TIMER_SECONDS`).
  The core treats it as `set_ready` for everyone not yet ready. The **host client** owns the clock;
  the core still never reads time.
- **`set_away` / `set_back` request:** marks a disconnected Dude. While away, the host runs the
  greedy bot for that Dude (GDD: plays Guard cards, then readies) through the same `apply()`.
- **Party size after a leave:** the GDD's "enemy scaling drops to the new party size from the next
  node" needs a `leave_party` request and a rule for what happens to the Dude's deck. That is an open
  question for the GDD (N6).

### 3. Which platform relay (decision N1)

| Option | Cost | What it gives | Catch |
| --- | --- | --- | --- |
| **Steam** (Steam Networking Sockets and lobbies, through the GodotSteam GDExtension) | Steam Direct fee (about $100 per app) | Relay, NAT traversal, lobbies, invites, room codes through lobby data. What most players expect | Steam only. Needs a Steam app ID and a third-party GDExtension; confirm its Godot 4.7 support before committing |
| **Epic Online Services** (P2P relay and lobbies) | Free | Cross-store relay and lobbies | Godot support is community plugins; more setup; Epic account linking |
| **Self-hosted relay** (for example an open-source Godot relay and NAT punch-through server on a small VPS) | A few dollars a month | Full control, any store | We run a server, which the GDD wanted to avoid ("avoids server costs") |
| **ENet direct plus a VPN** (Tailscale or similar) | Free | Works today | Players must install the VPN. Dev and friends only, never for outside players |

**Recommendation:**
- Build ENet first: it unblocks the whole protocol and the milestone 3 gate with zero
  infrastructure.
- Pick **Steam** as the shipping relay if the game will launch on Steam, which the GDD's "platform
  invite" wording suggests.
- Adding the relay is one `Transport` implementation plus a lobby screen.

### 4. Screens the client needs (client lane)

1. Host and Join menu: room code entry and display.
2. Lobby: players, Dude pick (`pick_dude`), ready, start.
3. In the fight:
   - teammates' hands (read-only);
   - card pings and emotes;
   - the Ready state of each player;
   - the turn timer;
   - "waiting for host" and "reconnecting" overlays.

## Suggested tasks once answered

| Owner | Task |
| --- | --- |
| A | `net/` protocol: message encode and decode, `HostSession`, `ClientSession`, and the ENet transport. Tests run host and client in one process over a loopback transport, play a full fixed-seed floor, and assert equal hashes every turn |
| A | Core additions: `turn_timeout`, `set_away` / `set_back` (contract PRs first) |
| A | Desync recovery: forced-mismatch test, snapshot resend, replay from `state_version` |
| B | Host/Join and lobby screens, room code display, version-mismatch message |
| B | Co-op fight UI: teammates' hands, pings and emotes, Ready markers, turn timer, reconnect overlay |
| B | Cheney's card-pool proposal and data (milestone 3 needs Tom and Cheney) |
| A | Cheney's mechanics: Auras and team Hype |
| A or B | The relay transport for the platform chosen in N1, after the ENet version passes the milestone 3 gate |

## Questions for the people

- **N1. Relay platform:** Steam, Epic, self-hosted, or decide later and ship ENet plus VPN to friends
  first? The recommendation is ENet now and Steam for launch.
- **N2. Lane:** who owns the new `net/` directory? The CLAUDE.md lane table doesn't say.
  Suggestion: a new `net` lane for Agent A, with the lobby screens in Agent B's `client` lane. This
  is a CLAUDE.md change in its own PR.
- **N3. Clients run the core:** OK for clients to apply accepted requests with their own core, as
  above? The alternative is the host sending full state after every request: simpler, more
  bandwidth.
- **N4. Cheating:** the GDD accepts that a host can cheat (turn-based co-op, low incentive). Clients
  also see the draw order in their own state copy. OK for co-op?
- **N5. Version number:** the `hello` check needs `application/config/version` set. It isn't yet:
  a one-line `project.godot` contract PR.
- **N6. Leaving for good:** when a player leaves, does their Dude vanish, become a bot, or stay
  Passed Out? The GDD covers scaling but not the Dude.
- **N7. Milestone order:** does networking start before the outside solo playtest (the milestone 2
  gate) finishes? The GDD orders them, but the work doesn't depend on the playtest results.
