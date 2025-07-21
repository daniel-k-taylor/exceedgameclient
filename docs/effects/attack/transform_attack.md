# transform_attack

**Category**: Attack
**Description**: Transform the current attack into a different attack card, replacing its properties and effects.

## Parameters

- `card_name` (required): Name of the card to transform into
  - **Type**: String
  - **Range**: Any valid card name from card definitions
  - **Special Values**: Must match exact display name from card data

## Supported Timings

- `after` - After strike resolution
- `cleanup` - During cleanup phase

## Examples

**Basic attack transformation:**
```json
{
  "timing": "after",
  "effect_type": "transform_attack",
  "card_name": "Enhanced Strike"
}
```

**Cleanup transformation:**
```json
{
  "timing": "cleanup",
  "effect_type": "transform_attack",
  "card_name": "Ultimate Form"
}
```

**Conditional transformation:**
```json
{
  "condition": "is_critical",
  "effect_type": "transform_attack",
  "card_name": "Critical Evolution"
}
```

## Implementation Notes

- Completely replaces the current attack card with the specified card
- Expected to be used at the end of a strike for transformation mechanics
- Creates new card data and effects based on the target card
- Generates transformation events and log messages
- Used for evolution mechanics, upgrade systems, or form changes
- Transformation is permanent for the duration of the effect
- New card retains current positioning and strike context

## Related Effects

- [attack_copy_gauge_or_transform_becomes_ex](attack_copy_gauge_or_transform_becomes_ex.md) - EX transformation marker
- [become_wide](become_wide.md) - Character form transformation
- [attack_is_ex](attack_is_ex.md) - Make attack EX
- [copy_other_hit_effect](copy_other_hit_effect.md) - Copy effects from other attacks

## Real Usage Examples

From card definitions:
- Evolution-based characters: Attacks that transform into stronger versions
- Form-changing mechanics: Different attack modes or stances
- Upgrade systems: Basic attacks becoming enhanced versions
- Character development: Attacks that grow stronger over time