# name_speed

**Category**: Choice and Selection
**Description**: Player names a speed value, and opponent must discard cards matching that speed or reveal their hand.

## Parameters

- `target_effect` (required): The effect to execute after speed is named
  - **Type**: String
  - **Values**: "opponent_discard_speed_or_reveal"
  - **Note**: Determines what happens with the named speed
- `amount` (optional): Number of cards opponent must discard if they have the named speed
  - **Type**: Integer
  - **Default**: 1

## Supported Timings

- `immediate` - Immediately when triggered
- `before` - Before strike resolution
- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Basic speed naming:**
```json
{
  "timing": "immediate",
  "effect_type": "name_speed",
  "target_effect": "opponent_discard_speed_or_reveal"
}
```

**Multiple card discard:**
```json
{
  "timing": "hit",
  "effect_type": "name_speed",
  "target_effect": "opponent_discard_speed_or_reveal",
  "amount": 2
}
```

**Before strike speed naming:**
```json
{
  "timing": "before",
  "effect_type": "name_speed",
  "target_effect": "opponent_discard_speed_or_reveal"
}
```

## Implementation Notes

- Creates a decision state where player selects a speed value (typically 1-9)
- After speed is named, executes the target_effect with the selected speed
- Most commonly used with "opponent_discard_speed_or_reveal" target effect
- If opponent has cards matching the named speed, they must discard the specified amount
- If opponent has no cards matching the named speed, they reveal their hand instead
- Speed values correspond to the speed stat printed on cards
- Player must choose from valid speed values in the game (usually 1-9)
- Creates strategic mind games as players try to guess opponent's hand composition
- Particularly effective against characters with predictable speed ranges

## Related Effects

- [opponent_discard_speed_or_reveal](../cards/opponent_discard_speed_or_reveal.md) - Target effect for speed naming
- [name_range](name_range.md) - Similar effect for range values
- [name_card_opponent_discards](name_card_opponent_discards.md) - Name specific cards instead
- [reveal_hand](../cards/reveal_hand.md) - Hand revelation when guess is wrong

## Real Usage Examples

From card definitions:
- Strategic disruption cards: Force opponent to discard specific speed cards
- Information gathering effects: Learn about opponent's hand composition
- Meta-game strategies: Target common speed values in the format
- Combo disruption: Name speeds that interfere with opponent's strategy
- Mind games: Psychological pressure through speed prediction
- Character counter-play: Target speeds common to specific characters