--[[
Handle http events for Bridged Vera to handle http get response for lu_status2 from poll.lua
--]]
local storage = require("storage")
local core = require("core")
local http = require("http")
local timer = require("timer")
local PLUGIN = storage.get_string("PLUGIN")
local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/update").setLevel(storage.get_number("log_level") or 99)

-- Map Vera services and variables to Ezlo items.
-- Keep in sync with DeviceMap in startup.lua
local ItemMapping = {
	["urn:micasaverde-com:serviceId:HaDevice1"] = {
		["BatteryLevel"] = { itemId = "battery", val_conv = function(val) return val end  }
	},
	["urn:upnp-org:serviceId:SwitchPower1"] = {
		["Status"] = { itemId = "switch", val_conv = function(val) return val ~= 0 end  }
	},
	["urn:upnp-org:serviceId:Dimming1"] = {
		["LoadLevelStatus"] = { itemId = "dimmer", val_conv = function(val) return val end }
	},
	["urn:upnp-org:serviceId:TemperatureSensor1"] = {
		["CurrentTemperature"] = { itemId = "temp", val_conv = function(val) return {value = val, scale = "celsius"} end }
	},
	["urn:micasaverde-com:serviceId:SecuritySensor1"] = {
		["Tripped"] = { itemIds = {
			{ itemId = "motion", val_conv = function(val) return val ~= 0 end },
			{ itemId = "dw_state", val_conv = function(val) return val == 0 and "dw_is_closed" or "dw_is_opened" end },
			{ itemId = "water_leak_alarm", val_conv = function(val) return val == 0 and "no_water_leak" or "water_leak_detected" end },
			{ itemId = "co_alarm", val_conv = function(val) return val == 0 and "no_co" or "co_detected" end },
			{ itemId = "co2_alarm", val_conv = function(val) return val == 0 and "no_co2" or "co2_detected" end },
			{ itemId = "smoke_alarm", val_conv = function(val) return val == 0 and "no_smoke" or "smoke_detected" end },
			{ itemId = "glass_breakage_alarm", val_conv = function(val) return val == 0 and "no_glass_breakage" or "glass_breakage" end },
			{ itemId = "gas_alarm", val_conv = function(val) return val == 0 and "no_gas" or "combustible_gas_detected" end }
		}}
	},
	["urn:micasaverde-com:serviceId:HumiditySensor1"] = {
		["CurrentLevel"] = { itemId = "humidity", val_conv = function(val) return {value = val, scale = "percent"} end }
	},
	["urn:micasaverde-com:serviceId:LightSensor1"] = {
		["CurrentLevel"] = { itemId = "illuminance", val_conv = function(val) return {value = val, scale = "percent"} end }
	},
	["urn:micasaverde-com:serviceId:LightSensor1"] = {
		["CurrentLevel"] = { itemIds = {
			{ itemId = "illuminance", val_conv = function(val) return {value = val, scale = "percent"} end },
			{ itemId = "ultraviolet", val_conv = function(val) return {value = val, scale = "uv_index"} end }
		}}
	},
	["urn:micasaverde-com:serviceId:EnergyMetering1"] = {
		["Watts"] = { itemId = "electric_meter_watt", val_conv = function(val) return {value = val, scale = "watt"} end },
		["KWH"] = { itemId = "electric_meter_kwh", val_conv = function(val) return {value = val, scale = "kilo_watt_hour"} end },
		["Volts"] = { itemId = "electric_meter_volt", val_conv = function(val) return {value = val, scale = "volt"} end },
		["Amps"] = { itemId = "electric_meter_amper", val_conv = function(val) return {value = val, scale = "ampere"} end }
	}	
}

-- look for bridged devices, and see if anything has changed
local function update_bridged_devices(name, vera)
	
	-- Find device in vera config
	vera.devices = vera.devices or {}
	for _,vd in ipairs(vera.devices) do
		local id = math.floor(vd.id)
		local cnfg = storage.get_table("VB_DC_"..name..id)
		if cnfg then
			logger.debug("Found %1 device %2 for Ezlo device %3", name, id, cnfg.deviceId)
			-- Now loop over states to see what to update.
			vd.states = vd.states or {}
			for _,vs in ipairs(vd.states) do
				if ItemMapping[vs.service] then
					local vera_var = ItemMapping[vs.service][vs.variable]
					if vera_var then
						if vera_var.itemIds then
							-- Can map to multiple Ezlo types
							for _, item in pairs(vera_var.itemIds) do
								local ezlo_id = cnfg[item.itemId.."_id"]
								if ezlo_id then
									local val = tonumber(vs.value)
									logger.debug("To update Ezlo item %1, value %2", ezlo_id, val)
									core.update_item_value(ezlo_id, item.val_conv(val))
								end
							end
						else
							-- Single mapping
							local ezlo_id = cnfg[vera_var.itemId.."_id"]
							if ezlo_id then
								local val = tonumber(vs.value)
								logger.debug("To update Ezlo item %1, value %2", ezlo_id, val)
								core.update_item_value(ezlo_id, vera_var.val_conv(val))
							end
						end
					else
						-- Not a variable we map
					end
				else
					-- Not a service we map
				end
			end
		else
			-- Device not bridged
		end
	end
end

local function vb_http_event(event)
	local ed = event.data
	local vera_name = ed.user_data
	local dv = storage.get_string("VB_DV_"..vera_name) or "0"
	if dv == "-1" then
		logger.info("Instructed %1 to stop polling.", vera_name)
		return
	end
	if event.event == "http_data_send" then
		logger.info("I have nothing to send??")
	elseif event.event == "http_data_received" then
		if ed.code == 200 then
			local json = require("HUB:"..PLUGIN.."/scripts/utils/dkjson")
			local js_resp = json.decode(ed.data)
			if type(js_resp) == "table" then
				logger.debug("Received %1 DataVersion %2", vera_name, js_resp.DataVersion or "0")
				storage.set_string("VB_DV_"..vera_name, js_resp.DataVersion or "0")
				update_bridged_devices(vera_name, js_resp)
			else
				logger.warn("Unexpected body data type received from %1: %4", vera_name, type(js_resp))
			end
		else
			logger.err("We got data, but not what we expected :-). HTTP return code %1", ed.code)
		end
	elseif event.event == "http_connection_closed" then
		if ed.reason.code ~= 0 then
--			logger.debug("http event %1", event)
			logger.info("Connection to %1 closed. Reason %2", vera_name, ed.reason)
		end
		-- Start new timer for next poll
		local timer_id = "VB_TimerId_" .. vera_name
		if timer.exists(timer_id) then
			-- Avoid multiple timers for single Vera. Can happen when there are timeouts.
			logger.warn("Timer for Vera %1 is already in progress.", vera_name)
		else
			local timer_sec = 10
			logger.debug("Setting timer for %1 to poll in %2 sec.", vera_name, timer_sec)
			timer.set_timeout_with_id(timer_sec * 1000, timer_id, "HUB:"..PLUGIN.."/scripts/poll", {name = vera_name})
		end
	else
		logger.err("unexpected event type %1", event.event)
	end
end

vb_http_event(...)
