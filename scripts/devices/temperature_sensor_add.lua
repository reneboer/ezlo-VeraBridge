-- Create a temperature sensor device
local function power_meter_add(gw, name, room, remote_id)
	local storage = require("storage")
	local core = require("core")
	local PLUGIN = storage.get_string("PLUGIN")
	local cnfg = {}
	local room_id = room	-- Until we have room functions in FW
--	if room and room ~= "" then
--		room_id = loadfile("HUB:"..PLUGIN.."/scripts/utils/get_config")().get(room)
--	end
	
	local newdev,err = core.add_device{
			gateway_id = gw,
			type = "sensor",
			device_type_id = "VeraBridge_temperature_sensor",
			name = name,
			room_id = room_id,
			category = "temperature",
			subcategory = "",
			battery_powered = false,
			info = {manufacturer = "Rene Boer", model = "VeraBridge Temperature Sensor", remote_id = remote_id}
		}
	if newdev then
		local add_item = loadfile("HUB:"..PLUGIN.."/scripts/devices/add_item")
		local err
		cnfg.deviceId = newdev
		-- Add the items.
		cnfg.temp_itemId, err = add_item(newdev, "temp")
		return cnfg
	else
		return nil,err
	end
end
return power_meter_add(...)