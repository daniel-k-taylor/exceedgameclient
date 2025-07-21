# dodge_at_range

**Category**: Attack
**Description**: Dodge attacks when the attacker is within a specific range or when special range conditions are met.

## Parameters

- `range_min` (optional): Minimum range for dodging
  - **Type**: Integer
  - **Range**: Any positive integer
  - **Default**: Uses special range if not specified

- `range_max` (optional): Maximum range for dodging
  - **Type**: Integer
  - **Range**: Any positive integer
  - **Default**: Same as range_min if not specified

- `special_range` (optional): Special range calculation method
  - **Type**: String
  - **Special Values**: "OVERDRIVE_COUNT" - Use overdrive count as range
  - **Default**: None

- `buddy_name` (optional): Buddy name for positional calculations
  - **Type**: String
  - **Range**: Any valid buddy name
  - **Default**: None

## Supported Timings

- `during_strike` - During strike resolution
- `after` - After strike resolution

## Examples

**Basic range dodging:**
```json
{
  "timing": "during_strike",
  "effect_type": "dodge_at_range",
  "range_min": 1,
  "range_max": 3
}
```

**Single range dodge:**
```json
{
  "timing": "during_strike",
  "effect_type": "dodge_at_range",
  "range_min": 4,
  "range_max": 4
}
```

**Overdrive-based dodging:**
```json
{
  "timing": "during_strike",
  "effect_type": "dodge_at_range",
  "special_range": "OVERDRIVE_COUNT"
}
```

**Buddy-based range:**
```json
{
  "timing": "during_strike",
  "effect_type": "dodge_at_range",
  "range_min": 2,
  "range_max": 4,
  "buddy_name": "Shield"
}
```

## Implementation Notes

- Creates "DodgeAttacksAtRange" event with range parameters
- Checks current range between characters for dodge activation
- Can use dynamic range calculations with special_range parameter
- Range calculations include all positioning modifiers
- Often used for tactical positioning and defensive play
- Combines well with movement effects and range control
- Range checking occurs during strike resolution

## Related Effects

- [dodge_attacks](dodge_attacks.md) - Complete attack evasion
- [dodge_normals](dodge_normals.md) - Dodge only normal attacks
- [dodge_from_opposite_buddy](dodge_from_opposite_buddy.md) - Buddy-based dodging
- [higher_speed_misses](higher_speed_misses.md) - Speed-based evasion

## Real Usage Examples

From card definitions:
- Various defensive characters: `{ "timing": "during_strike", "effect_type": "dodge_at_range", "range_min": 4, "range_max": 4 }`
- Range control strategies: Positioning for optimal dodge ranges
- Defensive counters: Avoiding specific range attacks
- Overdrive mechanics: Dynamic dodging based on resource levels