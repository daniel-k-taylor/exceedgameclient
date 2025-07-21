# SealThisBoost

**Category**: Seal and Transform
**Description**: Seals a specific boost card from continuous boosts to the sealed area immediately.

## Parameters

- `card_name` (required): The display name of the boost card to seal
  - **Type**: String
  - **Range**: Must match an existing boost card's display name

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- Can be used with choice effects to conditionally seal specific boosts

## Examples

**Seal specific boost (Arakune):**
```json
{
  "effect_type": "advance",
  "amount": 1,
  "and": {
    "effect_type": "seal_this_boost",
    "card_name": "How Shall I Cook You?"
  }
}
```

**Seal with movement choice:**
```json
{
  "effect_type": "retreat",
  "amount": 1,
  "and": {
    "effect_type": "seal_this_boost",
    "card_name": "How Shall I Cook You?"
  }
}
```

**Conditional sealing (King):**
```json
{
  "condition_card_id": "king_decree_kinglystrut",
  "effect_type": "seal_this_boost",
  "card_name": "Kingly Strut"
}
```

**Another King example:**
```json
{
  "condition_card_id": "king_decree_magnificentcape",
  "effect_type": "seal_this_boost",
  "card_name": "Magnificent Cape"
}
```

## Implementation Notes

- Searches both the performing player's and opponent's continuous boosts for the named card
- Removes the first matching card from continuous boosts and moves it to the sealed area
- The card must be currently in play as a continuous boost
- Creates log messages describing which card was sealed
- If no matching card is found in continuous boosts, the effect does nothing
- The sealed area may be secret (face-down) depending on character settings
- Can target boost cards from either player's continuous boost area

## Related Effects

- [`seal_continuous_boosts`](seal_continuous_boosts.md) - Seals all continuous boosts
- [`seal_this`](seal_this.md) - Seals the current card
- [`discard_continuous_boost`](../cards/discard_continuous_boost.md) - Discards instead of sealing
- [`remove_from_continuous_boosts`](../boost/remove_from_continuous_boosts.md) - Removes without sealing

## Real Usage Examples

From card definitions:
- Arakune's "How Shall I Cook You?" interactions: Multiple movement effects that seal this specific boost
- King's decree cards: Conditional sealing of specific boost cards when certain conditions are met
- Strategic board control: Remove specific opponent boosts while adding them to your sealed area
- Strategic context: Allows targeted removal of specific continuous effects while potentially gaining strategic value from the sealed cards, often used in conditional or choice-based effects