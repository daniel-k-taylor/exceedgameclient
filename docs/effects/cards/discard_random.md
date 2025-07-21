# discard_random

**Category**: Card Management
**Description**: Discard random cards from hand. Cards are selected randomly and moved to discard pile.

## Parameters

- `amount` (required): Number of cards to discard randomly
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `hit` - When attack hits

## Examples

**Discard one random card:**
```json
{
  "timing": "now",
  "effect_type": "discard_random",
  "amount": 1
}
```

**Discard multiple random cards:**
```json
{
  "timing": "hit",
  "effect_type": "discard_random",
  "amount": 2
}
```

**Immediate random discard:**
```json
{
  "timing": "immediate",
  "effect_type": "discard_random",
  "amount": 3
}
```

## Implementation Notes

- Cards are selected randomly from hand
- If hand has fewer cards than amount, all cards are discarded
- Does not trigger individual card discard effects
- Creates random discard log message
- Used for chaos effects, costs, and hand disruption
- Cannot be prevented by targeting or selection

## Related Effects

- [discard_hand](discard_hand.md) - Discard all cards from hand
- [self_discard_choose](../choice/self_discard_choose.md) - Choose cards to discard
- [opponent_discard_random](opponent_discard_random.md) - Force opponent to discard randomly
- [discard_random_and_add_triggers](discard_random_and_add_triggers.md) - Discard random and add triggers

## Real Usage Examples

From card definitions:
- Happy Chaos's chaotic effects: Random hand disruption
- Various gambling and chance-based mechanics
- Cost effects for powerful abilities requiring random sacrifice
- Chaos-themed characters with unpredictable effects