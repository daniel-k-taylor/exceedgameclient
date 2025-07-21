# spend_all_gauge_and_save_amount

**Category**: Gauge
**Description**: Spend all available gauge and save the amount for use by other effects.

## Parameters

None - this effect automatically spends all available gauge.

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `immediate` - Immediately when triggered

## Examples

**Basic usage:**
```json
{
  "timing": "before",
  "effect_type": "spend_all_gauge_and_save_amount"
}
```

**Combined with gauge-based effects:**
```json
{
  "timing": "before",
  "effect_type": "spend_all_gauge_and_save_amount",
  "and": {
    "effect_type": "powerup_per_gauge_spent_before_strike",
    "amount": 1
  }
}
```

## Implementation Notes

- Spends all gauge cards currently available to the player
- Saves the amount in `gauge_spent_before_strike` for other effects to reference
- Gauge cards are moved to discard pile when spent
- Other effects can use the saved amount for scaling bonuses
- Creates log message showing amount of gauge spent
- Does nothing if no gauge is available
- The saved amount persists until end of turn

## Related Effects

- [spend_all_force_and_save_amount](spend_all_force_and_save_amount.md) - Force version
- [gauge_for_effect](gauge_for_effect.md) - Spend specific amount of gauge
- [powerup_per_gauge_spent_before_strike](../stats/powerup_per_gauge_spent_before_strike.md) - Uses saved amount
- [increase_gauge_spent_before_strike](increase_gauge_spent_before_strike.md) - Modify saved amount

## Real Usage Examples

From card definitions:
- Ultimate attacks that convert all gauge into massive effects
- All-in strategies that spend entire gauge for maximum benefit
- Combo setup that prepares gauge-based scaling effects