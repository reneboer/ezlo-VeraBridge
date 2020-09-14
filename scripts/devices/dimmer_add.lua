-- Create an dimmer device
local function dimmer_add(gw, name, room, remote_id, meters)
	local storage = require("storage")
	local core = require("core")
	local PLUGIN = storage.get_string("PLUGIN")
	local meters = meters or false
	local cnfg = {}
	local room_id = room
--	if room and room ~= "" then
--		room_id = loadfile("HUB:"..PLUGIN.."/scripts/utils/get_config")().get(room)
--	end
	
	local newdev,err = core.add_device{
			gateway_id = gw,
			type = "dimmer.outlet",
			device_type_id = "VeraBridge_dimmer",
			name = name,
			room_id = room_id,
			category = "dimmable_light",
			subcategory = "dimmable_plugged",
			battery_powered = false,
			info = {manufacturer = "Rene Boer", model = "VeraBridge Dimmer", remote_id = remote_id}
		}
	if newdev then
		local add_item = loadfile("HUB:"..PLUGIN.."/scripts/devices/add_item")
		local err
		cnfg.deviceId = newdev
		cnfg.switch_itemId, err = add_item(newdev, "switch")
		cnfg.dimmer_itemId, err = add_item(newdev, "dimmer")
		add_item(newdev, "dimmer_up")
		add_item(newdev, "dimmer_down")
		add_item(newdev, "dimmer_stop")
		if meters then
			-- Add the usage meter items.
			cnfg.watt_itemId, err = add_item(newdev, "electric_meter_watt")
			cnfg.kwh_itemId, err = add_item(newdev, "electric_meter_kwh")
		end	
		return cnfg
	else
		return nil,err
	end
end

return dimmer_add(...)