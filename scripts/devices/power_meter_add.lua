-- Create an power meter device
local function power_meter_add(gw, name, room, remote_id)
	local storage = require("storage")
	local core = require("core")
	local PLUGIN = storage.get_string("PLUGIN")
	local meters = meters or false
	local cnfg = {}
	local room_id = room	-- Until we have room functions in FW
--	if room and room ~= "" then
--		room_id = loadfile("HUB:"..PLUGIN.."/scripts/utils/get_config")().get(room)
--	end
	
	local newdev,err = core.add_device{
			gateway_id = gw,
			type = "meter.power",
			device_type_id = "VeraBridge_switch",
			name = name,
			room_id = room_id,
			category = "power_meter",
			subcategory = "",
			battery_powered = false,
			info = {manufacturer = "Rene Boer", model = "VeraBridge Power Meter", remote_id = remote_id}
		}
	if newdev then
		local add_item = loadfile("HUB:"..PLUGIN.."/scripts/devices/add_item")
		local err
		cnfg.deviceId = newdev
		-- Add the usage meter items.
		cnfg.watt_itemId, err = add_item(newdev, "electric_meter_watt")
		cnfg.kwh_itemId, err = add_item(newdev, "electric_meter_kwh")
		cnfg.amps_itemId, err = add_item(newdev, "electric_meter_amper")
		cnfg.volt_itemId, err = add_item(newdev, "electric_meter_volt")
		return cnfg
	else
		return nil,err
	end
end
return power_meter_add(...)