# remove_generate_free_force

**Category**: Force
**Description**: Remove all free force from the player.

## Parameters

None - this effect removes all free force.

## Supported Timings

- `immediate` - Immediately when triggered
- `now` - Immediately when played
- `after` - After strike resolution

## Examples

**Basic usage:**
```json
{
  "timing": "immediate",
  "effect_type": "remove_generate_free_force"
}
```

**After effect cleanup:**
```json
{
  "timing": "after",
  "effect_type": "remove_generate_free_force"
}
```

## Implementation Notes

- Sets player's `free_force` to 0
- Removes all previously generated free force
- Does not affect normal force generation
- Used to end free force effects
- Creates log message about force removal

## Related Effects

- [generate_free_force](generate_free_force.md) - Generate free force
- [generate_free_force_cc_only](generate_free_force_cc_only.md) - Restricted free force
- [force_for_effect](force_for_effect.md) - Spend force for effects

## Real Usage Examples

From card definitions:
- End-of-turn cleanup effects
- Counters to free force generation
- Effect expiration management