# StrikeResponseReading

**Category**: Utility (also classified under Special Mechanics)
**Description**: Performs a strike using a specific reading card, optionally with EX or overload variations.

## Parameters

- `card_id` (required): The ID of the reading card to use for the strike
  - **Type**: Integer
  - **Range**: Valid card ID from the game database
  - **Usage**: References the specific reading card to strike with

- `ex_card_id` (optional): The ID of an EX card to use with the reading
  - **Type**: Integer
  - **Range**: Valid card ID from the game database
  - **Usage**: Enables EX version of the reading strike

- `overload_name` (optional): Display name of an overload card variant
  - **Type**: String
  - **Usage**: Used for UI display of overload reading options

## Supported Timings

- Decision resolution - Automatically triggered when player makes reading choice

## Examples

**Basic reading strike:**
```json
{
  "effect_type": "strike_response_reading",
  "card_id": 12345
}
```

**Reading with EX card:**
```json
{
  "effect_type": "strike_response_reading",
  "card_id": 12345,
  "ex_card_id": 67890
}
```

**Reading with overload:**
```json
{
  "effect_type": "strike_response_reading",
  "card_id": 12345,
  "ex_card_id": 67890,
  "overload_name": "Overload Strike"
}
```

## Implementation Notes

- Used internally for reading card strike mechanics
- Creates `EventType_Strike_EffectDoStrike` event with specified card
- Can include EX card enhancements when `ex_card_id` is provided
- Overload name is used for UI purposes to show overload options
- Reading cards have special strike properties and timing
- Part of advanced character-specific mechanics (like reading-based fighters)

## Related Effects

- [`strike_from_gauge`](strike_from_gauge.md) - Alternative special strike source
- [`strike_faceup`](strike_faceup.md) - Strike revelation mechanics
- [`choice`](../choice/choice.md) - Choice mechanics that can lead to reading strikes

## Real Usage Examples

From card definitions:
- Reading card mechanics: Used internally when players choose reading-based strikes
- Character-specific systems: Part of reading card fighter implementations
- EX combinations: `"ex_card_id": card_id` enables enhanced reading strikes
- Advanced mechanics: Used for complex reading card interactions and overloads