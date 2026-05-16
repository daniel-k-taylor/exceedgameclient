# Exceed Card Game - Character Implementation Guide

This guide distills the process of implementing a new character from scratch, based on lessons learned from implementing Geoffrey and Taisei (Season 2 / Seventh Cross).

## Step 1: Research the Character

1. **Read the wiki page** at `https://old.reddit.com/r/eXceed/wiki/card_db/seventhcross/<charname>/` (use old.reddit.com - regular reddit blocks scrapers)
2. **Record all card stats** precisely: Range, Power, Speed, Armor, Guard, Gauge cost, Force cost
3. **Identify all effects** and their timings (Before, During, Hit, After, Cleanup)
4. **Note the character's unique ability** (starting + exceed) — these are the trickiest parts
5. **Identify transform vs boost cards** — Transform cards have `T` as force cost

## Step 2: Analyze What Already Exists

Before writing any new engine code, check if the effects you need already exist:

### Key Files to Search
- `scenes/core/strike_effects.gd` — All 340+ effect type constants
- `scenes/core/local_game.gd` — Effect implementations (search for `StrikeEffects.<Name>:`)
- `scenes/core/player.gd` — Player state, stat boosts (`StrikeStatBoosts` class)
- `data/decks/*.json` — Existing character patterns to copy from

### Common Effect Types (already implemented)
| Effect | Constant | Notes |
|--------|----------|-------|
| +N Power | `powerup` | `amount` field |
| +N Speed | `speedup` | `amount` field |
| +N Armor | `armorup` | `amount` field |
| +N Guard | `guardup` | `amount` field |
| Gain N life | `gain_life` | `amount` field, caps at MaxLife (30) |
| Spend N life | `spend_life` | `amount` field, triggers `on_death` if life ≤ 0 |
| Push N | `push` | `amount` field |
| Pull N | `pull` | `amount` field |
| Close N | `close` | `amount` field |
| Retreat N | `retreat` | `amount` field |
| Advance N | `advance` | `amount` field |
| Draw N | `draw` | `amount` field |
| Ignore Armor | `ignore_armor` | No amount needed |
| Ignore Guard | `ignore_guard` | No amount needed |
| Stun Immunity | `stun_immunity` | No amount needed |
| Gain Advantage | `gain_advantage` | No amount needed |
| Cannot go below N life | `cannot_go_below_life` | `amount` field, checked during damage |
| Spend life for force | `can_spend_life_for_force` | `amount` = force per life |
| Opponent can't move past | `opponent_cant_move_past` | Blocks advance through |
| Ignore push/pull | `ignore_push_and_pull` | During strike only |

### Conditions (already implemented)
- `exceeded`, `not_exceeded`, `initiated_strike`, `is_critical`
- `opponent_stunned`, `was_hit`, `hit_opponent`
- `used_character_bonus`, `life_equal_or_below`, `life_above`
- `opponent_printed_speed_greater`, `advanced_through`

### Timings
- `now` / `immediate` — When card is played/boosted
- `set_strike` — When attack card is set
- `before` / `during_strike` / `hit` / `after` / `cleanup` — Strike resolution phases
- `when_hit` — When this player is hit
- `on_spend_life` — When this player spends life (not damage taken)
- `end_of_turn` — At end of turn

## Step 3: Create the Deck JSON

**File**: `data/decks/<charname>.json`

### Required Fields
```json
{
    "id": "<charname>",
    "season": 2,
    "display_name": "<Display Name>",
    "exceed_cost": 5,
    "exceed_cost_reduced_by": [{ "reduction_type": "transform_discount" }],
    "ability_effects": [...],
    "exceed_ability_effects": [...],
    "image_resources": { ... },
    "cards": [...]
}
```

### Optional Fields
- `"starting_life": 15` — Override default 30
- `"on_death": { "condition": "not_exceeded", "effect_type": "exceed_now" }` — Exceed on death
- `"on_exceed": { ... }` — Effect when exceeding (e.g., set life)
- `"character_action_default": [...]` — Character action before exceed
- `"character_action_exceeded": [...]` — Character action after exceed

### S2 Transform Pattern
Transform cards use `"force_cost": -1` (displayed as "T"). Each transform reduces exceed cost by 2 via `transform_discount`.

```json
{
    "boost_type": "transform",
    "force_cost": -1,
    "display_name": "Transform Name",
    "effects": [...]
}
```

### S2 Image Resources
All S2 characters share these URLs:
- Normals: `https://i.imgur.com/1pnJnEb.jpeg`
- Cardback: `https://i.imgur.com/s6wpKBq.jpeg`
- Character/Exceeded/Specials: Unique per character

### Card Deck Structure
30 cards total: 14 specials (7 unique × 2) + 16 normals (8 unique × 2)

## Step 4: Create Card Definitions

**File**: `data/card_definitions.json`

Add card definitions with all stats. Use existing cards as templates. Important notes:
- `"id"` format: `"<charname>_<cardname>"` (lowercase, no spaces)
- All stats must match the wiki exactly
- Effects use `"timing"` and `"effect_type"` fields
- Chain effects with `"and"` field
- Provide choices with `"choice"` array

