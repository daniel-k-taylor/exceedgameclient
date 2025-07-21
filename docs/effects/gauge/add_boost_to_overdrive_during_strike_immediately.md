# add_boost_to_overdrive_during_strike_immediately

**Category**: Gauge and Force
**Description**: Immediately moves a specific boost card from continuous boosts to the overdrive zone during strike resolution.

## Parameters

- `card_name` (required): The specific boost card to move to overdrive
  - **Type**: String
  - **Range**: Any valid card name that exists in continuous boosts
  - **Special Values**: Must match exact card name from card definitions

## Supported Timings

- `during_strike` - During strike resolution
- `after` - After strike resolution
- `immediate` - Immediately when triggered

## Examples

**Move specific boost to overdrive:**
```json
{
  "timing": "during_strike",
  "effect_type": "add_boost_to_overdrive_during_strike_immediately",
  "card_name": "Disjoint Union"
}
```

**After strike timing:**
```json
{
  "timing": "after",
  "effect_type": "add_boost_to_overdrive_during_strike_immediately",
  "card_name": "f piecewise"
}
```

**Combined with other effects:**
```json
{
  "timing": "during_strike",
  "and": {
    "effect_type": "add_boost_to_overdrive_during_strike_immediately",
    "card_name": "Disjoint Union"
  }
}
```

## Implementation Notes

- Requires an exact card name match to identify which boost card to move
- The card must currently be in the player's continuous boosts area
- Immediately removes the card from continuous boosts and places it in overdrive
- Creates appropriate log messages showing which card was moved
- If the specified card is not found in continuous boosts, the effect fails silently
- The overdrive zone provides strategic benefits for cards placed there
- This happens immediately during the strike, not during cleanup phase

## Related Effects

- [`add_strike_to_overdrive_after_cleanup`](add_strike_to_overdrive_after_cleanup.md) - Moves strike cards to overdrive after cleanup
- [`add_top_discard_to_overdrive`](add_top_discard_to_overdrive.md) - Moves discard cards to overdrive
- [`add_to_gauge_boost_play_cleanup`](add_to_gauge_boost_play_cleanup.md) - Moves boost cards to gauge instead
- [`remove_from_continuous_boosts`](../cards/remove_from_continuous_boosts.md) - Generic boost removal

## Real Usage Examples

From card definitions:
- Kokonoe's "Disjoint Union": `{ "effect_type": "add_boost_to_overdrive_during_strike_immediately", "card_name": "Disjoint Union" }` - Strategic boost repositioning
- Mathematical function cards: Moving specific function boosts to overdrive for combo setup
- Advanced combo systems: Precise control over which boosts remain active vs. go to overdrive