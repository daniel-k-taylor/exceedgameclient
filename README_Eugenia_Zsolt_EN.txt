================================================================================
  EXCEED - Eugenia (Cheshire Cat) & Zsolt Development Notes
================================================================================

This document records the development process, engine extensions, and
implementation details for adding Eugenia (Cheshire Cat) and Zsolt to the
EXCEED card game client.

================================================================================
1. Character Overview
================================================================================

Eugenia (Cheshire Cat):
  - Origin: Seventh Cross
  - Season: 2
  - Exceed Cost: 6 (reduced by transforms)
  - Core Mechanics: Wonderland, passive discard trigger, speed matching
  - Difficulty: ***

Zsolt:
  - Origin: Seventh Cross
  - Season: 2
  - Exceed Cost: 5 (reduced by transforms, further reduced by Battle Instinct)
  - Core Mechanics: Battle Instinct force pool, extra attack, transform discount
  - Difficulty: ****

================================================================================
2. File Structure
================================================================================

New files:
  data/decks/eugenia.json      -- Eugenia deck definition
  data/decks/zsolt.json        -- Zsolt deck definition

Modified files:
  data/card_definitions.json   -- Card definitions appended (alphabetical order)
  scenes/core/local_game.gd    -- Engine: new effects, passives, Wonderland, etc.
  scenes/core/player.gd        -- Player state: new vars, set_aside, transform intercept
  scenes/core/strike_effects.gd-- Effect type constants
  scenes/game/game.gd          -- UI: Wonderland button, Zsolt pool popup, boost desc
  globals/game_strings.gd      -- Effect description strings
  scenes/menu/char_select.tscn -- Character selection screen

Image resources:
  All images use remote imgur URLs. No local files.

================================================================================
3. Core Mechanic Implementations
================================================================================

--- Eugenia: Wonderland ---
Wonderland is a "set_aside + buddy + face_attack" triple system:
  1. set_aside: cards stored in player.gd's set_aside_cards[] array
  2. buddy: UI display configured via eugenia.json buddy_exceeds/buddy_card fields
  3. face_attack: on_exceed uses set_face_attack to enable Wonderland as a
     strike option

When using Wonderland as a face attack while exceeded, auto-grant
+1 Power / +1 Speed. Constants at top of local_game.gd:
  const WonderlandPowerBonus = { "effect_type": StrikeEffects.Powerup,
    "amount": 1, "character_effect": true }
  const WonderlandSpeedBonus = { "effect_type": StrikeEffects.Speedup,
    "amount": 1, "character_effect": true }
Two separate constants to avoid duplicate display.

--- Eugenia: Normal Passive ---
"Once per turn, when you make opponent discard":
  1. Check discarded card's printed speed (raw definition value)
  2. Find cards in Eugenia's hand with the same printed speed
  3. May reveal one matching card to deal 2 non-lethal damage
  4. X-speed cards (e.g. "CARDS_IN_HAND") are resolved to current value
     before comparison (e.g. Ink Splash = speed 3 when opponent has 3 cards)

  Note: Matches printed speed only, NOT affected by strike stat boosts
  (speedup/powerup).

--- Eugenia: Exceeded Passive ---
When opponent discards due to Eugenia's effect, pick one discarded card
to add to Wonderland (set_aside).

--- Eugenia: Special Card Effects ---
  - Shimmer of Madness: hit reveals hand, choose 1 to discard
  - Absinthin Arrow: hit opponent draws 1, discards 2 (random)
  - Plot Hook: hit pull 5 + gain advantage
  - Werelight: hit opponent chooses discard 2 or reveal & discard 1
  - Color Spray: during_strike stun immune (hand<=2), hit discard to 2
  - Queen of Hearts (Ultra): hit discard opponent's hand, draw 1,
    power = discarded count
  - Cat's Cradle (Ultra): during_strike -1P per opponent hand card,
    stun immune

--- Zsolt: Battle Instinct Force Pool ---
  - generate_free_force: 2 creates force pool (zsolt_force_pool), free_force = 0
  - gauge_costs_reduced_passive: 2 reduces exceed cost by 2

--- Zsolt: Exceed Ability (Awakening) ---
After a hit, pay 1 Force to perform an extra attack from hand
(max 2 per turn, at most 1 damage, cost skipped).

--- Zsolt: Normal Passive ---
Whenever a Zsolt NORMAL attack hits, he may Advance 1, Retreat 1, or Pass.

