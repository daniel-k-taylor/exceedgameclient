# choose_sustain_boost

**Category**: Choice and Selection
**Description**: Allow player to choose which boost cards to sustain (keep in play) instead of discarding them.

## Parameters

- `amount_min` (required): Minimum number of boosts that must be sustained
  - **Type**: Integer
  - **Range**: 0 or higher
  - **Note**: 0 allows choosing to sustain none
- `amount_max` (optional): Maximum number of boosts that can be sustained
  - **Type**: Integer
  - **Default**: All available boosts
- `boost_name_limitation` (optional): Restrict which boost types can be sustained
  - **Type**: String
  - **Note**: Limit to specific boost card names

## Supported Timings

- `cleanup` - During cleanup phase
- `immediate` - Immediately when triggered
- `after` - After strike resolution
- `before` - Before strike resolution

## Examples

**Optional boost sustain:**
```json
{
  "timing": "cleanup",
  "effect_type": "choose_sustain_boost",
  "amount_min": 0
}
```

**Required boost sustain:**
```json
{
  "timing": "cleanup",
  "effect_type": "choose_sustain_boost",
  "amount_min": 1,
  "amount_max": 2
}
```

**Sustain all boosts:**
```json
{
  "and": {
    "effect_type": "choose_sustain_boost",
    "amount_min": 0,
    "amount_max": 99
  }
}
```

**Hit effect sustain:**
```json
{
  "timing": "hit",
  "effect_type": "choose_sustain_boost",
  "amount_min": 0,
  "amount_max": 1
}
```

**Specific boost type:**
```json
{
  "timing": "cleanup",
  "effect_type": "choose_sustain_boost",
  "amount_min": 1,
  "boost_name_limitation": "Focus"
}
```

## Implementation Notes

- Creates a decision state where player selects from their active boost cards
- Sustained boosts remain in play and continue their effects
- Non-sustained boosts are discarded as normal
- If amount_min is 0, player can choose to sustain no boosts
- If no boosts are in play, effect has no impact
- Only boost cards currently in the boost zone are available for selection
- Selection happens before normal boost cleanup/discard
- Sustained boosts bypass normal end-of-turn discard rules

## Related Effects

- [sustain_this](../boost/sustain_this.md) - Automatically sustain specific boost
- [sustain_all_boosts](../boost/sustain_all_boosts.md) - Sustain all boosts automatically
- [discard_continuous_boost](../cards/discard_continuous_boost.md) - Force discard boosts
- [boost_then_sustain](../boost/boost_then_sustain.md) - Boost and sustain combination

## Real Usage Examples

From card definitions:
- Platinum's cleanup effects: Choose to sustain boosts for continued benefits
- Hit effects: Sustain boosts as reward for successful attacks
- Character abilities: Selective boost sustain for strategic advantage
- End-of-turn choices: Decide which boosts are worth keeping vs discarding
- Resource management: Balance boost effects against hand size and future plays