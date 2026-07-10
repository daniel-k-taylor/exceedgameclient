# Eugenia & Zsolt Test Suites

Unit tests validating the two Season 2 characters added in PR #208
(Eugenia "Cheshire Cat" and Zsolt). Both suites use the modern
`ExceedGutTest` base class and play against a clean **Ryu** opponent so the
opponent never triggers either character's passives.

- `test_eugenia.gd` — 25 tests
- `test_zsolt.gd` — 29 tests

Both characters are also wired into the AI stress test `test_randomai.gd` via
`test_eugenia_100()` / `test_zsolt_100()` (see "AI stress testing" below).

## Running the tests

Run the whole unit suite (slow — runs everything):

```powershell
.\godotexe\Godot_v4.4.1-stable_win64_console.exe -s addons/gut/gut_cmdln.gd "-gdir=res://test/unit" -gexit
```

### Running a SINGLE test file (important)

Use **`-gselect=<substring>`** (no `.gd` extension). This is the correct way to
run one file:

```powershell
.\godotexe\Godot_v4.4.1-stable_win64_console.exe -s addons/gut/gut_cmdln.gd "-gdir=res://test/unit" -gexit "-gselect=test_eugenia"
```

```powershell
.\godotexe\Godot_v4.4.1-stable_win64_console.exe -s addons/gut/gut_cmdln.gd "-gdir=res://test/unit" -gexit "-gselect=test_zsolt"
```

> **Gotcha:** `-gtest=<file>.gd` combined with `-gdir` does **not** limit the
> run to one file — it still runs *every* test in the directory. That was the
> source of earlier confusion where "one test file" appeared to run globally.
> Always use `-gselect` to scope to a single file.

The console build (`Godot_v4.4.1-stable_win64_console.exe`) prints test output
to stdout; the non-console build does not. Filter noisy output, e.g.:

```powershell
... 2>&1 | Select-String -Pattern "\* test_|\[Failed\]|Tests |Passing|Failing"
```

## Test-harness cheat-sheet

Both suites rely on helpers in `test/exceed_test.gd`:

- `execute_strike(initiator, defender, init_card, def_card, init_ex, def_ex, init_choices, def_choices, exit_after_validation, init_alt_ex, def_alt_ex, init_use_face_attack, def_use_face_attack)`
  drives a full strike. `init_choices` / `def_choices` are popped one element per
  decision, in resolution order, per player.
- Ultra gauge cost is paid by making the **first** `init_choices` entry the list
  of gauge ids: `[gauge_ids, ...]` (a flat list, NOT `[[gauge_ids], ...]`).
- Face attack: pass `init_card=""` and set `init_use_face_attack=true` (the 12th
  positional argument).
- `give_gauge(player, n)` returns the gauge card ids; `add_transform(player, def_id)`
  moves a special into the transform zone (also reduces exceed cost).

---

# Eugenia (Cheshire Cat)

Season 2, exceed cost **6** (reduced by 2 per transform). Buddy/set-aside zone
"Wonderland". Difficult

## What is tested (25 tests)

### Basics & setup (4 tests)
- `test_starting_life` — Both players start at 30 life
- `test_exceed_cost_default` — Default exceed cost is 6
- `test_exceed_cost_with_one_transform` — 1 transform reduces cost to 4
- `test_exceed_cost_with_two_transforms` — 2 transforms reduce cost to 2

### Normal passive (2 tests)
- `test_normal_passive_reveal_deals_nonlethal_damage` — Reveal matching printed speed → 2 non-lethal damage
- `test_normal_passive_pass_declines` — Declining reveal = no bonus damage

### Special attacks (5 tests)
- `test_plot_hook_pull_and_advantage` — Plot Hook: pull 5 + gain advantage
- `test_absinthin_arrow_damage_and_discard` — Absinthin Arrow: opponent draws 1 then discards 2 random
- `test_shimmer_choose_discard` — Shimmer of Madness: reveal hand, choose 1 to discard
- `test_werelight_opponent_discards` — Werelight: opponent chooses (discard 2 random / reveal + discard 1)
- `test_color_spray_damage` — Color Spray: hit draws opponent up to 2 or discards down to 2

### Ultra attacks (2 tests)
- `test_queen_of_hearts_discard_hand` — Queen of Hearts: opponent discards hand, then draws 1
- `test_cats_cradle_power_scales_with_opponent_hand` — Cat's Cradle: -1 Power per opponent hand card

### Exceed / Wonderland (4 tests)
- `test_exceed_places_wonderland_and_ends_turn` — On exceed, Wonderland card created + turn ends
- `test_exceeded_passive_adds_card_to_wonderland` — Exceeded passive: add discarded card to Wonderland
- `test_wonderland_face_attack_bonus` — Wonderland face attack +1P/+1S
- `test_wonderland_replace_returns_old_card_to_opponent_discard` — Adding a new card returns the old card to opponent's discard

### Boosts / transforms (8 tests)
- `test_hanging_by_a_thread_bonus_power` — Hanging by a Thread: +2P when opponent ≤2 cards
- `test_time_for_tea_action_discards` — Time for Tea: bonus action pay 1F → opponent discards 1 random
- `test_off_with_her_head_boost_discards` — Off With Her Head: range 1 → opponent chooses disc 2 or push 3
- `test_edge_of_sanity_boost_discards` — Edge of Sanity: opponent discards 1 random
- `test_edge_of_sanity_reduces_opponent_prepare_draw` — Edge of Sanity: opponent draws 0 on prepare
- `test_unhinged_adds_discard_on_ex_strike` — Unhinged: EX strike adds opponent discard on hit
- `test_were_all_mad_here_boost` — We're All Mad Here: both players draw 0-4 then discard 1
- `test_wanderlust_boost_search_deck` — Wanderlust: transform from deck + opponent top-deck search

