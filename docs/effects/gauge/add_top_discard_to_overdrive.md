# add_top_discard_to_overdrive

**Category**: Gauge and Force
**Description**: Moves the top card(s) from the player's discard pile to their overdrive zone.

## Parameters

- `amount` (optional): Number of cards to move from discard to overdrive
  - **Type**: Integer
  - **Range**: Any positive integer
  - **Default**: 1

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `after` - After strike resolution
- `now` - Immediately when played
- `immediate` - Immediately when triggered

## Examples

**Basic usage (single card):**
```json
{
  "timing": "after",
  "effect_type": "add_top_discard_to_overdrive"
}
```

**Move multiple cards:**
```json
{
  "timing": "before",
  "effect_type": "add_top_discard_to_overdrive",
  "amount": 2
}
```

**Conditional usage:**
```json
{
  "timing": "after",
  "condition": "opponent_stunned",
  "effect_type": "add_top_discard_to_overdrive"
}
```

## Implementation Notes

- Only moves cards that actually exist in the discard pile - if there are fewer cards than requested, only the available cards are moved
- Cards are moved from the top of the discard pile (most recently discarded)
- Creates appropriate log messages showing which cards were moved
- If the discard pile is empty, displays a message indicating no cards were available
- The overdrive zone is a special area that provides benefits when cards are placed there

## Related Effects

- [`add_top_discard_to_gauge`](add_top_discard_to_gauge.md) - Moves discard cards to gauge instead of overdrive
- [`add_strike_to_overdrive_after_cleanup`](add_strike_to_overdrive_after_cleanup.md) - Moves strike cards to overdrive
- [`add_boost_to_overdrive_during_strike_immediately`](add_boost_to_overdrive_during_strike_immediately.md) - Moves boost cards to overdrive
- [`add_bottom_discard_to_gauge`](add_bottom_discard_to_gauge.md) - Similar effect for gauge zone using bottom cards

## Real Usage Examples

From card definitions:
- Arakune's choice effects: `{ "effect_type": "add_top_discard_to_overdrive" }` - Optional overdrive building
- Kokonoe's conditional effects: Used when opponent is stunned to gain overdrive advantage
- Various mathematical characters: Building overdrive for combo potential and resource management