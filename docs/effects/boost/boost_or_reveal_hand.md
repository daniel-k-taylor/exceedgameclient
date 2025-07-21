# boost_or_reveal_hand

**Category**: Boost
**Description**: Allow player to boost a card from hand, or reveal hand if no valid boost options.

## Parameters

- `limitation` (optional): Restrictions on what can be boosted
  - **Type**: String
  - **Values**: "normal", "special", "continuous", etc.
  - **Default**: No limitation
- `strike_instead_of_reveal` (optional): Force strike instead of revealing hand
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `now` - Immediately when played (expected as character action)

## Examples

**Basic boost or reveal:**
```json
{
  "timing": "now",
  "effect_type": "boost_or_reveal_hand"
}
```

**Boost normal cards or reveal:**
```json
{
  "timing": "now",
  "effect_type": "boost_or_reveal_hand",
  "limitation": "normal"
}
```

**Boost or strike instead of reveal:**
```json
{
  "timing": "now",
  "effect_type": "boost_or_reveal_hand",
  "strike_instead_of_reveal": true
}
```

## Implementation Notes

- Expected to be used as a character action
- First checks if player [`can_boost_something(['hand'], limitation)`](../../scenes/core/local_game.gd:2056)
- If boost is possible, creates normal boost decision state
- If no valid boost cards, either reveals hand or forces strike
- When [`strike_instead_of_reveal`](../../scenes/core/local_game.gd:2065) is true, forces strike instead of revealing
- Calls [`performing_player.reveal_hand()`](../../scenes/core/local_game.gd:2082) if no boost and no strike option
- Creates flexible choice effects that adapt to hand state
- Provides strategic value even when boosting isn't available

## Related Effects

- [boost_additional](boost_additional.md) - Boost additional cards beyond normal limits
- [boost_from_gauge](boost_from_gauge.md) - Boost from gauge instead of hand
- [reveal_hand](../cards/reveal_hand.md) - Directly reveal hand
- [boost_then_strike](boost_then_strike.md) - Force strike after boosting

## Real Usage Examples

From card definitions:
- Character actions that provide flexible options based on hand state
- Cards that ensure value even with poor hand composition
- Strategic effects that reveal information when boosting isn't viable
- Adaptive abilities that respond to current game state