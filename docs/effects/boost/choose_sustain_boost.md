# choose_sustain_boost

**Category**: Boost
**Description**: Allow player to choose which boosts to sustain from their active boosts.

## Parameters

- `amount` (optional): Number of boosts to sustain
  - **Type**: Integer
  - **Default**: 1
  - **Range**: Limited by available unsustained boosts
- `amount_min` (optional): Minimum number of boosts that must be sustained
  - **Type**: Integer
  - **Default**: Same as amount
  - **Range**: Less than or equal to amount

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `after` - After strike resolution
- `cleanup` - During cleanup phase

## Examples

**Choose to sustain 1 boost:**
```json
{
  "timing": "after",
  "effect_type": "choose_sustain_boost"
}
```

**Choose to sustain up to 2 boosts:**
```json
{
  "timing": "immediate",
  "effect_type": "choose_sustain_boost",
  "amount": 2
}
```

**Choose to sustain 1-3 boosts:**
```json
{
  "timing": "cleanup",
  "effect_type": "choose_sustain_boost",
  "amount": 3,
  "amount_min": 1
}
```

## Implementation Notes

- Calculates available choices as [`performing_player.get_boosts().size() - performing_player.sustained_boosts.size()`](../../scenes/core/local_game.gd:2487)
- Only creates decision if there are unsustained boosts available
- Uses [`DecisionType_ChooseFromBoosts`](../../scenes/core/local_game.gd:2492) decision type
- Amount is capped by available unsustained boosts
- Creates [`EventType_ChooseFromBoosts`](../../scenes/core/local_game.gd:2502) event
- Logs message if no boosts available to sustain
- Provides strategic choice in boost management
- Enables selective preservation of valuable effects

## Related Effects

- [sustain_all_boosts](sustain_all_boosts.md) - Sustain all boosts automatically
- [sustain_this](sustain_this.md) - Sustain specific card
- [boost_then_sustain](boost_then_sustain.md) - Boost with automatic sustain
- [negate_boost](negate_boost.md) - Remove boost effects

## Real Usage Examples

From card definitions:
- Strategic cards that reward careful boost management
- Effects that provide selective sustain options
- End-of-turn abilities that preserve key boosts
- Choice-driven mechanics that create meaningful decisions