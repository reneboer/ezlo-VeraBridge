--[[
	event_handler.lua. handles core events we subscribed to.
--]]
local storage = require("storage")
local PLUGIN = storage.get_string("PLUGIN")
local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/set_item_value").setLevel(storage.get_number("log_level") or 99)

local function string_parameters(str, ...)
	local args = {...}
	str = string.gsub(str, "%%(%d+)", function(n)
			n = tonumber(n, 10)
			if n < 1 or n > #args then return "nil" end
			return tostring(args[n])
		end
	)
	return str
end

local function handle_core_event(params)
	local http = require("http")
	-- Check if we have an armed event.
	if params.armed ~= nil then
		local vera = storage.get_table("VB_D_"..params._id)
		local cnfg = nil
		if vera then
			cnfg = storage.get_table("VB_DC_"..vera.name..math.floor(vera.device_id))
		end
		if cnfg then
			logger.debug("Found device =%1", cnfg)
			local veraURI = "/data_request?id=lu_action&DeviceNum=%1&serviceId=urn:micasaverde-com:serviceId:SecuritySensor1&action=SetArmed&newArmedValue=%2"
			veraURI = string_parameters(veraURI, math.floor(vera.device_id), params.armed and 1 or 0)
			local config = storage.get_table("VB_config_"..vera.name)
			if config.type == "Vera" then
				veraURI = "http://" .. config.ip .. "/port_3480" .. veraURI
			elseif config.type == "openLuup" then
				veraURI = "http://" .. config.ip .. ":3480" .. veraURI
			else
				logger.err("Unsupported hub type %1. Expect Vera or openLuup.", config.type)
				return
			end	
			logger.debug("Vera %1 Action URL: %2", vera.name, veraURI)
			http.request { url = veraURI, handler = "HUB:"..PLUGIN.."/scripts/action_handler", user_data = vera.name }
		else
			logger.debug("Unsupported device %1 for armed event",params._id)
		end
	else
		logger.debug("Unsupported event %1",params)
	end
end

handle_core_event(...)
