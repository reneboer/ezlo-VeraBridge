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
When you want to uninstall the plugin you must first delete all device in the App. Currently the uninstall command does not remove the devices a plugin created, and after you uninstalled the plugin you cannot delete a device. This is a known bug that should be fixed.
After deleting the devices with the following command (enter on hub)
> /opt/firmware/bin/ha-infocmd hub.extensions.custom_plugin.uninstall VeraBridge

Next remove the plugin files else the plugin will reactivate at a reboot. You can also rename the config.json so starting the plugin will fail.

### The Makefile
If you have a Linux system at hand (like a Pi) you can also first put the files on that. The included Makefile can be used for the steps above:
- First set the IP address of your Hub in the Makefile
- make mkdir, will create the correct target folder
- make all, will stop the plugin, copy all files, start the plugin. Useful for making code changes.
- make copy, will copy all files. A restart of the plugin is only needed if the startup.lua or VeraBridge.json are changed. All other scripts are event driven and loaded again as events occur.
