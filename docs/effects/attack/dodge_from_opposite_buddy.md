# dodge_from_opposite_buddy

**Category**: Attack
**Description**: Dodge attacks when the opponent is positioned on the opposite side of a specified buddy.

## Parameters

- `buddy_name` (required): Name of the buddy to use for positional reference
  - **Type**: String
  - **Range**: Any valid buddy name
  - **Special Values**: Must match buddy names placed on the board

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic opposite buddy dodge:**
```json
{
  "timing": "during_strike",
  "effect_type": "dodge_from_opposite_buddy",
  "buddy_name": "Shield Knight"
}
```

**Combined with buddy placement:**
```json
{
  "timing": "before",
  "effect_type": "place_buddy_at_range",
  "buddy_name": "Guardian",
  "range": 2,
  "and": {
    "timing": "during_strike",
    "effect_type": "dodge_from_opposite_buddy",
    "buddy_name": "Guardian"
  }
}
```

**Conditional buddy dodge:**
```json
{
  "condition": "buddy_in_play",
  "effect_type": "dodge_from_opposite_buddy",
  "buddy_name": "Protector"
}
```

## Implementation Notes

- Sets `strike_stat_boosts.dodge_from_opposite_buddy = true`
- Creates "DodgeFromOppositeBuddy" event with buddy name
- Calculates relative positions of character, buddy, and opponent
- Dodges attacks when opponent is on the opposite side of the specified buddy
- Requires the named buddy to be present on the board
- Creates tactical positioning gameplay around buddy placement
- Log message indicates dodging attacks from opponents behind the buddy

## Related Effects

- [dodge_attacks](dodge_attacks.md) - Complete attack evasion
- [dodge_at_range](dodge_at_range.md) - Range-based dodging
- [place_buddy_at_range](../buddy/place_buddy_at_range.md) - Place buddy for positioning
- [only_hits_if_opponent_on_any_buddy](only_hits_if_opponent_on_any_buddy.md) - Opposite positioning requirement

## Real Usage Examples

From card definitions:
- Shovel Knight's defensive techniques: `{ "timing": "during_strike", "effect_type": "dodge_from_opposite_buddy", "buddy_name": "Shield Knight" }`
- Buddy-based defensive strategies: Using allies for protection
- Positional combat: Strategic buddy placement for defense
- Team-based mechanics: Coordinating with placed allies