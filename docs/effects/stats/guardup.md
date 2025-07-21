# guardup

**Category**: Stats
**Description**: Increase guard by specified amount for this strike. Guard reduces incoming damage by blocking.

## Parameters

- `amount` (required): Amount of guard to add
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic guard increase:**
```json
{
  "timing": "during_strike",
  "effect_type": "guardup",
  "amount": 1
}
```

**Heavy guard boost:**
```json
{
  "timing": "during_strike",
  "effect_type": "guardup",
  "amount": 3
}
```

**Conditional guard:**
```json
{
  "timing": "during_strike",
  "condition": "opponent_has_advantage",
  "effect_type": "guardup",
  "amount": 2
}
```

## Implementation Notes

- Guard bonus is applied to `strike_stat_boosts.guard`
- Stacks with other guard effects
- Guard reduces incoming damage after armor calculations
- Each point of guard blocks 1 point of damage
- Guard can be bypassed by `ignore_guard` effects
- Typically found on defensive attacks and blocks

## Related Effects

- [guardup_per_force_spent_this_turn](guardup_per_force_spent_this_turn.md) - Guard based on force spent
- [guardup_per_gauge](guardup_per_gauge.md) - Guard based on gauge size
- [guardup_per_two_cards_in_hand](guardup_per_two_cards_in_hand.md) - Guard based on hand size
- [ignore_guard](../attack/ignore_guard.md) - Bypass guard protection

## Real Usage Examples

From card definitions:
- Bang's "Steel Wheel": `{ "timing": "during_strike", "effect_type": "guardup", "amount": 2 }`
- Baiken defensive techniques: Guard for counterattacks
- Tager's defensive moves: Guard for trading hits
- Various parry and defensive stance abilities