-- SolarMeter delete device.
local function delete_device(params)
	local storage = require("storage")
	local PLUGIN = storage.get_string("PLUGIN")
	local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/delete_device").setLevel(storage.get_number("log_level") or 99)
	
	local timer = require("timer")
	local core = require("core")

	logger.debug("params %1", params)
	-- See if we know the device
	local device_id = params.deviceId
	if device_id then
		logger.info("Deleting device %1.", device_id)
		local vera = storage.get_table("VB_D_"..device_id)
		if vera then
			storage.delete("VB_DC_"..vera.name..math.floor(vera.device_id))
		end
		storage.delete("VB_D_"..device_id)
		core.remove_device(device_id)
	else
		logger.warn("No device in parameter")
	end
end

delete_device(...)

