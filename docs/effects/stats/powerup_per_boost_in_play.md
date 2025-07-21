# powerup_per_boost_in_play

**Category**: Stats
**Description**: Gain power per boost currently in play. Scales power with active boost count.

## Parameters

- `amount` (required): Power gained per boost in play
  - **Type**: Integer

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Power per boost:**
```json
{
  "timing": "during_strike",
  "effect_type": "powerup_per_boost_in_play",
  "amount": 1
}
```

**Double power per boost:**
```json
{
  "timing": "during_strike",
  "effect_type": "powerup_per_boost_in_play",
  "amount": 2
}
```

## Implementation Notes

- Counts all continuous boosts currently active
- Encourages boost-heavy strategies
- Can provide significant power scaling
- Power = boost count × amount

## Related Effects

- [powerup](powerup.md) - Basic power increase
- [speedup_per_boost_in_play](speedup_per_boost_in_play.md) - Speed per boost
- [rangeup_per_boost_in_play](rangeup_per_boost_in_play.md) - Range per boost

## Real Usage Examples

From card definitions:
- Boost synergy builds
- Combo escalation mechanics
- Resource scaling strategies