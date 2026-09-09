# 41's Combat Alert - World of Warcraft 1.12.1 addon

Alerts and/or Reports combat log events as you specify.

## Install

Copy the 41sCombatAlert folder into:

Interface\AddOns\

Then launch WoW

---

## Commands

/foca
    Open the configuration window.

You can also click the minimap icon to open or close the configuration window.

---

## Pattern

\* is the only wildcard. It means zero or more arbitrary characters.
Matching is case-insensitive.

currentpet will be replaced by your current pet's name. If there is no pet,
a pattern containing currentpet will not match.

Examples:

    currentpet*torment*resisted*
    your taunt was resisted*

### Your spellcast start

You can also trigger an alert when you begin casting a spell. These are addon
events, not combat-log lines, and only apply to your own casts:

```
SPELLCAST_START Fireball
SPELLCAST_START *
SPELLCAST_CHANNEL_START Mind Flay
```

`SPELLCAST_START` is sent for casts with a cast time; instant spells do not
send it. `SPELLCAST_CHANNEL_START` is sent when you begin a channelled spell.
Spellcast patterns must begin with one of these event names so that normal
combat-log patterns do not trigger from your casts.

On standard 1.12.1 clients, the channel start event normally includes the
spell name. Turtle WoW-based clients may instead provide the generic text
`Channeling`, so `SPELLCAST_CHANNEL_START *` is the reliable pattern for
channel starts on those clients.

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

## Text

When **Text** is enabled, the text entered in the **Text** field is displayed
on the screen when the alert is triggered.

The same text is also used as the chat-report message when one or more
Report to channels are selected.

The following message tokens work in both on-screen alerts and chat reports:

- `%t` — Your current target's name
- `%tt` — Your target's target's name
- `%p` — Your player name
- `%pet` — Your current pet's name

---

## Sound

When **Sound** is enabled, a sound is played when the alert is triggered.

### Choose one sound source from the Sound dropdown:

#### **Included Files**

- **Sound A** — Uses the included `SoundA.wav` file.
- **Sound B** — Uses the included `SoundB.wav` file.
- **Sound C** — Uses the included `SoundC.wav` file.
- **Sound D** — Uses the included `SoundD.wav` file.
- **Sound E** — Uses the included `SoundE.wav` file.
- **Sound F** — Uses the included `SoundF.wav` file.

#### **Custom File**

Put your WAV file in the addon's `Sounds` folder and enter its filename in the **File** field.
For example:

  `MySound.wav`

#### **MPQ Path**

Uses the WAV file path entered in the **MPQ** field.

The MPQ field is for an audio path inside the WoW client archives,
not a Windows file path. For example:

```
Sound\Interface\RaidWarning.wav
```

You can look for sound file path [>>>HERE<<<](https://github.com/fondlez/wow-sounds).

---

## Sound sequences and random groups

Press **Sequence** or **Random** on a parent alert to add a child alert.
Child alerts inherit the parent's Pattern, which cannot be edited, while their
Text, Sound, and Report to settings can be configured independently.

The parent alert is included as the first reaction:

- **Sequence** — Uses the parent reaction, then each enabled child reaction in
  order, and repeats from the beginning.
- **Random** — Randomly selects the parent reaction or one enabled child
  reaction each time the pattern matches.

---

## Starter examples

The Taunt-resisted example is enabled by default, has Text and Sound enabled,
and reports to Party. Existing alerts and SavedVariables are kept when
updating does not import settings from older CombatAlert packages.



<BR><BR>
---

This project is licensed under the [MIT License](LICENSE).
