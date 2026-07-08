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
  - Popup dialog on each force payment, select 0~pool for free force
  - During combat, auto-select min(pool, amount), skip popup
  - Stacking: two Battle Instincts = pool=4, options 0/1/2/3/4
  - _recalc_zsolt_pool() recalculates from active boosts on add/remove
    to prevent drift

--- Zsolt: Extra Attack ---
  One extra attack per turn after exceeding.
  Second attack does NOT require first to hit.
  Card destination: hit = gauge, Block = not gauge (extra_attack_always_go_to_gauge)

--- Zsolt: Transform Exceed Discount ---
  exceed_cost_reduced_by: [{ "reduction_type": "transform_discount" }]

================================================================================
4. Special Effect Types Added
================================================================================

New constants in strike_effects.gd:
  RevealSingleCard            -- Reveal single hand card (not all)
  ReduceOpponentPrepareDraw   -- Opponent Prepare draws -1
  AddToSetAsideImmediately    -- Create card in set_aside on exceed
  OpponentDrawTo              -- Force opponent to draw to specified hand size
  ZsoltNormalPassive          -- Zsolt normal passive
  PowerupPerTransform         -- +1 Power per transform (Fatal Eye, max 5)
  ZsoltTransformExtra         -- Zsolt transform extra effect

New conditions:
  opponent_max_cards_in_hand  -- Check opponent hand <= N

New variables in player.gd:
  zsolt_battle_fugue_drew     -- Battle Fugue drawn this combat?
  zsolt_extra_attack_count    -- Extra attacks used this turn
  zsolt_awaken_offered        -- Awakening payment offered?
  zsolt_force_pool            -- Battle Instinct force pool value
  eugenia_normal_passive_used_this_turn -- Normal passive used this turn?

================================================================================
5. Known Traps & Notes
================================================================================

1. initialize_new_strike Timing
   initialize_new_strike() clears strike_stat_boosts.
   Wonderland +1P/+1S must be applied AFTER initialize_new_strike,
   or they get cleared. Applied on two paths: initiator and defender response.

2. add_to_hand Does Not Remove Source Zone
   add_to_hand() only appends to hand array; does NOT remove from original zone.
   When taking from set_aside, manually call remove_from_set_aside()
   first, then add_to_hand(), or the card exists in two zones and
   subsequent zone checks will process it twice.

3. Effect Source Tracking (_last_effect_source_player_id)
   Determines if discard was caused by a specific player's effect (e.g. Eugenia).
   Choice sub-effects need _source_player_id injected, otherwise the
   trigger check fails. and-handler sub-effect chains need save/restore
   to avoid pollution.

4. performing_player in choice effects
   do_choice()'s performing_player is "the one making the choice",
   NOT the original attacker. Effect directions in choice options
   must account for this context. Use for_other_player: true to
   reverse execution direction.

5. Missing Card Visual Node
   AddToSetAsideImmediately creates cards with no visual node (data layer only).
   create_event(AddToDiscard) crashes if it can't find a visual node.
   Check definition.id == "wonderland" to skip visual events.

6. Zsolt Force Pool Notes
   The following issues have been fixed in the current build:
   - Hand-to-Change force popup — implemented (2026-07-09)
   - Transform auto-fill override — protected with skip_zsolt_popup (2026-07-09)
   - Empty popup on Pass — removed unused select_boost_options = {} (2026-07-09)

7. X-Speed Card Matching
   Eugenia's normal passive matches printed speed (definition raw value).
   Special values like "CARDS_IN_HAND" are resolved to current numeric
   value before comparison. NOT affected by strike stat boosts.
   Only X-speed card in the game: Seijun's Ink Splash (speed: "CARDS_IN_HAND")

8. Wonderland Face Attack Button
   Uses buddy_exceeds flag to control buddy card visibility.
   Hidden before exceed, shown as Face Attack button after exceed.

================================================================================
6. Card Lists
================================================================================

Eugenia Specials:
  1. Shimmer of Madness   (1-2, 2P, 6S)  -- Reveal hand, discard 1
  2. Absinthin Arrow      (3-6, 2P, 5S)  -- Opponent draw 1, discard 2
  3. Plot Hook            (1-5, 3P, 4S)  -- Hit: pull 5 + advantage
  4. Werelight            (2-4, 4P, 3S)  -- Opponent: discard 2 / reveal+discard 1
  5. Color Spray          (1-3, 6P, 2S)  -- Discard to 2 hand cards

Eugenia Ultras:
  6. Queen of Hearts      (1-1, 1P, 7S)  -- Discard hand, draw 1, power=count
  7. Cat's Cradle         (1-3, 9P, 1S)  -- -1P/opponent hand card, discard 2

Eugenia Special:
  8. Wonderland           (1-3, 0P, 0S)  -- +1P/+1S face attack marker

Zsolt Specials:
  1. Fatal Eye             (1-3, 1P, 7S)  -- +1P/transform (max 5)
  2. Cross Up              (1-2, 4P, 6S)  -- After: advance 4
  3. Blaze of Fervour      (2-4, 4P, 5S)  -- Hit: advance 3, AD-through = adv.
  4. Whip Crack            (2-4, 3P, 4S)  -- Hit: push/pull 1, After: adv/ret 1
  5. Gunblaze              (1-4, 3P, 2S)  -- Before if hit: +2P or draw 2

Zsolt Ultras:
  6. Fanatical Purification(1-1, 6P, 4S)  -- Before: close 3, Hit: push 2 + adv
  7. Wild Hunt             (1-1, 5P, 3S)  -- Before: close 8, power=dist, adv 9

Zsolt Transforms:
  8. Somersault            (Fatal Eye)     -- Advance/Retreat 2 + draw 1
  9. Battle Fugue          (Cross Up)      -- First advantage per combat: draw 1
  10. Mad Dog              (Blaze)         -- Pay 1F: +1 Power
  11. Press the Attack     (Whip Crack)    -- Pay 1F: +1 Speed
  12. Seeing Red           (Gunblaze)      -- Life-based draw + bonus action
  13. Battle Instinct      (Fanatical Pur.)-- -2 cost +2 force pool
  14. Heightened Reflexes  (Wild Hunt)     -- Advance/Retreat 1 + bonus action

Eugenia Transforms:
  15. Unhinged             (Color Spray)   -- EX or X-speed: extra discard 1
  16. Off With Her Head    (Werelight)     -- Range 1: opponent discard 2 or push 3
  17. We're All Mad Here   (Absinthin)     -- Draw 0-4 then discard 1
  18. Hanging by a Thread  (Shimmer)       -- Opponent hand<=2: +2 Power
  19. Time for Tea         (Plot Hook)     -- Pay 1F: random discard 1 + skip draw
  20. Wanderlust           (Queen of H.)   -- Search top 30, pick 1 to hand
  21. Edge of Sanity       (Cat's Cradle)  -- Random discard 1 + reduce prepare draw

================================================================================
7. Version History
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

================================================================================
  End of README
================================================================================
