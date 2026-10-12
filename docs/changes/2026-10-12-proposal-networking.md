# 2026-10-12 - Proposal: networking for the co-op prototype

Added `docs/proposals/networking.md` (Agent A, at Smoketsu's request). It is a design proposal only,
with no code. It covers:
- the protocol: host session, client session, and clients replaying accepted requests with their own
  core;
- swappable transports: ENet first, a platform relay later;
- three core additions: `turn_timeout`, `set_away` / `set_back`, `leave_party`;
- a relay comparison: Steam, Epic, self-hosted, VPN;
- suggested tasks per lane;
- questions N1–N7 for the people.

## Variables, fields and constants

None were added. The proposal names requests that would be added later, in contract PRs, only if it
is accepted.
