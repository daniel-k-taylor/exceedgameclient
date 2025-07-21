# name_range

**Category**: Choice and Selection
**Description**: Player names a range value, and opponent must discard cards matching that range or reveal their hand.

## Parameters

- `target_effect` (required): The effect to execute after range is named
  - **Type**: String
  - **Values**: "opponent_discard_range_or_reveal"
  - **Note**: Determines what happens with the named range
- `amount` (optional): Number of cards opponent must discard if they have the named range
  - **Type**: Integer
  - **Default**: 1

## Supported Timings

- `immediate` - Immediately when triggered
- `before` - Before strike resolution
- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Basic range naming:**
```json
{
  "timing": "immediate",
  "effect_type": "name_range",
  "target_effect": "opponent_discard_range_or_reveal"
}
```

**Multiple card discard:**
```json
{
  "timing": "hit",
  "effect_type": "name_range",
  "target_effect": "opponent_discard_range_or_reveal",
  "amount": 2
}
```

**Before strike range naming:**
```json
{
  "timing": "before",
  "effect_type": "name_range",
  "target_effect": "opponent_discard_range_or_reveal"
}
```

## Implementation Notes

- Creates a decision state where player selects a range value (typically 1-9)
- After range is named, executes the target_effect with the selected range
- Most commonly used with "opponent_discard_range_or_reveal" target effect
- If opponent has cards matching the named range, they must discard the specified amount
- If opponent has no cards matching the named range, they reveal their hand instead
- Range values correspond to the range stat printed on cards
- Player must choose from valid range values in the game (usually 1-9)
- Creates strategic mind games as players try to guess opponent's hand composition

## Related Effects

- [opponent_discard_range_or_reveal](../cards/opponent_discard_range_or_reveal.md) - Target effect for range naming
- [name_speed](name_speed.md) - Similar effect for speed values
- [name_card_opponent_discards](name_card_opponent_discards.md) - Name specific cards instead
- [reveal_hand](../cards/reveal_hand.md) - Hand revelation when guess is wrong

## Real Usage Examples

From card definitions:
- Strategic disruption cards: Force opponent to discard specific range cards
- Information gathering effects: Learn about opponent's hand composition
- Meta-game strategies: Target common range values in the format
- Combo disruption: Name ranges that interfere with opponent's strategy
- Mind games: Psychological pressure through range prediction