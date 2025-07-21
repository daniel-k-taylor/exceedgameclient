# Strike Effect Documentation Instructions

This document provides detailed instructions for creating individual effect documentation files. Each effect should follow this standardized format to ensure consistency and completeness.

## File Structure

Each effect gets its own markdown file in the appropriate category folder:
- `docs/effects/{category}/{effect_name}.md`
- File names should be lowercase with underscores (e.g., `powerup_per_boost_in_play.md`)
- File names should match the effect constant from `strike_effects.gd` (converted to lowercase)

## Standard Template

Every effect documentation file should follow this exact structure:

```markdown
# {effect_name}

**Category**: {Category}
**Description**: {Single sentence describing what the effect does}

## Parameters

{List of all parameters with detailed explanations}

## Supported Timings

{List of when this effect can be used}

## Examples

{Real JSON examples from card definitions}

## Implementation Notes

{Technical details, edge cases, and important behavior}

## Related Effects

{Cross-references to similar or complementary effects}

## Real Usage Examples

{Actual examples from character cards in the game}
```

## Section-by-Section Instructions

### 1. Header and Basic Info

```markdown
# {effect_name}

**Category**: {Category}
**Description**: {Single sentence describing what the effect does}
```

**Instructions:**
- **Effect Name**: Use exact name from `strike_effects.gd` (without quotes)
- **Category**: One of the 13 defined categories (Movement, Stats, Card Management, etc.)
- **Description**: Single clear sentence explaining the effect's purpose
  - Focus on what it does, not how it works
  - Avoid technical jargon when possible
  - Example: "Move the character forward by a specified amount" not "Calls advance_character_position with amount parameter"

### 2. Parameters Section

```markdown
## Parameters

- `parameter_name` (required/optional): Description of what this parameter does
  - **Type**: Data type (Integer, String, Boolean, Array, Effect object)
  - **Range**: Valid values or constraints
  - **Default**: Default value if parameter is optional
  - **Special Values**: Any special string values or constants
```

**Instructions:**
- List ALL parameters the effect accepts
- Mark each as `(required)` or `(optional)`
- Include comprehensive type information:
  - **Type**: Integer, String, Boolean, Array, Effect object, etc.
  - **Range**: "Any positive integer", "1-9", "true/false only", etc.
  - **Default**: What happens if not specified
  - **Special Values**: Dynamic strings like "strike_x", "GAUGE_COUNT", constants, etc.

**Examples:**
```markdown
- `amount` (required): Number of spaces to advance
  - **Type**: Integer or String
  - **Range**: Any positive integer
  - **Special Values**: "strike_x" - Use current strike's X value

- `opponent` (optional): If true, affects opponent instead of self
  - **Type**: Boolean
  - **Default**: false

- `valid_zones` (optional): Source zones for the effect
  - **Type**: Array of strings
  - **Default**: ["hand"]
  - **Values**: ["hand"], ["gauge"], ["deck"], ["discard"]
```

### 3. Supported Timings Section

```markdown
## Supported Timings

- `timing_name` - Description of when this occurs
```

**Instructions:**
- List ALL timings where this effect can be used
- Include brief explanation of what each timing means
- Base this on actual usage in card definitions, not just code possibilities
- Common timings include:
  - `before` - Before strike resolution
  - `during_strike` - During strike resolution
  - `hit` - When attack hits
  - `after` - After strike resolution
  - `now` - Immediately when played
  - `immediate` - Immediately when triggered
  - `cleanup` - During cleanup phase
  - `set_strike` - When setting a strike

### 4. Examples Section

```markdown
## Examples

**Brief description of example:**
```json
{
  "timing": "during_strike",
  "effect_type": "effect_name",
  "parameter": "value"
}
```
```

**Instructions:**
- Provide 3-5 real JSON examples showing different parameter combinations
- Use actual JSON format that would appear in card definitions
- Include variety: basic usage, complex parameters, chained effects
- Add brief descriptions for each example
- Examples should be realistic and actually usable

**Example formats:**
```markdown
**Basic power increase:**
```json
{
  "timing": "during_strike",
  "effect_type": "powerup",
  "amount": 2
}
```

**Conditional power boost:**
```json
{
  "timing": "during_strike",
  "condition": "is_critical",
  "effect_type": "powerup",
  "amount": 3
}
```
```

