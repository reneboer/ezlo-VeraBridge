--[[ 
For full reset of plugin so we can start over. All mapped devices will be removed.

1. First unregister then plugin and wait at least ten seconds.
2. Call from the Ezlo API Tool using 
{
 "method": "extensions.plugin.run",
 "id": "12345",
 "params": { "script": "HUB:VeraBridge/scripts/reset_plugin" }
}
3. register the plugin again.
]]--
local storage = require("storage")
local core = require("core")
local PLUGIN = storage.get_string("PLUGIN")
local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/reset_plugin").setLevel(storage.get_number("log_level") or 99)

-- See if polling has stopped.
local veras = storage.get_table("VB_veras")
local can_delete = true
for _,vera in pairs(veras) do
	if storage.get_string("VB_DV_"..vera) ~= "-1" then can_delete = false end
end
if can_delete then
	logger.info("Dropping all data and devices for %1 plugin.", PLUGIN)
	core.remove_gateway_devices(core.get_gateway().id)
	storage.delete_all()
	core.send_ui_broadcast({ data = "Plug-in "..PLUGIN.." reset. Register for restart." })
else
	logger.warn("Plug-in %1 has not been unregisterd. Unregister before resetting plugin.", PLUGIN)
	core.send_ui_broadcast({ data = "Plug-in "..PLUGIN.." has not been unregisterd. Unregister before resetting plugin."})
end
