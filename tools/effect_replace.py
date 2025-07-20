#!/usr/bin/env python3
"""
Script to replace string literals with StrikeEffects constant references.

This script parses scenes/core/strike_effects.gd to extract const variable
names and their string values, then replaces all instances of those strings
in a target file with StrikeEffects.VariableName format.

Usage:
    python effect_replace.py <target_file>

Example:
    python effect_replace.py scenes/some_file.gd

This will replace occurrences like:
    "add_attack_effect" -> StrikeEffects.AddAttackEffect
    "add_attack_triggers" -> StrikeEffects.AddAttackTriggers
"""

import sys
import re
import os
from typing import Dict, Tuple


def parse_strike_effects_file(file_path: str) -> Dict[str, str]:
    """
    Parse the strike_effects.gd file to extract constant mappings.

    Args:
        file_path: Path to the strike_effects.gd file

    Returns:
        Dictionary mapping string values to StrikeEffects.ConstantName
    """
    mappings = {}

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Regex to match const declarations like:
        # const VariableName = "string_value"
        const_pattern = r'const\s+(\w+)\s*=\s*"([^"]+)"'

        for match in re.finditer(const_pattern, content):
            variable_name = match.group(1)
            string_value = match.group(2)

            # Map the string value to StrikeEffects.VariableName
            mappings[string_value] = f"StrikeEffects.{variable_name}"

    except FileNotFoundError:
        print(f"Error: Could not find strike_effects.gd at {file_path}")
        sys.exit(1)
    except Exception as e:
        print(f"Error parsing strike_effects.gd: {e}")
        sys.exit(1)

    return mappings


def replace_in_file(target_file: str, mappings: Dict[str, str]) -> Tuple[
    int, bool
]:
    """
    Replace string literals in the target file with StrikeEffects references.

    Args:
        target_file: Path to the file to modify
        mappings: Dictionary mapping string values to
                  StrikeEffects.ConstantName

    Returns:
        Tuple of (number_of_replacements, success)
    """
    try:
        with open(target_file, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content
        total_replacements = 0

        # Sort by length (longest first) to avoid partial replacements
        sorted_strings = sorted(mappings.keys(), key=len, reverse=True)

        for string_value in sorted_strings:
            replacement = mappings[string_value]

            # Match the string in quotes, handling both single and double
            # quotes
            # This regex looks for the exact string surrounded by quotes
            patterns = [
                f'"{re.escape(string_value)}"',  # Double quotes
                f"'{re.escape(string_value)}'"   # Single quotes
            ]

            for pattern in patterns:
                matches = list(re.finditer(pattern, content))
                if matches:
                    content = re.sub(pattern, replacement, content)
                    total_replacements += len(matches)
                    print(f"  Replaced {len(matches)} occurrence(s) of "
                          f"{pattern} with {replacement}")

        # Only write if changes were made
        if content != original_content:
            with open(target_file, 'w', encoding='utf-8') as f:
                f.write(content)
            return total_replacements, True
        else:
            return 0, True

    except FileNotFoundError:
        print(f"Error: Could not find target file {target_file}")
        return 0, False
    except Exception as e:
        print(f"Error processing {target_file}: {e}")
        return 0, False


def main():
    """Main function to handle command line arguments and execute the
    replacement."""
    if len(sys.argv) != 2:
        print("Usage: python effect_replace.py <target_file>")
        print("Example: python effect_replace.py scenes/some_file.gd")
        sys.exit(1)

    target_file = sys.argv[1]
    strike_effects_file = "scenes/core/strike_effects.gd"

    # Check if target file exists
    if not os.path.exists(target_file):
        print(f"Error: Target file '{target_file}' does not exist")
        sys.exit(1)

    # Check if strike_effects.gd exists
    if not os.path.exists(strike_effects_file):
        print(f"Error: Strike effects file '{strike_effects_file}' "
              f"does not exist")
        sys.exit(1)

    print(f"Parsing {strike_effects_file}...")
    mappings = parse_strike_effects_file(strike_effects_file)

    if not mappings:
        print("No constant mappings found in strike_effects.gd")
        sys.exit(1)

    print(f"Found {len(mappings)} constant mappings")
    print(f"Processing {target_file}...")

    replacements, success = replace_in_file(target_file, mappings)

    if success:
        if replacements > 0:
            print(f"✅ Successfully made {replacements} replacements in "
                  f"{target_file}")
        else:
            print(f"ℹ️  No replacements needed in {target_file}")
    else:
        print(f"❌ Failed to process {target_file}")
        sys.exit(1)


if __name__ == "__main__":
    main()