### Stun Rule
Stun occurs when `total_damage > guard` (strictly greater, NOT >=). This matters for damage calculations in tests.

## Step 5: Implement Engine Code

### When to Add New Code
Only add new engine code for effects that don't exist yet. Most card effects can be expressed purely through JSON definitions.

### Where to Add New Effects
1. Add constant to `scenes/core/strike_effects.gd`
2. Add handling in `scenes/core/local_game.gd` in the appropriate `match` block:
   - `handle_strike_effect()` for most effects
   - `apply_damage()` for damage modification
   - `on_death()` for death prevention
3. Add player state in `scenes/core/player.gd` if needed
4. Add game string in `globals/game_strings.gd` if the effect needs display text

### Patterns for Common Needs
- **Passive that persists outside strikes**: Use `ignore_push_and_pull_passive_bonus` pattern — increment a counter on `now` timing, decrement on `discarded`
- **Character ability**: `ability_effects` array in deck JSON, with `"character_effect": true`
- **Exceed replaces starting ability**: `exceed_ability_effects` in deck JSON; mid-strike exceed handling is automatic via `handle_mid_strike_exceed()`

## Step 6: Write Tests

**File**: `test/unit/test_<charname>.gd`

### Test Structure
```gdscript
extends ExceedGutTest

func who_am_i():
    return "<charname>"
```

This creates a mirror match (both players are the character).

### Key Testing Patterns
- Use `position_players(p1, loc1, p2, loc2)` to set positions
- Use `give_gauge(player, amount)` to give gauge cards (returns array of card IDs)
- Use `give_player_specific_card(player, "card_def_id")` to give specific cards (returns card ID)
- Use `execute_strike(...)` for strike tests
- Use `validate_life(p1, expected1, p2, expected2)` to check life
- Use `validate_positions(p1, loc1, p2, loc2)` to check positions
- Use `advance_turn(player)` to pass a turn

### Decision Handling in execute_strike
The 7th and 8th parameters are initiator/defender decision arrays:
- `[]` = no decisions
- `[0]` = choose first option
- `[1]` = choose second option
- `[gauge_ids]` = pay gauge cost
- `[[card_ids]]` = force for effect (inner array of card IDs to discard)
- For Block's ForceForArmor: always provide `[[]]` (empty force payment)

### Test Coverage Checklist
For each card, test:
- [ ] Strike attack with key effects triggering
- [ ] Strike attack where effects don't trigger (conditions not met)
- [ ] Boost effect
- [ ] Transform effect (if applicable)
- [ ] Edge cases (out of range, stunned, etc.)

Also test:
- [ ] Starting ability
- [ ] Exceed ability
- [ ] Exceed on-exceed effects
- [ ] Interactions between character effects

### Important: Verify Damage Math
Always comment the expected damage calculation in tests:
```gdscript
# Card(S5) vs OppCard(S3). Card faster.
# P4 vs A0 = 4 damage. G3: 4>3 → stunned.
# OppCard stunned, doesn't resolve.
```

## Step 7: UI Integration

### Required Changes
1. **Portrait**: `assets/portraits/<charname>.png` (should already exist from batch import)
2. **Animation**: `assets/character_animations/<charname>/animations.tres`
   - S2 chars with sprites use `metadata/scaling = 0.07`
3. **Character Select**: Add to `scenes/menu/char_select.tscn`
   - Add to `SCCharacterSelect` (Season 2 section)
   - Need ext_resource, node with char_id/portrait_texture, two signal connections
4. **Game Strings**: `globals/game_strings.gd` — Add display strings for any new effects
5. **Random AI Test**: Add `test_<charname>_100()` to `test/unit/test_randomai.gd`

## Common Pitfalls

1. **Block always triggers ForceForArmor** when the Block user is hit — always provide `[[]]` in defender decisions
2. **Transform choice is only offered if the card HIT** and the boost_type is "transform"
3. **Stun is strictly greater than** (`damage > guard`), not `>=`
4. **Mirror match**: Both players have the same ability — account for this in damage math
5. **`on_death` fires from `spend_life` too** — not just from strike damage
6. **Comments must match code** — Always verify damage math comments are accurate
7. **Use `overall_effect` for all-or-nothing effects**, not `per_force_effect`
8. **Movement effects**: `block_opponent_move` blocks SELF-moves; `ignore_push_and_pull` blocks being pushed/pulled
9. **Test that tests actually test what they claim** — e.g., a "stun immunity" test should use an attack that would actually stun without immunity

## Workflow Summary

1. Research → Wiki page + card stats
2. Analyze → Search codebase for existing effects
3. Deck JSON → Create character definition
4. Card definitions → Add to card_definitions.json
5. Engine code → Only for truly new mechanics
6. Tests → Comprehensive test suite, verify damage math
7. UI → Portrait, animations, char select, game strings, random AI test
8. Rubber duck review → Audit tests for correctness before finalizing
9. Commit → With proper authorship and co-author trailer
