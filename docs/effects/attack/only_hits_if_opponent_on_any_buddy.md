# only_hits_if_opponent_on_any_buddy

**Category**: Attack
**Description**: Attack only hits if the opponent is standing on any buddy placed on the board.

## Parameters

- `buddy_name` (optional): Specific buddy name to check for
  - **Type**: String
  - **Range**: Any valid buddy name
  - **Default**: Checks for any buddy if not specified

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic buddy requirement:**
```json
{
  "timing": "during_strike",
  "effect_type": "only_hits_if_opponent_on_any_buddy"
}
```

**Specific buddy requirement:**
```json
{
  "timing": "during_strike",
  "effect_type": "only_hits_if_opponent_on_any_buddy",
  "buddy_name": "Ice Spike"
}
```

**Combined with buddy placement:**
```json
{
  "timing": "before",
  "effect_type": "place_buddy_onto_opponent",
  "buddy_name": "Ice Spike",
  "and": {
    "timing": "during_strike",
    "effect_type": "only_hits_if_opponent_on_any_buddy",
    "buddy_name": "Ice Spike"
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.only_hits_if_opponent_on_any_buddy = true`
- Checks opponent's position against all buddy locations
- Attack automatically misses if condition is not met
- Can specify particular buddy types or check for any buddy
- Useful for trap-based attacks or positional requirements
- Encourages strategic buddy placement and positioning
- Creates conditional hit mechanics based on board state

## Related Effects

- [place_buddy_onto_opponent](../buddy/place_buddy_onto_opponent.md) - Place buddy on opponent
- [place_buddy_at_range](../buddy/place_buddy_at_range.md) - Place buddy at specific range
- [attack_does_not_hit](attack_does_not_hit.md) - Force attack to miss
- [dodge_from_opposite_buddy](dodge_from_opposite_buddy.md) - Dodge based on buddy position

## Real Usage Examples

From card definitions:
- Iaquis' "Ice Spear": `{ "timing": "during_strike", "effect_type": "only_hits_if_opponent_on_any_buddy", "buddy_name": "Ice Spike" }`
- Trap-based characters: Attacks that require setup
- Area denial strategies: Forcing opponents into specific positions
- Combo attacks: Requiring buddy placement before hitting