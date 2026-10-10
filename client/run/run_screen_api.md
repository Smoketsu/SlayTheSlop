# Run screens: the shared interface (task 020)

Every run sub-screen (`map_screen.gd`, `offer_screen.gd`) is a `Control` with this interface, so the
run screen (`run_screen.gd`) can show any of them the same way. Lane: client (Agent B).

- `func show_state(ruleset: Dictionary, state: Dictionary, player_id: String) -> void`
  Redraws the whole screen from a run state snapshot. Reads only; never changes `state`. Called
  after every applied request and after loading a save.
- `signal request_made(request: Dictionary)`
  Emitted when the player picks something. `request` holds `type` and that type's own fields
  (`core/schema/request.gd`), for example `{"type": "vote_node", "node_id": "r1c0"}` or
  `{"type": "choose_reward", "reward_id": "...", "choice_index": 0}`. The run screen adds
  `player_id` and `seq`, sends it to the core and redraws.
- Test hooks: public `press_*` methods that do exactly what a click does, so tests drive the screens
  headless (as `fight_screen.gd` does).

Which screen is shown comes from the state alone (`run_screen.gd` `screen_for()`):
`run_phase` "map" -> map; an active fight -> the fight screen; "node" with an open offer for this
player -> the offer screen; "floor_end" -> run over (won); "lost" -> run over (passed out).
