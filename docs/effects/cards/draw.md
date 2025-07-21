# draw

**Category**: Card Management
**Description**: Draw cards from deck to hand.

## Parameters

- `amount` (required): Number of cards to draw
  - **Type**: Integer or String
  - **Special Values**:
    - `"strike_x"` - Draw equal to current strike's X value
    - `"GAUGE_COUNT"` - Draw equal to number of cards in gauge
    - `"SPACES_BETWEEN"` - Draw equal to distance between characters minus 1
    - Any positive integer
- `opponent` (optional): If true, opponent draws instead of you
  - **Type**: Boolean
  - **Default**: false
- `from_bottom` (optional): Draw from bottom of deck instead of top
  - **Type**: Boolean
  - **Default**: false
- `reveal` (optional): Reveal the drawn cards
  - **Type**: Boolean
  - **Default**: false
- `and` (optional): Chained effect that executes after drawing
  - **Type**: Effect object

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `after` - After strike resolution
- `hit` - When attack hits
- `cleanup` - During cleanup phase
- `end_of_turn` - At end of turn

## Examples

**Basic draw:**
```json
{
  "timing": "now",
  "effect_type": "draw",
  "amount": 1
}
```

**Opponent draws:**
```json
{
  "timing": "immediate",
  "effect_type": "draw",
  "amount": 2,
  "opponent": true
}
```

**Draw using strike X:**
```json
{
  "timing": "hit",
  "effect_type": "draw",
  "amount": "strike_x"
}
```

**Draw from bottom and reveal:**
```json
{
  "timing": "after",
  "effect_type": "draw",
  "amount": 1,
  "from_bottom": true,
  "reveal": true
}
```

**Draw with chained effect:**
```json
{
  "timing": "hit",
  "effect_type": "draw",
  "amount": 1,
  "and": {
    "effect_type": "strike"
  }
}
```

## Implementation Notes

- Amount is modified by `strike_stat_boosts.increase_draw_effects_by`
- If deck is empty, triggers reshuffle if available
- Drawn cards are added to the end of hand
- If revealing, cards are shown to both players

## Related Effects

- [draw_to](draw_to.md) - Draw to specific hand size
- [draw_or_discard_to](draw_or_discard_to.md) - Draw or discard to target size
- [draw_any_number](draw_any_number.md) - Choose number of cards to draw
- [discard_hand](discard_hand.md) - Discard all cards from hand

## Real Usage Examples

From card definitions:
- Seijun's "Exceed": `{ "timing": "start_of_next_turn", "effect_type": "draw", "amount": 1 }`
- Ramlethal's "Exceed": `{ "effect_type": "draw", "amount": 3 }`
- Londrekia's "Icicle Spear": `{ "timing": "after", "effect_type": "draw", "amount": 2 }`
- Shovel Knight: `{ "timing": "on_move_action", "effect_type": "draw", "amount": 1 }`