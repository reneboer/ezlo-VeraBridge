--[[
	set_item_value.lua
	Handle "setter" events for items. 
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

local function vb_set_item(item_id, value)
	local core = require("core")
	local http = require("http")
	local item = core.get_item(item_id)
	local curVal = item.value
	if type(curVal) == "table" then
		if curVal.value == value.value then
			curVal = nil
		end
	else
		if curVal == value then
			curVal = nil
		end
	end
	core.update_item_value(item_id, value or false)
	if curVal == nil then
		logger.debug("Items current value %1 is same as new value %2.", item.value, value)
		return
	end
	local vera = storage.get_table("VB_D_"..item.device_id)
	local cnfg = nil
	if vera then
		cnfg = storage.get_table("VB_DC_"..vera.name..math.floor(vera.device_id))
	end
	if cnfg then
		-- We have a mapped Vera device for the item
		logger.debug("Found device =%1", cnfg)
		local newVal = value
		local veraURI
		if cnfg.behavior == "dimmer" then
			veraURI = "/data_request?id=lu_action&DeviceNum=%1&serviceId=urn:upnp-org:serviceId:Dimming1&action=SetLoadLevelTarget&newLoadlevelTarget=%2"
		elseif cnfg.behavior == "switch" then
			veraURI = "/data_request?id=lu_action&DeviceNum=%1&serviceId=urn:upnp-org:serviceId:SwitchPower1&action=SetTarget&newTargetValue=%2"
		else
			logger.err("unsupported behavior %1 for lu_action", cnfg.behavior)
			return
		end
		-- For Dimmer device, we may get a switch command. Convert true/false to load level
		if cnfg.behavior == "dimmer" and type(newVal) == "boolean" then
			newVal = newVal and 100 or 0
		end
		local config = storage.get_table("VB_config_"..vera.name)
		veraURI = string_parameters(veraURI, math.floor(vera.device_id), newVal)
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
		logger.debug("Item %1 for device %2 is not mapped to a Vera device", item_id, item.deviceId)
	end
end

local function vb_set_items(params)
	-- See if we have one item, or multiple items to update
	logger.debug("params=%1", params)
	if params.operation_id then
		logger.debug("ignoring this")
	elseif params.item_ids then
		for _, item in pairs(params.item_ids) do
			vb_set_item(item, params.value)
		end
	elseif params.item_id then
		vb_set_item(params.item_id, params.value)
	else
		-- Not something for us to handle?
	end
end

vb_set_items(...)
