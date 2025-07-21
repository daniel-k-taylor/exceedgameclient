# Strike Effects Documentation

This directory contains comprehensive documentation for all 340+ strike effects used in the card game engine.

## Organization

Each effect is documented in its own markdown file, organized by category:

- **Movement Effects** - Character and opponent movement
- **Stat Modification Effects** - Power, speed, armor, guard, range modifications
- **Card Management Effects** - Drawing, discarding, deck manipulation
- **Gauge and Force Effects** - Gauge operations and force generation
- **Attack Modification Effects** - Attack properties and defense
- **Choice and Selection Effects** - Player choices and card selection
- **Boost Effects** - Boost operations and interactions
- **Buddy and Placement Effects** - Buddy placement and management
- **Seal and Transform Effects** - Card sealing and transformation
- **Protection and Passive Effects** - Defensive abilities and passives
- **Life and Damage Effects** - Life manipulation and damage
- **Special Mechanics** - Unique game mechanics
- **Utility Effects** - General utility and helper effects

## File Structure

```
docs/effects/
├── README.md (this file)
├── index.md (searchable index)
├── movement/
│   ├── advance.md
│   ├── close.md
│   ├── retreat.md
│   └── ...
├── stats/
│   ├── powerup.md
│   ├── speedup.md
│   ├── armorup.md
│   └── ...
├── cards/
│   ├── draw.md
│   ├── discard_hand.md
│   └── ...
└── ...
```

## Quick Reference

### Most Common Effects
- [advance](movement/advance.md) - Move forward
- [close](movement/close.md) - Move toward opponent
- [retreat](movement/retreat.md) - Move away from opponent
- [pull](movement/pull.md) - Pull opponent toward you
- [push](movement/push.md) - Push opponent away
- [powerup](stats/powerup.md) - Increase power
- [speedup](stats/speedup.md) - Increase speed
- [armorup](stats/armorup.md) - Increase armor
- [draw](cards/draw.md) - Draw cards
- [choice](choice/choice.md) - Present multiple options

### Navigation

- [Complete Index](index.md) - Alphabetical list of all effects
- [By Category](index.md#by-category) - Effects grouped by functionality
- [By Timing](index.md#by-timing) - Effects grouped by when they can be used

## Format

Each effect documentation includes:
- **Category** - Functional grouping
- **Description** - What the effect does
- **Parameters** - Required and optional parameters with types
- **Supported Timings** - When this effect can be used
- **Examples** - Real usage from card definitions
- **Related Effects** - Similar or complementary effects

## Source Code References

- **Effect Constants**: `scenes/core/strike_effects.gd`
- **Implementation**: `scenes/core/local_game.gd` in `handle_strike_effect`
- **Card Examples**: `data/card_definitions.json` and `data/decks/*.json`