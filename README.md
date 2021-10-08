# OBS Websocket GD
A Godot addon to interact with obs-websocket. Tested on Godot 3.4.

## Editor Plugin Quickstart
1. Install [obs-websocket](https://github.com/Palakis/obs-websocket) for your platform
2. Configure obs-websocket in OBS and set the password to something of your choosing
3. Clone this project and move the `addons/obs_websocket_gd` folder to your `addons` folder
4. By default, the addon tries to connect to `localhost:4444` with a password of `password`. Change the password in `addons/obs_websocket_gd/obs_websocket.gd` to the password set in step 2
5. Activate the addon in the Godot editor
6. A new `OBS` menu should appear in the bottom bar of the editor

## Game/App Quickstart
1. Install [obs-websocket](https://github.com/Palakis/obs-websocket) for your platform
2. Configure obs-websocket in OBS and set the password to something of your choosing
3. Clone this project
4. Instance in the `addons/obs_websocket_gd/obs_websocket.tscn` file somewhere in your project
5. By default, the addon tries to connect to `localhost:4444` with a password of `password`. Change the password in `addons/obs_websocket_gd/obs_websocket.gd` to the password set in step 2. The variables are exported for convenience
6. (OPTIONAL) Connect some listener to the `obs_updated(update_data)` signal in `obs_websocket.gd`. `obs_updated` outputs a Dictioanry
7. Call the `send_command(command: String, data: Dictionary = {})` method on the `obs_websocket.gd` instance. Reference the [obs-websocket protocol](https://github.com/Palakis/obs-websocket/blob/4.x-current/docs/generated/protocol.md#requests) to find out what commands + data to send

## Discussion
A Discord server [is available here](https://discord.gg/6mcdWWBkrr) if you need help, like to contribute, or just want to chat.

