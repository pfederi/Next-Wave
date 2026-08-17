#!/usr/bin/env python3
"""
Checks that every string in a Localizable.xcstrings catalog has a
translated (non-empty) entry for de, fr, and it.

Usage: scripts/check_localization_completeness.py <path-to-Localizable.xcstrings> [...]
Exits 1 and prints every missing (key, language) pair if anything is missing.
"""
import json
import sys

REQUIRED_LANGUAGES = ("de", "fr", "it")


def check_catalog(path):
    with open(path) as f:
        catalog = json.load(f)

    missing = []
    for key, entry in catalog.get("strings", {}).items():
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        for lang in REQUIRED_LANGUAGES:
            unit = localizations.get(lang, {}).get("stringUnit")
            if not unit or unit.get("state") != "translated" or not unit.get("value"):
                missing.append((key, lang))
    return missing


def main():
    if len(sys.argv) < 2:
        print("Usage: check_localization_completeness.py <path-to-Localizable.xcstrings> [...]")
        sys.exit(2)

    any_missing = False
    for path in sys.argv[1:]:
        missing = check_catalog(path)
        if missing:
            any_missing = True
            print(f"Missing {len(missing)} translations in {path}:")
            for key, lang in missing:
                print(f"  [{lang}] {key!r}")
        else:
            print(f"All strings fully translated in {path}")

    sys.exit(1 if any_missing else 0)


if __name__ == "__main__":
    main()
