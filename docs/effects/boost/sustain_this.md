# sustain_this

**Category**: Boost
**Description**: Sustain the current card as a continuous boost.

## Parameters

- `hide_effect` (optional): Hide the sustain effect from logs
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `during_strike` - During strike resolution
- `after` - After strike resolution
- `cleanup` - During cleanup phase

## Examples

**Basic sustain this card:**
```json
{
  "timing": "after",
  "effect_type": "sustain_this"
}
```

**Hidden sustain effect:**
```json
{
  "timing": "immediate",
  "effect_type": "sustain_this",
  "hide_effect": true
}
```

## Implementation Notes

- Adds the current [`card_id`](../../scenes/core/local_game.gd:5682) to [`performing_player.sustained_boosts`](../../scenes/core/local_game.gd:5682)
- If [`hide_effect`](../../scenes/core/local_game.gd:5683) is false, creates log message with boost name
- Creates [`EventType_SustainBoost`](../../scenes/core/local_game.gd:5687) event with specific card ID
- Allows individual cards to become persistent continuous effects
- Can be used to hide sustain effects from logs for cleaner presentation
- Enables strategic investment in long-term card effects
- More targeted than [`sustain_all_boosts`](sustain_all_boosts.md)

## Related Effects

- [sustain_all_boosts](sustain_all_boosts.md) - Sustain all continuous boosts
- [boost_this_then_sustain](boost_this_then_sustain.md) - Boost current card with sustain
- [boost_then_sustain](boost_then_sustain.md) - Boost other cards with sustain
- [negate_boost](negate_boost.md) - Remove boost effects

## Real Usage Examples

From card definitions:
- Cards that convert themselves into ongoing effects
- Strategic boosts that provide lasting value
- Self-sustaining continuous effects
- Cards that reward investment with persistence