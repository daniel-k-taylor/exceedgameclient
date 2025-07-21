# generate_free_force_cc_only

**Category**: Force
**Description**: Generate free force that can only be used for change cards operations.

## Parameters

- `amount` (required): Amount of free force to generate
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `immediate` - Immediately when triggered
- `now` - Immediately when played
- `before` - Before strike resolution

## Examples

**Basic usage:**
```json
{
  "timing": "immediate",
  "effect_type": "generate_free_force_cc_only",
  "amount": 2
}
```

**Large amount:**
```json
{
  "timing": "now",
  "effect_type": "generate_free_force_cc_only",
  "amount": 5
}
```

## Implementation Notes

- Sets `free_force_cc_only` on the player to the specified amount
- This force can ONLY be used for change cards (cc) operations
- Cannot be used for movement, attacks, or other force costs
- Restricts force usage to card management only
- Creates log message about free force generation
- Different from regular free force which has no restrictions

## Related Effects

- [generate_free_force](generate_free_force.md) - Unrestricted free force
- [remove_generate_free_force](remove_generate_free_force.md) - Remove free force
- [force_for_effect](force_for_effect.md) - Spend force for effects

## Real Usage Examples

From card definitions:
- Character abilities that provide card management force
- Effects that enable deck cycling without movement cost
- Strategic card filtering with dedicated force