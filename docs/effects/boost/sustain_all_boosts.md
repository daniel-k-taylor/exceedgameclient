# sustain_all_boosts

**Category**: Boost
**Description**: Sustain all continuous boosts currently in play.

## Parameters

No parameters required.

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `after` - After strike resolution
- `cleanup` - During cleanup phase

## Examples

**Basic sustain all boosts:**
```json
{
  "timing": "after",
  "effect_type": "sustain_all_boosts"
}
```

**Immediate sustain all:**
```json
{
  "timing": "immediate",
  "effect_type": "sustain_all_boosts"
}
```

## Implementation Notes

- Iterates through all [`performing_player.continuous_boosts`](../../scenes/core/local_game.gd:5676)
- Adds each boost ID to [`performing_player.sustained_boosts`](../../scenes/core/local_game.gd:5678) if not already sustained
- Creates log message indicating all continuous boosts are sustained
- Creates [`EventType_SustainBoost`](../../scenes/core/local_game.gd:5680) event with card ID -1 (all boosts)
- Powerful effect that preserves all active boost investments
- Often found on high-value cards or climactic effects
- Enables long-term boost accumulation strategies

## Related Effects

- [sustain_this](sustain_this.md) - Sustain only the current card
- [boost_then_sustain](boost_then_sustain.md) - Boost and sustain new cards
- [boost_this_then_sustain](boost_this_then_sustain.md) - Boost current card with sustain
- [negate_boost](negate_boost.md) - Opposite effect that removes boosts

## Real Usage Examples

From card definitions:
- Sol Badguy's ultimate effects: After strike sustain all boosts
- High-cost finisher cards that preserve all board state
- Strategic cards that reward boost accumulation
- End-game effects that maintain momentum for future turns