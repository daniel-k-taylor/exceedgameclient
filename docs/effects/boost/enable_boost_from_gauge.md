# enable_boost_from_gauge

**Category**: Boost
**Description**: Enable the player to boost cards from their gauge zone.

## Parameters

No parameters required.

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `during_strike` - During strike resolution
- `after` - After strike resolution

## Examples

**Basic enable gauge boosting:**
```json
{
  "timing": "now",
  "effect_type": "enable_boost_from_gauge"
}
```

**Enable during strike:**
```json
{
  "timing": "during_strike",
  "effect_type": "enable_boost_from_gauge"
}
```

## Implementation Notes

- Sets [`performing_player.can_boost_from_gauge = true`](../../scenes/core/local_game.gd:2866)
- This is a simple flag that enables gauge boosting capability
- Once enabled, player can use gauge zone as a valid source for boosting
- Persistent effect that lasts for the duration of the game
- Enables strategic gauge management and resource allocation
- Often found on character-specific cards or exceed abilities

## Related Effects

- [boost_from_gauge](boost_from_gauge.md) - Actually boost from gauge (requires this to be enabled)
- [gauge_for_effect](../gauge/gauge_for_effect.md) - Add cards to gauge
- [boost_additional](boost_additional.md) - Boost additional cards with gauge access
- [boost_multiple](boost_multiple.md) - Boost multiple cards including from gauge

## Real Usage Examples

From card definitions:
- Character exceed abilities that unlock gauge boosting
- Special cards that provide advanced resource access
- Strategic effects that enable new boost options
- Cards that expand player capabilities permanently