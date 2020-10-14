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
		local newVal = nil
		local veraURI
		if item_id == cnfg.dimmer_id then
			veraURI = "/data_request?id=lu_action&DeviceNum=%1&serviceId=urn:upnp-org:serviceId:Dimming1&action=SetLoadLevelTarget&newLoadlevelTarget=%2"
			if type(value) == "boolean" then newVal = value and 100 or 0 end
		elseif item_id == cnfg.switch_id then
			if type(value) == "boolean" then newVal = value and 1 or 0 end
			veraURI = "/data_request?id=lu_action&DeviceNum=%1&serviceId=urn:upnp-org:serviceId:SwitchPower1&action=SetTarget&newTargetValue=%2"
		elseif item_id == cnfg.rbgcolor_id then
			newVal = math.floor(value.red)..","..math.floor(value.green)..","..math.floor(value.blue)
			veraURI = "/data_request?id=lu_action&DeviceNum=%1&serviceId=urn:micasaverde-com:serviceId:Color1&action=SetColorRGB&newColorRGBTarget=%2"
		elseif cnfg.behaviour == "window_cov" then
			veraURI = "/data_request?id=lu_action&DeviceNum=%1&serviceId=urn:upnp-org:serviceId:WindowCovering1&action=%2"
			if item_id == cnfg.dimmer_up_id then
				newVal = "Up"
			elseif item_id == cnfg.dimmer_down_id then
				newVal = "Down"
			elseif item_id == cnfg.dimmer_stop_id then
				newVal = "Stop"
			end
		else	
			logger.err("unsupported behavior %1 for lu_action", cnfg.behavior)
			return
		end
		if not newVal then newVal = math.floor(value) end
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
