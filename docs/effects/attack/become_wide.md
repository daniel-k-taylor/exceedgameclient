# become_wide

**Category**: Attack
**Description**: Transform the character into a wide form, typically changing their appearance and potentially affecting game mechanics.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution
- `now` - Immediately when played

## Examples

**Basic wide transformation:**
```json
{
  "timing": "during_strike",
  "effect_type": "become_wide"
}
```

**Immediate transformation:**
```json
{
  "timing": "now",
  "effect_type": "become_wide",
  "description": "Tinker Tank"
}
```

**Combined with other effects:**
```json
{
  "timing": "during_strike",
  "effect_type": "become_wide",
  "and": {
    "effect_type": "powerup",
    "amount": 3
  }
}
```

## Implementation Notes

- Sets `performing_player.extra_width = 1`
- Creates a log message indicating the transformation
- Triggers "BecomeWide" event with character details
- Often used for mech transformations or size changes
- May affect visual representation and game board presence
- Transformation is typically permanent for the duration of the effect
- Can include description parameter for flavor text

## Related Effects

- [transform_attack](transform_attack.md) - Transform attack properties
- [attack_is_ex](attack_is_ex.md) - Make attack EX
- [powerup](../stats/powerup.md) - Increase power
- [speedup](../stats/speedup.md) - Increase speed

## Real Usage Examples

From card definitions:
- Tinker's transformation cards: `{ "effect_type": "become_wide", "description": "Tinker Tank" }`
- Mech suit activations: Size and form changes
- Vehicle transformations: Robot to vehicle mode changes
- Character stance changes: Wide defensive or offensive forms