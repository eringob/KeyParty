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

- `/kp refresh` or `/keyparty refresh`
  - Reads ratings, requests keystones, and prints a report.
- `/kp report`
  - Prints the latest report from the current cache.

## Heuristic for the "best progression key"

For each available keystone in the group, the addon calculates a score:

- More points when more players have no score yet for that dungeon.
- Then preference for lower average group score on that dungeon.
- Then preference for higher key level.

This gives a practical recommendation for group progression.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
