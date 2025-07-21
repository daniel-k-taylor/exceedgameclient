# generate_free_force

**Category**: Force
**Description**: Generate free force for this turn. Adds force that can be spent without paying normal costs.

## Parameters

- `amount` (required): Amount of free force to generate
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `set_strike` - When setting a strike
- `now` - Immediately when played

## Examples

**Basic free force:**
```json
{
  "timing": "set_strike",
  "effect_type": "generate_free_force",
  "amount": 1
}
```

**Multiple free force:**
```json
{
  "timing": "now",
  "effect_type": "generate_free_force",
  "amount": 2
}
```

## Implementation Notes

- Adds to available force for current turn
- Force can be spent on any valid force costs
- Often used for resource acceleration
- Stacks with other force generation
- May be limited to specific card types in some contexts

## Related Effects

- [force_for_effect](force_for_effect.md) - Spend force for effects
- [remove_generate_free_force](remove_generate_free_force.md) - Remove force generation
- [generate_free_force_cc_only](generate_free_force_cc_only.md) - Force for character cards only

## Real Usage Examples

From card definitions:
- Various character actions that provide resource acceleration
- Setup cards that enable expensive plays
- Momentum-building mechanics across multiple characters