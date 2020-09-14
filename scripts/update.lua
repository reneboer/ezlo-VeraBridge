--[[

Handle http events for Bridged Vera to handle http get response for lu_status2 from poll.lua

--]]
local storage = require("storage")
local PLUGIN = storage.get_string("PLUGIN")
local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/update").setLevel(storage.get_number("log_level") or 99)

-- look for bridged devices, and see if anything has changed
local function update_bridged_devices(name, vera)
	local core = require "core"
	
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
				if vs.service == "urn:upnp-org:serviceId:SwitchPower1" then
					if vs.variable == "Status" then
						if cnfg.switch_itemId then
							local val = tonumber(vs.value)
							logger.debug("To update Ezlo switch item %1, value %2", cnfg.switch_itemId, val)
							core.update_item_value(cnfg.switch_itemId, val ~= 0)
						end
					end
				elseif vs.service == "urn:upnp-org:serviceId:Dimming1" then
					if vs.variable == "LoadLevelStatus" then
						if cnfg.dimmer_itemId then
							local val = tonumber(vs.value)
							logger.debug("To update Ezlo dimmer item %1, value %2", cnfg.dimmer_itemId, val)
							core.update_item_value(cnfg.dimmer_itemId, val)
						end
					end
				elseif vs.service == "urn:upnp-org:serviceId:TemperatureSensor1" then
					if vs.variable == "CurrentTemperature" then
						if cnfg.temp_itemId then
							local val = tonumber(vs.value)
							logger.debug("To update Ezlo temperature sensor item %1, value %2", cnfg.temp_itemId, val)
							core.update_item_value(cnfg.temp_itemId,  {value = val, scale = "celsius"})
						end
					end
				elseif vs.service == "urn:micasaverde-com:serviceId:EnergyMetering1" then
					if vs.variable == "Watts"  then
						if cnfg.watt_itemId then
							local val = tonumber(vs.value)
							logger.debug("To update Ezlo electric_meter_watt item %1, value %2", cnfg.watt_itemId, val)
							core.update_item_value(cnfg.watt_itemId, {value = val, scale = "watt"})
						end
					elseif vs.variable == "KWH"  then
						if cnfg.kwh_itemId then
							local val = tonumber(vs.value)
							logger.debug("To update Ezlo electric_meter_kwh item %1, value %2", cnfg.kwh_itemId, val)
							core.update_item_value(cnfg.kwh_itemId, {value = val, scale = "kilo_watt_hour"})
						end
					elseif vs.variable == "Volts" then
						if cnfg.volt_itemId then
							local val = tonumber(vs.value)
							logger.debug("To update Ezlo electric_meter_volt item %1, value %2", cnfg.volt_itemId, val)
							core.update_item_value(cnfg.volt_itemId, {value = val, scale = "volt"})
						end
					elseif vs.variable == "Amps" then
						if cnfg.amps_itemId then
							local val = tonumber(vs.value)
							logger.debug("To update Ezlo electric_meter_amper item %1, value %2", cnfg.amps_itemId, val)
							core.update_item_value(cnfg.amps_itemId, {value = val, scale = "ampere"})
						end
					end
				end
			end
		else
			-- Device not bridged
		end
	end
end

local function vb_http_event(event)
	local http = require "http"
	local timer = require "timer"
	
	local ed = event.data
	local vera_name = ed.user_data
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
			logger.info("connection closed. Reason %1", ed.reason)
		end
		-- Start new timer for next poll
		logger.debug("Setting timer to poll in %1 sec.", 10)
		timer.set_timeout(10000, "HUB:"..PLUGIN.."/scripts/poll", {name = vera_name})
	else
		logger.err("unexpected event type %1", event.event)
	end
end

vb_http_event(...)
