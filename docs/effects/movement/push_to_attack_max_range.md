# push_to_attack_max_range

**Category**: Movement
**Description**: Push the opponent to the maximum range of the performing character's attack.

## Parameters

- No parameters - automatically uses the character's maximum attack range

## Supported Timings

- `hit` - When attack hits

## Examples

**Basic push to max range:**
```json
{
  "timing": "hit",
  "effect_type": "push_to_attack_max_range"
}
```

## Implementation Notes

- Uses `get_total_max_range()` to determine the performing character's maximum attack range
- Calculates target position based on maximum range from performing character's location
- If opponent is already at or beyond maximum range, no movement occurs
- If opponent is closer than maximum range, pushes them away to exactly maximum range
- Useful for maintaining optimal spacing after successful attacks
- Respects arena boundaries and cannot push opponent beyond valid spaces

## Related Effects

- [push_to_range](push_to_range.md) - Push to specific attack range
- [push](push.md) - Basic push movement
- [pull_to_range](pull_to_range.md) - Pull to attack range
- [push_from_source](push_from_source.md) - Push from attack origin

## Real Usage Examples

From card definitions:
- Various character attacks: `{ "timing": "hit", "effect_type": "push_to_attack_max_range" }`
- Spacing control for zoning characters
- Maintaining optimal distance after successful hits
- Defensive positioning to prevent opponent rushdown