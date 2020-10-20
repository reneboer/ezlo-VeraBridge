--[[
	set_item_value.lua
	Handle "setter" events for items. 
--]]
local storage = require("storage")
local PLUGIN = storage.get_string("PLUGIN")
local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/set_item_value").setLevel(storage.get_number("log_level") or 99)

-- Map item names (type) to Vera URL
local ItemMapping = {
	dimmer = function(value)
				if type(value) == "number" then
					return "urn:upnp-org:serviceId:Dimming1&action=SetLoadLevelTarget&newLoadlevelTarget="..math.floor(value)
				else
					return nil
				end
			end,
	switch = function(value) 
				if type(value) == "boolean" then 
					tv = value and "1" or "0"
					return "urn:upnp-org:serviceId:SwitchPower1&action=SetTarget&newTargetValue="..tv
				else
					return nil
				end
			end,
	siren_alarm = function(value)
				local tv = value == "siren_active" and "1" or "0"
				return "urn:upnp-org:serviceId:SwitchPower1&action=SetTarget&newTargetValue="..tv
			end,
	rgbcolor = function(value)
				local tv = math.floor(value.red)..","..math.floor(value.green)..","..math.floor(value.blue)
				return "urn:micasaverde-com:serviceId:Color1&action=SetColorRGB&newColorRGBTarget="..tv
			end,
	dimmer_up = function(value) return "urn:upnp-org:serviceId:WindowCovering1&action=Up" end,
	dimmer_down = function(value) return "urn:upnp-org:serviceId:WindowCovering1&action=Down" end,
	dimmer_stop = function(value) return "urn:upnp-org:serviceId:WindowCovering1&action=Stop" end
}

local function vb_set_item(item_id, value)
	local core = require("core")
	local http = require("http")

	-- Update local device item
	local item = core.get_item(item_id)
	core.update_item_value(item_id, value or false)
	
	-- Is this a item type we could send to a Vera
	local veraURI = ItemMapping[item.name](value)
	if veraURI then
		-- See if item is mapped to Vera bridged device
		local vera = storage.get_table("VB_D_"..item.device_id)
		local cnfg = nil
		if vera then
			cnfg = storage.get_table("VB_DC_"..vera.name..math.floor(vera.device_id))
		end
		if cnfg then
			-- We have a mapped Vera device for the item
			logger.debug("Found mapped Vera device: %1", cnfg)
			local config = storage.get_table("VB_config_"..vera.name)
			local vt = string.upper(config.type)
			veraURI = "/data_request?id=lu_action&DeviceNum=" .. math.floor(vera.device_id) .. "&serviceId=" .. veraURI
			if vt == "VERA" then
				veraURI = "http://" .. config.ip .. "/port_3480" .. veraURI
			elseif vt == "OPENLUUP" then
				veraURI = "http://" .. config.ip .. ":3480" .. veraURI
			else
				logger.err("Unsupported hub type %1. Expect Vera or openLuup.", config.type)
				return
			end
			-- Send command to Vera
			logger.debug("Vera %1 Action URL: %2", vera.name, veraURI)
			http.request { url = veraURI, handler = "HUB:"..PLUGIN.."/scripts/action_handler", user_data = vera.name }
		else	
			logger.debug("Item %1 for device %2 is not mapped to a Vera device", item_id, item.deviceId)
		end
	else
		logger.err("unsupported item type %1 for lu_action", item.name)
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
