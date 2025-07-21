# choose_calculate_range_from_buddy

**Category**: Choice and Selection
**Description**: Allow player to choose which buddy to calculate range from for attack or effect targeting.

## Parameters

- `buddy_name` (required): Name of the buddy type to calculate range from
  - **Type**: String
  - **Note**: Must match a valid buddy name in the game
- `optional` (optional): If true, player can choose not to use this effect
  - **Type**: Boolean
  - **Default**: false
- `condition` (optional): Condition that must be met for this choice to be available
  - **Type**: String
- `condition_detail` (optional): Additional details for the condition
  - **Type**: String

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `set_strike` - When setting a strike
- `immediate` - Immediately when triggered

## Examples

**Choose buddy for range calculation:**
```json
{
  "timing": "during_strike",
  "effect_type": "choose_calculate_range_from_buddy",
  "buddy_name": "Dissolve"
}
```

**Optional buddy range choice:**
```json
{
  "timing": "before",
  "effect_type": "choose_calculate_range_from_buddy",
  "buddy_name": "Lightningrod",
  "optional": true
}
```

**Conditional buddy range:**
```json
{
  "timing": "set_strike",
  "condition": "buddy_in_play",
  "condition_detail": "Dissolve",
  "effect_type": "choose_calculate_range_from_buddy",
  "buddy_name": "Dissolve"
}
```

**Range calculation with multiple buddies:**
```json
{
  "timing": "during_strike",
  "effect_type": "choose_calculate_range_from_buddy",
  "buddy_name": "Any",
  "optional": false
}
```

## Implementation Notes

- Creates a decision state where player chooses from available buddies of the specified type
- If optional is true, player can decline to use any buddy for range calculation
- Range calculation uses the buddy's current position instead of the character's position
- Only buddies of the specified name type are available for selection
- If no valid buddies are in play, the choice is automatically skipped
- The chosen buddy becomes the origin point for all range-based calculations during the current effect

## Related Effects

- [calculate_range_from_buddy](../buddy/calculate_range_from_buddy.md) - Automatic buddy range calculation
- [place_buddy_at_range](../buddy/place_buddy_at_range.md) - Place buddy at specific range
- [choice](choice.md) - Basic choice mechanism

## Real Usage Examples

From card definitions:
- Dissolve character cards: Choose which Dissolve buddy to calculate range from
- Lightningrod attacks: Optional choice to use lightningrod position for range
- Multi-buddy characters: Strategic positioning choices for optimal range coverage
- Enchantress spell effects: Choose spell circle for range-based targeting