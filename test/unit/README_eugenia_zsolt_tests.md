# Eugenia & Zsolt Test Suites

Unit tests validating the two Season 2 characters added in PR #208
(Eugenia "Cheshire Cat" and Zsolt). Both suites use the modern
`ExceedGutTest` base class and play against a clean **Ryu** opponent so the
opponent never triggers either character's passives.

- `test_eugenia.gd` — 21 tests
- `test_zsolt.gd` — 26 tests

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
"Wonderland". Difficulty ***.

## Mechanics under test

| Mechanic | Behaviour | Test(s) |
| --- | --- | --- |
| Exceed cost + transform discount | 6, then 4 with one transform, 2 with two | `test_exceed_cost_*` |
| Normal (non-exceeded) passive | Once/turn, when an Eugenia effect makes the opponent discard, she may reveal a hand card whose **printed speed** matches a discarded card's printed speed to deal **2 non-lethal damage**. Pass is always choice index 0. | `test_normal_passive_reveal_deals_nonlethal_damage`, `test_normal_passive_pass_declines` |
| Exceeded passive | While exceeded (normal passive suppressed), on an Eugenia-caused discard she may add a discarded card to Wonderland. `wonderland_add_card` **replaces** the placeholder (set-aside size stays 1, but the card becomes the chosen one). | `test_exceeded_passive_adds_card_to_wonderland` |
| Exceed | Costs gauge, places the Wonderland placeholder in set-aside, and ends her turn. | `test_exceed_places_wonderland_and_ends_turn` |
| Wonderland face attack | Only available once a real card has been added to Wonderland (set-aside size > 1). Base P0/S0 + during-strike +1P/+1S + exceeded face bonus +1P/+1S = **P2/S2**, range 1-3. | `test_wonderland_face_attack_bonus` |

## Attacks under test

| Card | Stats | Hit effect | Test |
| --- | --- | --- | --- |
| Shimmer of Madness | R1-2 P2 S6 | Reveal opponent hand, choose 1 card to discard | `test_shimmer_choose_discard` |
| Absinthin Arrow | R3-6 P2 S5 | Opponent draws 1, discards 2 random | `test_absinthin_arrow_damage_and_discard` |
| Plot Hook | R1-5 P3 S4 | Gain advantage + pull 5 (overshoots through Eugenia) | `test_plot_hook_pull_and_advantage` |
| Werelight | R2-4 P4 S3 | Opponent chooses discard 2 random / reveal + Eugenia discards 1 | `test_werelight_opponent_discards` |
| Color Spray | R1-3 P6 S2 | During: stun immunity if hand ≤ 2; hit: opponent discards to 2 | `test_color_spray_damage` |
| Queen of Hearts (Ultra) | R1-1 P1 S7, gauge 3 | Opponent discards hand, draws 1, Eugenia powers up | `test_queen_of_hearts_discard_hand` |
| Cat's Cradle (Ultra) | R1-3 P9 S1, gauge 3 | During: stun immunity, −1 Power per opponent hand card; hit: opponent draws 1, discards 2 | `test_cats_cradle_power_scales_with_opponent_hand` |

## Transforms under test

| Transform (boost of) | Effect | Test |
| --- | --- | --- |
| Hanging by a Thread (Shimmer) | set_strike: +2 Power if opponent has ≤ 2 cards | `test_hanging_by_a_thread_bonus_power` |
| Time for Tea (Plot Hook) | Bonus action: pay 1 Force → opponent discards 1 random | `test_time_for_tea_action_discards` |
| Off With Her Head (Werelight) | Immediate boost at range 1: opponent chooses discard 2 / push 3 | `test_off_with_her_head_boost_discards` |
| Edge of Sanity (Cat's Cradle) | Continuous boost: opponent discards 1 random + reduces their Prepare draw | `test_edge_of_sanity_boost_discards` |
| Unhinged (Color Spray) | set_strike: on an EX (or wild-swing) strike, add hit → opponent discards 1 | `test_unhinged_adds_discard_on_ex_strike` |

## Notable interaction gotchas

- **Any Eugenia effect that makes the opponent discard triggers a passive
  decision.** Non-exceeded → normal-passive `EffectChoice` (Pass = idx 0).
  Exceeded → exceeded-passive `EffectChoice` (Pass = idx 0, add-to-Wonderland at
  idx ≥ 1). Tests always account for this extra decision.
- **Transform-boost specials (Shimmer, Plot Hook, Color Spray) offer a
  `transform_attack` `EffectChoice` when the attack HITS** (transform = idx 0,
  pass = idx 1) — regardless of whether the transform is already in the zone.
- **A `powerup` hit effect added by a standing transform produces a
  `ChooseSimultaneousEffect` ordering decision** alongside the attack's own hit
  effects. Ordering does not change the damage outcome.
- **`choose_opponent_card_to_discard` is a `ChooseToDiscard`** where Eugenia
  picks from the *opponent's* revealed hand; pass a real opponent card id. Give
  the opponent a known card beforehand.
- **Dive is a poor defender for the Wonderland face attack** — its `advance 3 /
  dodge` moves it out of range so the face attack misses (and can trigger an
  engine cleanup recursion). Use a stationary defender such as Grasp at a range
  where it misses but the R1-3 face attack still hits.

---

# Zsolt

Season 2, exceed cost **5** (reduced by transforms; Battle Instinct reduces it
further). Difficulty ****.

## Mechanics under test

| Mechanic | Behaviour | Test(s) |
| --- | --- | --- |
| Exceed cost + transform discount | 5, reduced 2 per transform | `test_exceed_cost_*` |
| Normal (non-exceeded) passive | Normals gain a hit `EffectChoice`: advance 1 (idx 0) / retreat 1 (idx 1) / pass (idx 2). Suppressed while exceeded. | normal-passive tests |
| Awakening (exceeded) extra attack | After exceeding: pay 1 Force (`ForceForEffect`) then play an attack from hand (`ChooseToDiscard`), up to 2×/turn. The extra attack deals at most 1 damage and does not require the first to hit. | awakening tests |
| Transform-attack | Transform-boost specials (Cross Up, Blaze, Whip Crack) offer a `transform_attack` when the attack HITS (transform idx 0 / pass idx 1). Immediate/continuous boosts do not. | transform tests |

## Attacks under test

Fatal Eye, Cross Up, Blaze of Fervour, Whip Crack, Gunblaze, Fanatical
Purification (Ultra) and Wild Hunt (Ultra) each have a dedicated damage/effect
test. Movement effects (advance/retreat/close), `advanced_through` advantage,
and `powerup_per_transform` (Fatal Eye, cap 5) are validated.

## Transforms under test

Mad Dog (Blaze), Press the Attack (Whip Crack), and Battle Fugue (Cross Up) are
validated, including their `transform_attack` on-hit offers.

## Notable interaction gotchas

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
