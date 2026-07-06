# WASP Player-Facing Writing Style Guide

Status: READY for writers and builders  
Lane: 441

## Voice

Military-operational, accessible, direct.

- Write in second person: `you`, `your squad`, `your team`.
- Use present tense.
- Give orders and facts; do not hedge.
- Explain outcomes, not internals.
- Treat players as competent.

Preferred: `Capture towns to grow income.`  
Avoid: `You might want to try capturing towns so your team can maybe earn more.`

## Canonical Terms

| Preferred | Forbidden variants | Usage example |
|---|---|---|
| NATO | BLUFOR, West players, blue team | `NATO starts with US equipment.` |
| CSAT | OPFOR, East players, red team | `CSAT pushes from the eastern base.` |
| Insurgents | GUER, Resistance players, green team | `Insurgents hold towns and punish careless convoys.` |
| HQ | base truck, command car | `Protect the HQ or your team loses its build anchor.` |
| MHQ | mobile HQ, mobile base | `Move the MHQ before the enemy pins it.` |
| Town | city, objective town | `Capture towns to increase income.` |
| Camp | depot, flag point | `Secure camps before the town flips.` |
| Supply Run | supply mission, truck job | `Complete Supply Runs to fund upgrades.` |
| Supplies Delivered | supply value, supplies | `Supplies Delivered measures logistics output.` |
| Infantry Kills | man kills, soldier kills | `Infantry Kills count enemy foot soldiers.` |
| Vehicle Kills | car kills, light armor kills | `Vehicle Kills track ground vehicles.` |
| Air Kills | aircraft kills, plane kills | `Air Kills include helicopters and fixed-wing aircraft.` |
| Static Kills | turret kills, emplacement kills | `Static Kills track crewed weapons.` |
| Structure Kills | building kills, base kills | `Structure Kills show base damage.` |
| HQ / MHQ Kills | HQ kills, MHQ kills | `HQ / MHQ Kills are rare and decisive.` |
| Captures | caps, capture points | `Captures show town-control contribution.` |
| Deaths | times killed, losses | `Deaths count player deaths.` |
| Kill Streak | streak, best streak | `Kill Streak shows your best uninterrupted run.` |
| Longest Kill | longest shot, range record | `Longest Kill uses km above 1,000 m.` |
| Engine Score | score, game score | `Engine Score is the mission's raw score value.` |
| WF Menu | warfare menu, main menu | `Open the WF Menu to buy units and manage gear.` |
| EASA Menu | aircraft service menu, plane loadout | `Use the EASA Menu to service aircraft.` |
| Upgrade Menu | upgrades screen, tech menu | `The commander buys upgrades from the Upgrade Menu.` |
| Gear Menu | buy gear, equipment menu | `Use the Gear Menu after respawn.` |
| Factory | barracks/factory | `Factories produce units and vehicles.` |
| Barracks | infantry factory | `Barracks produce infantry.` |
| Light Factory | light vehicle factory | `Light Factory vehicles move infantry quickly.` |
| Heavy Factory | tank factory | `Heavy Factory units decide open fights.` |
| Aircraft Factory | air factory | `Aircraft Factory units need runway discipline.` |
| Service Point | repair point, rearm point | `Use Service Points to rearm and repair.` |
| Artillery | arty | `Artillery softens a town before an assault.` |
| Commander | CO, team lead | `The Commander sets construction and upgrades.` |
| Headless Client | HC | `Headless Clients run AI groups in the background.` |
| Round | match, game | `A Round ends when a side wins.` |
| Match Report | end report, stats post | `The Match Report posts after ROUNDEND.` |

## Formatting

- Headings use Title Case.
- List items use sentence case.
- Bold the first use of a key game term in a guide.
- Use code blocks for commands and key bindings.
- Keep paragraphs to one idea.
- Use commas for thousands: `1,250`.
- Use `km` for long distances at or above 1,000 m: `1.4 km`.

## UI Element Naming

- `WF Menu`: the main Warfare interface.
- `Gear Menu`: player equipment selection.
- `EASA Menu`: aircraft service/loadout interface.
- `Upgrade Menu`: commander upgrade screen.
- `Buy Units`: unit purchase screen.
- `Command Menu`: commander orders screen.

Do not invent alternate UI labels in guide text.

## Bot Copy Rules

- Embed titles use Title Case.
- Field labels are 24 characters or fewer.
- Field values are concise and numeric where possible.
- Use faction display names: NATO, CSAT, Insurgents.
- Do not use raw side tokens in public copy.
- Use one action line in admin alerts.

## Anti-Patterns

| Current pattern | Replace with |
|---|---|
| `might`, `may want to`, `try to` | direct verb: `Capture`, `Move`, `Build` |
| `the user` | `you` |
| `please` | omit |
| `BLUFOR/OPFOR/GUER` in public text | `NATO/CSAT/Insurgents` |
| `stuff`, `things`, `etc.` | name the object |
| `it is recommended` | direct instruction |
| passive voice: `towns are captured by` | active voice: `you capture towns` |
| unexplained acronym first use | spell out or use canonical term |

## Pre-Publish Checklist

1. The first paragraph tells the player what to do.
2. Every faction uses NATO, CSAT, or Insurgents.
3. Every UI element uses its canonical name.
4. No sentence uses `might`, `try to`, or `please`.
5. Commands and key bindings are in code formatting.
6. Numbers use commas and distance uses `km` above 1,000 m.
7. The guide uses second person.
8. The guide does not promise behavior not verified in source.
9. Bot embeds fit short field labels.
10. The copy has one clear next action.