### 5. Implementation Notes Section

```markdown
## Implementation Notes

- Technical detail about how the effect works
- Edge cases and special behavior
- Interactions with other systems
- Performance considerations
- Validation rules
```

**Instructions:**
- Include important technical details that affect usage
- Document edge cases and special behavior
- Explain interactions with other game systems
- Note any validation rules or constraints
- Mention performance implications if relevant
- Keep technical but accessible

**Examples:**
- "Stacks with other power effects"
- "Can be modified by multiplier effects"
- "Creates appropriate log message"
- "May trigger reshuffle if deck becomes empty"
- "Cannot move to space occupied by opponent"

### 6. Related Effects Section

```markdown
## Related Effects

- [effect_name](relative_path.md) - Brief description of relationship
```

**Instructions:**
- Link to related effects in other categories
- Use relative paths to markdown files
- Brief description of how they relate (similar, opposite, complementary)
- Include 3-6 most relevant related effects
- Focus on effects users might want to use together or compare

**Examples:**
```markdown
- [speedup](speedup.md) - Increase speed instead of power
- [powerup_per_boost_in_play](powerup_per_boost_in_play.md) - Power scaling variant
- [multiply_positive_power_bonuses](multiply_positive_power_bonuses.md) - Power multiplier
```

### 7. Real Usage Examples Section

```markdown
## Real Usage Examples

From card definitions:
- Character Name's "Card Name": Brief description or JSON snippet
- Game context: How this effect is used strategically
```

**Instructions:**
- Include actual examples from character cards in the game
- Reference specific character names and card names when possible
- Provide brief context about how the effect is used strategically
- Show variety across different characters/playstyles
- Validate examples against actual card definitions

**Examples:**
```markdown
From card definitions:
- Ryu's "Hadoken": `{ "timing": "during_strike", "effect_type": "powerup", "amount": 2 }`
- Sol Badguy's combo attacks: Power scaling for extended sequences
- Various rushdown characters: Offensive pressure mechanics
```

## Quality Standards

### Accuracy
- All parameters must be verified against actual code implementation
- Timing information must be validated against real card usage
- Examples must be tested and functional

### Completeness
- Document ALL parameters, even rarely used ones
- Include ALL supported timings found in actual usage
- Cover edge cases and special behavior

### Consistency
- Use identical formatting across all effect files
- Use same terminology and conventions
- Maintain consistent cross-reference style

### Usability
- Write for card designers, not just developers
- Include enough examples to understand all major use cases
- Provide strategic context, not just technical specs

## File Naming Conventions

- Use exact effect name from `strike_effects.gd`
- Convert to lowercase
- Replace camelCase with underscore_case
- Example: `PowerupPerBoostInPlay` → `powerup_per_boost_in_play.md`

## Cross-Reference Guidelines

- Always use relative paths: `../category/effect.md`
- Link to effects that users might use together
- Link to opposite effects (powerup ↔ speedup)
- Link to scaling variants (powerup → powerup_per_boost_in_play)
- Link to related mechanics (ignore_armor ↔ armorup)

## Validation Checklist

Before completing an effect documentation:

- [ ] Header uses exact effect name
- [ ] Category is correct and matches folder structure
- [ ] All parameters documented with types and constraints
- [ ] Timing list verified against actual card usage
- [ ] Examples are valid JSON that could work in cards
- [ ] Implementation notes cover important edge cases
- [ ] Related effects links work and are relevant
- [ ] Real usage examples reference actual game content
- [ ] File name follows naming conventions
- [ ] Formatting matches template exactly

## Examples of Well-Documented Effects

See these existing files as examples of the complete format:
- `movement/advance.md` - Complex parameters with special values
- `stats/powerup.md` - Simple but comprehensive
- `choice/choice.md` - Complex effect with multiple options
- `gauge/gauge_for_effect.md` - Resource mechanics
- `attack/critical.md` - Simple effect with no parameters

## Tools and Resources

- **Source Code**: `scenes/core/strike_effects.gd` - Effect constants
- **Implementation**: `scenes/core/local_game.gd` - Effect implementations
- **Usage Examples**: `data/card_definitions.json` - Real card usage
- **Validation**: Search codebase for effect name to find all usage patterns

This standardized approach ensures every effect is documented comprehensively and consistently, making the documentation system valuable for both developers and card designers.