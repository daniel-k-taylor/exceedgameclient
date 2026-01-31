# Copilot Instructions for Exceed Card Game

## Build & Test Commands

**Run all tests:**
```bash
..\Godot_v4.4.1-stable_win64.exe -s addons/gut/gut_cmdln.gd -gdir=res://test\unit -gexit
```

Running all tests takes a long time! So only run individual tests when developing unless feature hits many parts of the codebase.

**Run a single test file:**
```bash
..\Godot_v4.4.1-stable_win64.exe -s addons/gut/gut_cmdln.gd -gdir=res://test\unit -gexit -gtest=test_ryu.gd
```

**Run the game:**
```bash
..\Godot_v4.4.1-stable_win64.exe
```

Tests use the [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) framework. Test output is verbose - pipe through `Select-String` to filter.

## Architecture Overview

### Core Engine
- `scenes/core/local_game.gd` - Main game engine (~10k lines). Handles all game logic, strike resolution, and effect processing
- `scenes/core/player.gd` - Player state including hand, gauge, life, arena location, and `StrikeStatBoosts` class for strike modifiers
- `scenes/core/strike_effects.gd` - Constants for all 340+ effect types
- `scenes/core/enums.gd` - Game constants (arena size 1-9, max life 30, hand size 7) and all enum types

### Data-Driven Cards
- `data/card_definitions.json` - All card definitions with stats and effects
- `data/decks/*.json` - Character decks (90+ characters) containing:
  - `ability_effects` / `exceed_ability_effects` - Character passive abilities
  - `character_action_default` / `character_action_exceeded` - Character actions
  - `cards` - References to card definitions with images

### Effect System
Effects are JSON objects with `timing`, `effect_type`, and parameters. Common timings:
- `now` / `immediate` - When card is played
- `set_strike` - When setting attack card
- `before` / `during_strike` / `hit` / `after` - Strike resolution phases
- `cleanup` - End of strike

Effects can chain with `and` or provide options with `choice`. See `docs/effects/` for comprehensive documentation.

### Autoloaded Globals
Defined in `project.godot`:
- `CardDataManager` - Loads and provides access to card/deck definitions
- `NetworkManager` - Client-server communication
- `GlobalSettings` - User preferences
- `ImageCache` - Card image caching

## Testing Conventions

### Test Base Classes
**Legacy style** (extends `GutTest` directly):
```gdscript
extends GutTest

var default_deck = CardDataManager.get_deck_from_str_id("ryu")
const TestCardId1 = 50001  # Manual card ID constants

func give_player_specific_card(player, def_id, card_id):
    # Must pass card_id explicitly
```

**Modern style** (preferred for new tests):
```gdscript
extends ExceedGutTest

func who_am_i():
    return "charactername"  # Returns character ID for deck loading
```

The `ExceedGutTest` base class (`test/exceed_test.gd`) provides:
- Automatic game setup with `who_am_i()` character
- `give_player_specific_card(player, def_id)` - Returns auto-generated card ID
- `execute_strike(initiator, defender, init_card, def_card, ...)` - Comprehensive strike helper
- `process_decisions()` / `process_remaining_decisions()` - Decision handling
- Helper functions: `position_players()`, `give_gauge()`, `validate_life()`, `validate_positions()`, `advance_turn()`

### Test Patterns
```gdscript
func test_example():
    position_players(player1, 3, player2, 6)
    give_gauge(player1, 2)

    # execute_strike handles card creation, strike initiation, and decision processing
    execute_strike(player1, player2, "standard_normal_assault", "standard_normal_cross",
        false, false,  # EX flags
        [0, []],       # initiator decisions (choice indices, card arrays)
        [])            # defender decisions

    validate_positions(player1, 4, player2, 6)
    validate_life(player1, 27, player2, 26)
```

### Decision Types
Tests must handle game decisions in order. Use `game_logic.decision_info.type` to check:
- `DecisionType_EffectChoice` - Choose between effect options (`do_choice(player, index)`)
- `DecisionType_ForceForEffect` - Discard cards for effect (`do_force_for_effect()`)
- `DecisionType_GaugeForEffect` - Spend gauge (`do_gauge_for_effect()`)
- `DecisionType_ReadingNormal` - Name opponent's card (`do_boost_name_card_choice_effect()`)
- `DecisionType_ChooseArenaLocationForEffect` - Pick arena space

### Validating Events
```gdscript
var events = game_logic.get_latest_events()
validate_has_event(events, Enums.EventType.EventType_Strike_Critical, player1)
validate_not_has_event(events, Enums.EventType.EventType_Strike_Miss, player1)
```

## Key Conventions

### Character Definition Structure
```json
{
    "id": "charactername",
    "exceed_cost": 3,
    "ability_effects": [...],
    "exceed_ability_effects": [...],
    "character_action_default": [...],
    "cards": [
        { "definition_id": "charactername_cardname", "image_name": "specials", "image_index": 0 }
    ]
}
```

### Effect Conditions
Effects can have `condition` fields checked at runtime:
- `is_critical`, `exceeded`, `initiated_strike`
- `used_character_bonus` - Set by `set_used_character_bonus` effect
- `hit_opponent`, `stunned`, `was_hit`

### Strike Resolution Order
1. Set effects (both players)
2. Pay costs
3. During strike bonuses
4. Card1 (faster) activation → before → determine hit → hit → apply damage → after
5. Card2 activation (if not stunned) → same phases
6. Cleanup → End of strike

### Arena Positions
- Arena spaces: 1-9 (center is 5)
- Players face each other, can't occupy same space
- Distance = `abs(p1.arena_location - p2.arena_location)`

## Documentation
- `docs/effects/` - Comprehensive effect documentation (340+ effects)
- `docs/effects/documentation_instructions.md` - Template for documenting new effects
