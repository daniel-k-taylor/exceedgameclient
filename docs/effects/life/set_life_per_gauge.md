# SetLifePerGauge

**Category**: Life and Damage
**Description**: Sets the character's life to a value calculated by multiplying gauge count by a specified amount.

## Parameters

- `amount` (required): Life amount per gauge card
  - **Type**: Integer
  - **Range**: Any positive integer

- `maximum` (optional): Maximum life that can be set
  - **Type**: Integer
  - **Range**: Any positive integer
  - **Default**: Enums.MaxLife (maximum possible life)

## Supported Timings

- `on_exceed` - When character enters exceed state
- `immediate` - Immediately when triggered
- `effect_type` - As a standalone effect

## Examples

**Basic life setting per gauge:**
```json
{
  "effect_type": "set_life_per_gauge",
  "amount": 4
}
```

**Life setting with maximum cap:**
```json
{
  "effect_type": "set_life_per_gauge",
  "amount": 3,
  "maximum": 15
}
```

**Exceed transformation:**
```json
{
  "on_exceed": {
    "effect_type": "set_life_per_gauge",
    "amount": 4,
    "maximum": 20
  }
}
```

## Implementation Notes

- Calculates final life as: gauge_count * amount_per_gauge
- Applies maximum cap if specified, otherwise uses Enums.MaxLife
- Sets life directly, does not add to current life
- Creates EventType_Strike_GainLife event for UI consistency
- Generates log message about life being set to new value
- Commonly used for character transformations or special states
- Gauge count is taken at time of effect execution

## Related Effects

- [gain_life](gain_life.md) - Adds to current life instead of setting
- [gauge_for_effect](../gauge/gauge_for_effect.md) - Uses gauge as a resource
- [effect_per_card_in_zone](effect_per_card_in_zone.md) - General zone-based scaling

## Real Usage Examples

From card definitions:
- Tinker's exceed: `{ "on_exceed": { "effect_type": "set_life_per_gauge", "amount": 4, "maximum": 20 } }`
- Character transformations: Life scaling based on resource investment
- Exceed mechanics: New life totals when entering powered-up states
- Risk/reward builds: Higher gauge investment for more life
- Strategic resource management: Players balancing gauge usage vs life scaling
- Special character abilities: Unique life calculation methods