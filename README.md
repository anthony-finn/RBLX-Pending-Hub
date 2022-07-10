
# Roblox-Pending-Hub

This turns any Roblox server/place into a pending hub where specific roles in a group are allowed to enter a place while others must waiting in a "pending" server. A notification is sent to the "main server" with basic information about the player requesting to join. Players who have permissions/administrator access are allowed to either allow or disallow these players from being placed in the main server.

## History

The creation of this was to solve the problem of denial of service attacks (DDoS) on Roblox servers in 2020-2021. During organized events, malicious users would join servers and DDoS the server so the game would not be playable. These attackers could easily get the server IP address by looking in their roblox logs.

By introducing a "pending hub," the attackers are not able to access the main game server and the server IP address.
## Releases
The model has over 700 (July 2022) takes with many Roblox groups using the script. There are two versions available for use.

**You can take the updated version [here](https://www.roblox.com/library/9987375002/Pending-Hub-2022) for yourself. The entire source code can be found [here](https://www.roblox.com/library/8963844966/PendingHubModule).**

[Old Version (2020)](https://www.roblox.com/library/5966042837/Pending-Hub)
## Installation

You can install this by inserting a server script into your game. The model will be automatically updated with the latest bug fixes and features.

```lua
_G.PENDING_HUB_SETTINGS = require(script:WaitForChild("Settings"))
require(script:FindFirstChild("MainModule") or 8963844966)()
```

Create a ModuleScript and parent it to the above script. Paste the code from [here](https://github.com/anthony-finn/Roblox-Pending-Hub/blob/main/Settings.lua) into the newly created script. Rename the script to "Settings".
## Acknowledgements
External modules used:
 - [Timezone Service - Eezby](https://github.com/Eezby/Roblox-TimeZoneService)
## Screenshots
Pending Server:

![App Screenshot](https://cdn.discordapp.com/attachments/995548321592660079/995739010079146004/unknown.png)

Main/Game Server:

![App Screenshot](https://cdn.discordapp.com/attachments/995548321592660079/995739303978221689/unknown.png)

