# add_strike_to_overdrive_after_cleanup

**Category**: Gauge and Force
**Description**: Sets a flag that causes the player's strike card to be moved to overdrive after the strike resolves and cleanup occurs.

## Parameters

This effect takes no parameters.

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `now` - Immediately when played
- `immediate` - Immediately when triggered

## Examples

**Basic usage:**
```json
{
  "timing": "before",
  "effect_type": "add_strike_to_overdrive_after_cleanup"
}
```

**Choice-based usage:**
```json
{
  "timing": "before",
  "choice": [
    { "effect_type": "add_strike_to_overdrive_after_cleanup" },
    { "effect_type": "pass" }
  ]
}
```

**Combined with other effects:**
```json
{
  "timing": "before",
  "effect_type": "add_strike_to_overdrive_after_cleanup",
  "and": {
    "effect_type": "powerup",
    "amount": 1
  }
}
```

## Implementation Notes

- Sets the `always_add_to_overdrive` flag in the player's strike stat boosts
- The actual movement of the strike card happens during cleanup phase, not immediately
- Also triggers `handle_strike_attack_immediate_removal` to prepare for the removal
- Works with any strike card, regardless of its normal cleanup destination
- The overdrive zone provides strategic benefits for cards placed there
- Cannot be undone once the flag is set for the current strike

## Related Effects

- [`add_strike_to_gauge_after_cleanup`](add_strike_to_gauge_after_cleanup.md) - Moves strike to gauge instead of overdrive
- [`add_top_discard_to_overdrive`](add_top_discard_to_overdrive.md) - Moves discard cards to overdrive
- [`add_boost_to_overdrive_during_strike_immediately`](add_boost_to_overdrive_during_strike_immediately.md) - Moves boost cards to overdrive immediately
- [`add_opponent_strike_to_gauge`](add_opponent_strike_to_gauge.md) - Moves opponent's strike to your gauge

## Real Usage Examples

From card definitions:
- Kokonoe's mathematical effects: `{ "effect_type": "add_strike_to_overdrive_after_cleanup" }` - Choice-based overdrive building
- Various combo-oriented characters: Building overdrive for extended sequences and resource management
- Strategic cards: Preserving powerful strikes in overdrive for later use rather than losing them to discard