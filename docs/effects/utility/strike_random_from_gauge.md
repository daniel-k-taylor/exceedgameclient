# StrikeRandomFromGauge

**Category**: Utility (also classified under Special Mechanics)
**Description**: Performs a strike using a randomly selected card from the player's gauge.

## Parameters

This effect takes no parameters.

## Supported Timings

- `now` - Immediately when the effect is triggered

## Examples

**Basic random gauge strike:**
```json
{
  "timing": "now",
  "effect_type": "strike_random_from_gauge"
}
```

**In deck effect:**
```json
{
  "effect": {
    "effect_type": "strike_random_from_gauge"
  }
}
```

**With conditional bonuses:**
```json
{
  "timing": "during_strike",
  "condition": "was_strike_from_gauge",
  "effect_type": "stun_immunity"
}
```

## Implementation Notes

- Creates an `EventType_Strike_OpponentSetsFirst` event (opponent sets first for information balance)
- Sets `next_strike_random_gauge` flag to true for the performing player
- Automatically selects a random card from the player's gauge to use as a strike
- Provides unpredictability while accessing potentially powerful gauged cards
- Opponent gets to set their strike first to balance the random element
- Used for high-risk, high-reward strategies with gauge-based decks
- Cards used this way are removed from gauge according to normal strike rules

## Related Effects

- [`strike_from_gauge`](strike_from_gauge.md) - Choice-based version of gauge striking
- [`strike_opponent_sets_first`](strike_opponent_sets_first.md) - Strike timing modification
- [`gauge_for_effect`](../gauge/gauge_for_effect.md) - Moves cards to gauge for later use

## Real Usage Examples

From card definitions:
- Yuzu character cards: `"effect_type": "strike_random_from_gauge"`
- Random mechanics: Provides unpredictable but potentially powerful strikes
- Gauge-based strategies: `"condition": "was_strike_from_gauge"` triggers special effects
- Risk/reward gameplay: Trades control for potential access to powerful gauged cards