# spend_all_force_and_save_amount

**Category**: Force
**Description**: Spend all available force and save the amount for use by other effects.

## Parameters

None - this effect automatically spends all available force.

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `immediate` - Immediately when triggered

## Examples

**Basic usage:**
```json
{
  "timing": "before",
  "effect_type": "spend_all_force_and_save_amount"
}
```

**Combined with force-based effects:**
```json
{
  "timing": "before",
  "effect_type": "spend_all_force_and_save_amount",
  "and": {
    "effect_type": "powerup_per_force_spent_this_turn",
    "amount": 1
  }
}
```

## Implementation Notes

- Spends all force currently available to the player
- Saves the amount in `force_spent_before_strike` for other effects to reference
- Force is deducted from current turn's available force
- Other effects can use the saved amount for scaling bonuses
- Creates log message showing amount of force spent
- Does nothing if no force is available
- The saved amount persists until end of turn

## Related Effects

- [spend_all_gauge_and_save_amount](spend_all_gauge_and_save_amount.md) - Gauge version
- [force_for_effect](force_for_effect.md) - Spend specific amount of force
- [powerup_per_force_spent_this_turn](../stats/powerup_per_force_spent_this_turn.md) - Uses saved amount
- [increase_force_spent_before_strike](increase_force_spent_before_strike.md) - Modify saved amount

## Real Usage Examples

From card definitions:
- Ultimate attacks that convert all force into massive effects
- All-in strategies that spend entire force for maximum benefit
- Combo setup that prepares force-based scaling effects