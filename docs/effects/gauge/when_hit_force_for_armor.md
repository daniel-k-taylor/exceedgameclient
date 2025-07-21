# when_hit_force_for_armor

**Category**: Gauge and Force
**Description**: Sets up a conditional effect that allows the player to spend force (or gauge) for armor when they are hit during the strike.

## Parameters

- `amount` (required): Maximum amount of force/gauge that can be spent for armor
  - **Type**: Integer
  - **Range**: Any positive integer
- `use_gauge_instead` (optional): If true, allows spending gauge instead of force
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `during_strike` - During strike resolution
- `before` - Before strike resolution
- `immediate` - Immediately when triggered

## Examples

**Basic force-for-armor setup:**
```json
{
  "timing": "during_strike",
  "effect_type": "when_hit_force_for_armor",
  "amount": 2
}
```

**Gauge-based armor:**
```json
{
  "timing": "during_strike",
  "effect_type": "when_hit_force_for_armor",
  "use_gauge_instead": true,
  "amount": 3
}
```

**Defensive preparation:**
```json
{
  "timing": "before",
  "effect_type": "when_hit_force_for_armor",
  "amount": 2
}
```

## Implementation Notes

- Sets the `when_hit_force_for_armor` flag in the player's strike stat boosts
- By default, sets the flag to "force" to indicate force spending
- If `use_gauge_instead` is true, sets the flag to "gauge" for gauge spending
- Force version takes priority - if already set to "force", gauge version is ignored
- The actual force/gauge spending decision occurs when the player is hit, not when this effect is applied
- Each point of force/gauge typically reduces incoming damage by 1 point
- The effect persists for the duration of the current strike
- Multiple applications with the same resource type do not stack - the highest amount applies

## Related Effects

- [`immediate_force_for_armor`](immediate_force_for_armor.md) - Triggers force-for-armor decision immediately
- [`force_for_effect`](force_for_effect.md) - Generates force for other purposes
- [`gauge_for_effect`](gauge_for_effect.md) - Generates gauge for other purposes
- [`armorup`](../stats/armorup.md) - Direct armor increase effect

## Real Usage Examples

From card definitions:
- Block and defensive cards: `{ "effect_type": "when_hit_force_for_armor", "amount": 2 }` - Standard defensive option
- Gauge-based defense: `{ "effect_type": "when_hit_force_for_armor", "use_gauge_instead": true, "amount": 3 }` - Alternative resource for armor
- Multiple defensive characters: Consistent defensive mechanics across different playstyles
- Resource conversion cards: Strategic choice between offensive resource usage and defensive spending