--- Zsolt: Special Card Effects ---
  - Fatal Eye: before +1P per transform (max 5), hit gain advantage
  - Cross Up: after advance 4
  - Blaze of Fervour: hit advance 3, if advanced-through gain advantage
  - Whip Crack: hit choice push/pull 1, after choice advance/retreat 1
  - Gunblaze: before if hit choose +2P or draw 2, hit close 3
  - Fanatical Purification (Ultra): before close 3, hit push 2 + adv
  - Wild Hunt (Ultra): before close 8 (save as X), +X Power, after adv 9

--- Zsolt: Transforms ---
  - Somersault (Fatal Eye): immediate advance/retreat 2 + draw 1
  - Battle Fugue (Cross Up): first advantage per combat -> draw 1
  - Mad Dog (Blaze): set_strike pay 1F -> +1 Power
  - Press the Attack (Whip Crack): set_strike pay 1F -> +1 Speed
  - Seeing Red (Gunblaze): life-based draw + bonus action
  - Battle Instinct (Fanatical Purification): continuous, +2 force pool, -2 gauge costs
  - Heightened Reflexes (Wild Hunt): immediate advance/retreat 1 + bonus action

--- Eugenia: Transforms ---
  - Hanging by a Thread (Shimmer): set_strike if opp <=2 cards +2 Power
  - We're All Mad Here (Absinthin): immediate both draw 0-4 then discard 1
  - Time for Tea (Plot Hook): action pay 1F -> opponent discard 1 random
  - Off With Her Head (Werelight): immediate range 1 opp discard 2 or push 3
  - Unhinged (Color Spray): set_strike EX or wild strike -> on hit discard 1
  - Wanderlust (Queen of Hearts): action search top 30, pick 1 to hand
  - Edge of Sanity (Cat's Cradle): continuous opp discard 1 + reduce prepare draw

================================================================================
4. Known Traps & Lessons Learned
================================================================================

1. initialize_new_strike Timing
   initialize_new_strike() clears strike_stat_boosts.
   Wonderland +1P/+1S must be applied AFTER initialize_new_strike,
   or they get cleared. Applied on two paths: initiator and defender response.

2. Parser Error "Expected indented block after 'if' block"
   Usually a tab-indentation issue in game.gd's update_boost_summary.
   The engine uses tabs, but fuzzy match in diffs can introduce spaces.
   Fix: ensure tab indentation.

3. Choice Effects
   - opponent: true -> choice interface goes to opponent
   - performing_player in do_choice() is the one who chooses
   - Effect direction in choices needs to consider this context

4. for_other_player Effects
   handle_strike_effect has a global for_other_player swap at the top.
   Don't swap again inside effects. Use non-conflicting keys for custom checks.

5. Card Visual Node
   AddToSetAsideImmediately creates cards with no visual node (data layer only).
   create_event(AddToDiscard) crashes if it can't find a visual node.
   Check definition.id == "wonderland" to skip visual events.

6. Zsolt Force Pool Notes
   zsolt_force_pool accumulates across multiple Battle Instinct uses.
   begin_generate_force_selection: popup offers 0..pool choices for normal force payments.
   ForForceEffect: auto min(pool, force_max) to avoid popup during strike.

7. X-speed Cards
   Only X-speed card in the game: Seijun's Ink Splash (speed: "CARDS_IN_HAND")
   Resolved to current numeric value before printed-speed comparison.

8. Wonderland Face Attack Button
   Uses buddy_exceeds flag to control buddy card visibility.
   Hidden before exceed, shown as Face Attack button after exceed.

================================================================================
5. Version History
================================================================================

v1.0 - Initial Eugenia import
v2.0 - Wonderland mechanic
v3.0 - Bug fixes and polish
v3.1 - Wonderland button visible only after exceed
v3.2 - ForceForEffect cancel fix
v3.3 - Wonderland sealed card handling, Axl Idealism nesting fix
v3.4 - Color Spray passive fix, Edge of Sanity direction fix
v3.5 - Werelight source tracking fix, Boost push direction fix
v3.6 - Normal passive X-speed card matching
v4.0 - Migrated from custom_card_definitions to core card_definitions
v4.1 - Edge of Sanity cleanup fix
v4.2 - Test suite added: 25 Eugenia tests + 29 Zsolt tests (PR #208 merge)
v4.3 - Synced upstream card_definitions.json fix (PR #208); Fixed block force-for-armor discard falsely triggering Eugenia passive (reset _last_effect_source_player_id in do_hit_response_effects)

================================================================================
  End of README
================================================================================