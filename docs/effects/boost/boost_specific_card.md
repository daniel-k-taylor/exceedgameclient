# boost_specific_card

**Category**: Boost
**Description**: Boost a specific named card from hand if available.

## Parameters

- `boost_name` (required): The display name of the boost card to find and boost
  - **Type**: String
  - **Values**: Any valid boost card display name
  - **Example**: "Hadoken", "Dragon Punch", etc.

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered

## Examples

**Boost specific named card:**
```json
{
  "timing": "now",
  "effect_type": "boost_specific_card",
  "boost_name": "Hadoken"
}
```

**Immediate boost of specific card:**
```json
{
  "timing": "immediate",
  "effect_type": "boost_specific_card",
  "boost_name": "Dragon Punch"
}
```

## Implementation Notes

- Searches through player's hand for card with matching [`boost.display_name`](../../scenes/core/local_game.gd:2087)
- If found, automatically boosts that card without player choice
- Creates decision state for boost mechanics but doesn't require player input
- Uses [`EventType_EffectDoBoost`](../../scenes/core/local_game.gd:2099) with specific card ID
- Sets decision type to [`DecisionType_BoostNow`](../../scenes/core/local_game.gd:2094) for proper boost handling
- No effect if specified card is not in hand
- Enables precise combo execution and card synergies
- Bypasses normal boost selection process

## Related Effects

- [boost_additional](boost_additional.md) - Boost additional cards beyond normal limits
- [boost_from_gauge](boost_from_gauge.md) - Boost from gauge instead of hand
- [boost_multiple](boost_multiple.md) - Boost multiple cards at once
- [boost_then_sustain](boost_then_sustain.md) - Sustain boost effects

## Real Usage Examples

From card definitions:
- Character-specific combos that require exact card sequences
- Effects that enable specific boost synergies
- Cards that search for and activate particular strategies
- Combo enablers that guarantee specific boost availability