### Notable interaction gotchas
- `execute_strike` choices array must be flat per player, **not** nested arrays
- Wonderland card has no visual node → `find_card_on_board()` skip required

---

# Zsolt

Season 2, exceed cost **5** (reduced by 2 per transform). Difficulty ****.

## What is tested (29 tests)

### Normals & passives (6 tests)
- Zsolt normal passive: before a Zsolt normal hit, prompt to advance/retreat/pass
- Only NORMAL attacks trigger default passive (not specials/ultras)
- Somersault immediate boost (advance/retreat 2 + draw 1)
- Seeing Red immediate boost (life condition draws: low/medium life tested, scaling draw count)
- Heightened Reflexes immediate boost (advance/retreat 1 + bonus action)
- Battle Instinct continuous boost: -2 exceed cost +2 force pool (tested via `test_battle_instinct_force_pool`)

### Special attacks (8 tests)
- Fatal Eye: +1P per transform zone card (0/2/6 transforms tested)
- Cross Up: after advance 4
- Blaze of Fervour: hit advance 3, advanced-through = gain advantage
- Whip Crack: hit push/pull 1 + after advance/retreat 1
- Gunblaze: before "was hit" → choose draw 2 or +2P (tested with life check)
- Fanatical Purification: before close 3 → hit push 2 + gain advantage
- Wild Hunt: before close (save distance as X) → +X Power → after advance 9

### Exceed: extra attack (Awakening) (4 tests)
- 1 extra attack (pay 1 Force, at most 1 damage)
- 2 extra attacks (pay 1 Force each)
- Decline the extra attack
- Extra attack with Mad Dog (Blaze) / Press the Attack (Whip Crack) transformed

### Transform attacks (2 tests)
- Transforming an attack on hit adds card to transform zone (reduces exceed cost)
- Transformed attack status: Mad Dog (Blaze), Press the Attack (Whip Crack), and Battle Fugue (Cross Up) are
  validated, including their `transform_attack` on-hit offers.

### Notable interaction gotchas
- **Advancing *through* the opponent's space** does not count that space as
  movement and fires `advanced_through` (e.g. Blaze's gain-advantage). Verify via
  `EventType_GainAdvantage`.
- **Awakening `init_choices` shape:** `[[gauge_id], [attack_card_id], ...]`,
  repeated per extra attack, ending with `[]` to decline.

---

# AI stress testing (`test_randomai.gd`)

Both characters were added to the random-AI stress harness:

```gdscript
func test_eugenia_100():
    run_iterations_with_deck("eugenia")

func test_zsolt_100():
    run_iterations_with_deck("zsolt")
```

`test_randomai.gd` plays full AI-vs-AI games. With `const RandomIterations = 1`
(the checked-in default) each `*_100` test plays a single mirror match. Bumping
`RandomIterations` (e.g. to 100) plays the mirror once and then that character
against many *random* opponents, exercising a huge range of card interactions —
useful for surfacing engine crashes and AI-policy gaps.

### Running just one character's stress test

Combine `-gselect` (file) with `-gunit_test_name` (test-method substring):

```powershell
.\godotexe\Godot_v4.4.1-stable_win64_console.exe -s addons/gut/gut_cmdln.gd `
  "-gdir=res://test/unit" -gexit "-gselect=test_randomai" "-gunit_test_name=test_eugenia_100"
```

For a deterministic repro, seed the global RNG at the top of the test (e.g.
`seed(12345)`) so the same sequence of games replays every run — invaluable for
pinning down an intermittent crash.

### Bugs found & fixed via 100-iteration stress runs

Running `test_eugenia_100` / `test_zsolt_100` at 100 iterations surfaced (and we
fixed) these **new-character** issues:

1. **Wonderland placeholder had an invalid `owner_id` → stack overflow.**
   `AddToSetAsideImmediately` created the placeholder with
   `GameCard.new(next_id, card_def, next_id, ...)` — passing the random card id
   as the *owner*. Because that owner matched neither player,
   `Player.add_to_discards()` recursed forever (each player forwarding the card
   to the other). Fixed by using `performing_player.my_id` as the owner, plus a
   defensive guard in `add_to_discards` that discards locally instead of
   recursing when the owner matches neither player.
   (`scenes/core/local_game.gd`, `scenes/core/player.gd`)
2. **AI double-subtracted `free_gauge` when paying for Exceed.**
   `get_exceed_cost()` already nets out `free_gauge` (Zsolt's Battle Instinct),
   but the AI then routed that value through `get_combinations_to_pay_gauge()`
   which subtracted `free_gauge` a second time — underpaying and failing
   `do_exceed`. `get_exceed_actions()` now builds gauge combinations of exactly
   `get_exceed_cost()` cards. (`scenes/core/ai_player.gd`)
3. **Null-card logging crash.** `_get_boost_and_card_name()` dereferenced
   `card.definition` on a null card (e.g. `SustainThis` with an invalid id).
   Added a null guard. (`scenes/core/local_game.gd`)

After these fixes Eugenia ran 60 consecutive stress iterations (mirror + 59
random opponents) with no crashes, and Zsolt ran clean until the same
matchup below.

### Known pre-existing issue (NOT introduced by PR #208)

At high iteration counts, any character facing **Faust** can stall: when Faust
plays `faust_love` as a *mid-strike boost* whose `force_for_effect`
(`other_player: true`) targets the current player, the engine ends up parked in
`GameState_Strike_Processing` without resuming the strike (the
`continue_player_action_resolution` path after `do_force_for_effect`), which the
harness reports as repeated `Unexpected game state 11`. This reproduces
identically for Eugenia, Zsolt, and other initiators, so it is a general engine /
harness limitation, independent of the new characters, and is left as-is.