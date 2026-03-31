# Key Party (WoW AddOn)

Key Party is a World of Warcraft addon that helps your group by:

- Showing Mythic+ ratings per player and per dungeon.
- Collecting available keystones from group members (via addon communication).
- Recommending the best keystone for progression based on group scores.
- Showing a visual party overview with keystone icons, weekly affixes, dungeon score icons, and teleport availability.

## Why You Want This AddOn (and Your Group Does Too)

Key Party is for that moment when five adults in voice chat suddenly forget how numbers work and start arguing about whose key is "best." Everyone runs `/kp refresh`, the addon gathers what keys the group actually has, compares dungeon scores, and serves up a practical recommendation so you can stop debating and start timing.

## Important

The WoW API does not allow reading other players' keystones directly without participation.
Because of this, group members only share their keystone if they are also running this addon.

## Installation

1. Copy the `KeyParty` folder to your WoW addons directory:
  - `_retail_/Interface/AddOns/KeyParty`
2. Restart WoW or use `/reload`.

## Usage

Main slash commands:

- `/kp`
  - Opens/closes the addon frame.
  - If there is no cached data yet, it triggers a refresh first.
- `/keyparty`
  - Alias of `/kp`.

### User Commands

- `/kp refresh`
  - Refreshes ratings and keys, then updates UI/report.
- `/kp report`
  - Prints the latest cached group report.

## UI Overview

The main frame contains four sections:

- `GROUP RATINGS`
  - Shows the current Mythic+ rating for each visible group member.
  - Player names include `-Realm` when that player is on a different realm than you.
- `AVAILABLE KEYSTONES`
  - Shows up to five party keystones as large dungeon icons across the width of the frame.
  - Each icon shows:
    - A small dungeon abbreviation at the top.
    - The key level in the center.
    - The keystone owner's name underneath.
  - Owner names are truncated with `...` if they are wider than the icon.
  - The sixth column shows the current weekly affixes in a `2x2` icon grid.
  - Hovering a weekly affix shows a tooltip with the affix name, activation level, and description.
- `YOUR SCORES`
  - Shows the current season dungeons as icons.
  - Each icon shows:
    - Dungeon score in the center.
    - Highest completed key level at the top.
    - A dungeon abbreviation under the icon.
  - If a dungeon teleport spell is mapped and known, clicking the icon casts that teleport.
  - Teleports show cooldown overlays when active.
- `BEST PROGRESSION KEY`
  - Shows the recommended key as a large dungeon icon.
  - The key level is shown inside the icon.
  - The dungeon name, owner, and recommendation reason are shown next to it.
  - If a teleport is available for that dungeon, the icon is clickable and shows cooldown state.

Bottom options:

- `Auto open after dungeon finish`
  - Automatically opens the frame when end-of-dungeon refresh runs.
- `Party chat announcement Best Progression Key after dungeon finish`
  - Sends the best progression key announcement to group chat (`INSTANCE_CHAT` / `RAID` / `PARTY`) after dungeon completion.
  - If disabled, the announcement stays local.

When a usage/help chat prompt is shown in-game, only these user commands are listed:

- `/kp [refresh|report]`

### Developer Commands (Internal)

These commands remain available for development and debugging, but are not shown in the user-facing usage prompt:

- `/kp debug`
  - Prints debug information about current internal state.
- `/kp debugaddon`
  - Prints addon presence/debug status for current group members.
- `/kp debugcolors`
  - Dumps instance score color info used by the icon coloring logic.
- `/kp debugcooldown`
  - Enables cooldown debug mode for 45 seconds.
- `/kp debugcooldown <seconds>`
  - Enables cooldown debug mode for the provided duration.
  - Example: `/kp debugcooldown 90`
- `/kp debugcooldown off`
  - Disables cooldown debug mode.
- `/kp testdungeonend`
  - Simulates end-of-dungeon refresh behavior for testing.
- `/kp testbestkeyannouncement`
  - Forces the end-of-dungeon best-key chat announcement locally, including when solo.
- `/kp dumpapi`
  - Prints a dump of available dungeon-score API results for debugging.
- `/kp setportal <mapID> <spellID>`
  - Stores or overrides a portal spell mapping for a dungeon map.
  - Example: `/kp setportal 5042 445424`

## Heuristic for the "best progression key"

For each available keystone in the group, the addon calculates a score:

- More points when more players have no score yet for that dungeon.
- Then preference for lower average group score on that dungeon.
- Then preference for higher key level.

This gives a practical recommendation for group progression.

## Notes

- Keystones are still shared by addon communication, so other players must run the addon for their key to appear here.
- Weekly affixes are read from the live Blizzard Mythic+ API for the current week.
- Dungeon score colors use Blizzard rarity color data when available, with fallback thresholds when needed.
- After the automatic end-of-dungeon refresh, if at least one party member is not using the addon, Key Party prints the next best progression key.
- When group version data is available, the addon warns you in local chat if your installed Key Party version is older than someone else in your current group.
- Internal addon identifiers now use `KeyParty`; existing saved settings are migrated automatically from older `KeyLottery` data.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
