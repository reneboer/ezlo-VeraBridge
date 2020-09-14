-- Create a motion sensor device
local function switch_add(gw, name, room, remote_id)
	local storage = require("storage")
	local core = require("core")
	local PLUGIN = storage.get_string("PLUGIN")
	local cnfg = {}
	local room_id = room
--	if room and room ~= "" then
--		room_id = loadfile("HUB:"..PLUGIN.."/scripts/utils/get_config")().get(room)
--	end
	
	local newdev,err = core.add_device{
			gateway_id = gw,
			type = "sensor",
			device_type_id = "VeraBridge_security_sensor",
			name = name,
			room_id = room_id,
			category = "security_sensor",
			subcategory = "motion",
			battery_powered = false,
			info = {manufacturer = "Rene Boer", model = "VeraBridge Motion Sensor", remote_id = remote_id}
		}
	if newdev then
		local add_item = loadfile("HUB:"..PLUGIN.."/scripts/devices/add_item")
		local err
		cnfg.deviceId = newdev
		cnfg.switch_itemId, err = add_item(newdev, "motion")
		return cnfg
	else
		return nil,err
	end
end
return switch_add(...)