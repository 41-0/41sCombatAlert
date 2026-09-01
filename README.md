# 41sCombatAlert - for World of Warcraft 1.12.1 client


## Install

Copy the 41sCombatAlert folder into:

Interface\AddOns\

Then launch WoW

---

## Commands

/foca
    Open the configuration window.

/foca test
    Test the on-screen alert and sound.

/foca hide
    Hide the current on-screen alert.

You can also click the minimap icon to open or close the configuration window.

---

## Pattern

* is the only wildcard. It means zero or more arbitrary characters.
Matching is case-insensitive.

currentpet will be replaced by your current pet's name. If there is no pet,
a pattern containing currentpet will not match.

Examples:

    currentpet * torment * resisted *
    your taunt was resisted *

Each alert has:
    Enable
    Text
    Sound
    Report to: Party, Raid, Say, Yell

More than one report channel can be selected. The Text field is used as both
the on-screen alert and the chat-report message. Party and Raid messages are
sent only while you are in a party or raid respectively.

The alert editor displays four alerts per page. Use Previous and Next to move
between pages.

---

## Starter examples

The Taunt-resisted example is enabled by default, has Text and Sound enabled,
and reports to Party. Existing alerts and SavedVariables are kept when
updating does not import settings from older CombatAlert packages.
