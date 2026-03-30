# Key Party (WoW AddOn)

Key Party is a World of Warcraft addon that helps your group by:

- Showing Mythic+ ratings per player and per dungeon.
- Collecting available keystones from group members (via addon communication).
- Recommending the best keystone for progression based on group scores.

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

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
