# may_generate_gauge_with_force

**Category**: Gauge and Force
**Description**: Sets a flag allowing the player to generate gauge cards using force instead of the normal gauge generation method.

## Parameters

This effect takes no parameters.

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `now` - Immediately when played
- `immediate` - Immediately when triggered

## Examples

**Basic usage:**
```json
{
  "timing": "before",
  "effect_type": "may_generate_gauge_with_force"
}
```

**Combined with other effects:**
```json
{
  "timing": "before",
  "effect_type": "may_generate_gauge_with_force",
  "and": {
    "effect_type": "powerup",
    "amount": 1
  }
}
```

**Chained usage:**
```json
{
  "timing": "before",
  "effect_type": "may_generate_gauge_with_force",
  "and": {
    "effect_type": "may_generate_gauge_with_force"
  }
}
```

## Implementation Notes

- Sets the `may_generate_gauge_with_force` flag in the player's strike stat boosts
- This flag modifies the gauge generation system to allow using force as an alternative resource
- The effect persists for the duration of the current strike
- Does not automatically generate gauge - it only enables the option to use force for gauge generation
- The actual gauge generation still requires separate effects or player decisions
- Multiple applications of this effect do not stack - it's a boolean flag
- The force-to-gauge conversion rate and mechanics depend on other game systems

## Related Effects

- [`gauge_for_effect`](gauge_for_effect.md) - Generates gauge for specific effects
- [`force_for_effect`](force_for_effect.md) - Generates force for specific effects
- [`generate_free_force`](generate_free_force.md) - Generates force without cost
- [`add_hand_to_gauge`](add_hand_to_gauge.md) - Alternative gauge generation method

## Real Usage Examples

From card definitions:
- Kokonoe's mathematical effects: `{ "effect_type": "may_generate_gauge_with_force" }` - Resource flexibility for complex combos
- Advanced resource management cards: Providing alternative resource conversion options
- Strategic flexibility: Allowing players to choose between force and normal gauge generation based on current needs