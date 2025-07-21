# boost_from_gauge

**Category**: Boost
**Description**: Allow player to boost a card from their gauge.

## Parameters

- `limitation` (optional): Restrictions on what can be boosted
  - **Type**: String
  - **Values**: "normal", "special", "continuous", etc.
  - **Default**: No limitation (any card type can be boosted)

## Supported Timings

- `now` - Immediately when played (expected as character action)

## Examples

**Basic boost from gauge:**
```json
{
  "timing": "now",
  "effect_type": "boost_from_gauge"
}
```

**Boost normal cards only from gauge:**
```json
{
  "timing": "now",
  "effect_type": "boost_from_gauge",
  "limitation": "normal"
}
```

**Boost continuous cards from gauge:**
```json
{
  "timing": "now",
  "effect_type": "boost_from_gauge",
  "limitation": "continuous"
}
```

## Implementation Notes

- Expected to be used as a character action
- Creates a decision state for player to select card from gauge
- Checks if player [`can_boost_something(['gauge'], limitation)`](../../scenes/core/local_game.gd:2014) before allowing boost
- If no valid cards available, logs message that player has no valid cards in gauge to boost with
- Creates [`EventType_ForceStartBoost`](../../scenes/core/local_game.gd:2015) event
- Sets decision type to [`DecisionType_BoostNow`](../../scenes/core/local_game.gd:2018) with gauge zone restriction
- Requires gauge cards to be available for boosting

## Related Effects

- [boost_from_extra](boost_from_extra.md) - Boost from extra deck instead of gauge
- [boost_additional](boost_additional.md) - Boost additional cards beyond normal limits
- [enable_boost_from_gauge](enable_boost_from_gauge.md) - Enable gauge boosting capability
- [gauge_for_effect](../gauge/gauge_for_effect.md) - Add cards to gauge for later boosting

## Real Usage Examples

From card definitions:
- Character-specific actions that utilize gauge resources
- Abilities that convert gauge cards into active boosts
- Resource management effects that provide boost alternatives
- Strategic effects that access previously stored gauge cards