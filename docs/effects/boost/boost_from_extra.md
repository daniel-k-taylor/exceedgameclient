# boost_from_extra

**Category**: Boost
**Description**: Allow player to boost a card from their extra deck.

## Parameters

- `limitation` (optional): Restrictions on what can be boosted
  - **Type**: String
  - **Values**: "normal", "special", "continuous", etc.
  - **Default**: No limitation (any card type can be boosted)

## Supported Timings

- `now` - Immediately when played (expected as character action)

## Examples

**Basic boost from extra:**
```json
{
  "timing": "now",
  "effect_type": "boost_from_extra"
}
```

**Boost normal cards only from extra:**
```json
{
  "timing": "now",
  "effect_type": "boost_from_extra",
  "limitation": "normal"
}
```

**Boost special cards from extra:**
```json
{
  "timing": "now",
  "effect_type": "boost_from_extra",
  "limitation": "special"
}
```

## Implementation Notes

- Expected to be used as a character action
- Creates a decision state for player to select card from extra deck
- Checks if player [`can_boost_something(['extra'], limitation)`](../../scenes/core/local_game.gd:2002) before allowing boost
- If no valid cards available, logs message that player has no valid extra cards to boost with
- Creates [`EventType_ForceStartBoost`](../../scenes/core/local_game.gd:2003) event
- Sets decision type to [`DecisionType_BoostNow`](../../scenes/core/local_game.gd:2006) with extra zone restriction

## Related Effects

- [boost_from_gauge](boost_from_gauge.md) - Boost from gauge instead of extra
- [boost_additional](boost_additional.md) - Boost additional cards beyond normal limits
- [boost_multiple](boost_multiple.md) - Boost multiple cards at once
- [enable_boost_from_gauge](enable_boost_from_gauge.md) - Enable gauge boosting capability

## Real Usage Examples

From card definitions:
- Character-specific actions that access extra deck resources
- Special abilities that allow accessing powerful extra deck cards
- Strategic effects that provide access to unique boost options
- Exceed abilities that unlock extra deck boosting capabilities