# ezlo-VeraBridge
Bridge selected devices from your Vera to Ezlo Plus on the same local network.

The following devices are currently supported:
dw_sensor, motion_sensor, co_sensor, co2_sensor, glass_sensor, leak_sensor, light_sensor, humidity_sensor, temperature_sensor, uv_sensor, dimmer, switch, power_meter

Note: The Ezlo hub must have FW 1.5 or later to poll multiple Veras reliably.

### Installation.
To install first create a folder VeraBridge in the /home/data/custom_plugins folder. Make sure VeraBridge is spelled exact with the same letter casing (upper V, upper B).
Next put all files in that folder, except this README and LICENSE. You must use the same folder structure. I.e. scripts, scripts/utils.

### Configuration
As there is no programmable UI (yet) for the Ezlo hubs the configuration is done in VeraBridge.json. It is the only file you need to edit.

Specify the log_level: 1 critical and error messages only, 2 also warning messages, 3 also notice messages, 4 also info messages, 5 also debug messages.

Specify the Vera(s) (or openLuup) and devices to bridge to your Ezlo Plus in the veras array.
* name: a unique name for the bridged device, no spaces, no special characters.
* type: Vera or openLuup (mind the letter casing)
* ip: the ip address of the vera or openLuup
* devices: array of the devices to bridge.
  * behavior: the type of device to bridge. Must be one of the supported devices listed above.
  * device_id: the vera device ID
  * name: the name to use for the device on the Ezlo Hub
  * room_id: the Ezlo room ID to put the devie in.
  * battery_powerd: if true a battery indication is included.

### Starting the plugin
The plugin is started with the following command (enter on hub)
> /opt/firmware/bin/ha-infocmd hub.extensions.custom_plugin.register VeraBridge

### Stopping the plugin
The plugin is stopped with the following command (enter on hub)
> /opt/firmware/bin/ha-infocmd hub.extensions.custom_plugin.unregister VeraBridge

### Uninstalling the plugin
For full reset of plugin so we can start over. All mapped devices will be removed.
1. First unregister then plugin and wait at least ten seconds.
2. Call from the Ezlo API Tool using 
{
 "method": "extensions.plugin.run",
 "id": "12345",
 "params": { "script": "HUB:VeraBridge/scripts/reset_plugin" }
}
Last run the uninstall on the hub.
> /opt/firmware/bin/ha-infocmd hub.extensions.custom_plugin.uninstall VeraBridge

If you want to start over you can use the same steps, update the VeraBridge.json and restart the plugin.

### The Makefile
If you have a Linux system at hand (like a Pi) you can also first put the files on that. The included Makefile can be used for the steps above:
- First set the IP address of your Hub in the Makefile
- make mkdir, will create the correct target folder
- make all, will stop the plugin, copy all files, start the plugin. Useful for making code changes.
- make copy, will copy all files. A restart of the plugin is only needed if the startup.lua or VeraBridge.json are changed. All other scripts are event driven and loaded again as events occur.
