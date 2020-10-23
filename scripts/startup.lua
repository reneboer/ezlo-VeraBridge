--[[
	Vera device Bridge plugin for Ezo Linux based hubs
	
	File	: startup.lua
	Version	: 1.4
	Author	: Rene Boer
--]]
local PLUGIN = "VeraBridge"
local storage = require("storage")
local core = require("core")
local timer = require("timer")
local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/startup").setLevel(storage.get_number("log_level") or 99)

local temp_units = "celsius"

-- Map behavior to device specifics.
-- Keep in sync with ItemMapping table in update.lua
local DeviceMap = {
	["dimmer"] = { 
		type = "dimmer.outlet", 
		category = "dimmable_light", 
		subcategory = "dimmable_plugged",
		items = { "switch", "dimmer", "dimmer_up", "dimmer_down", "dimmer_stop", "electric_meter_watt", "electric_meter_kwh" }
	},	
	["dimmer_rgb"] = { 
		type = "light.bulb", 
		category = "dimmable_light", 
		subcategory = "dimmable_colored",
		items = { "switch", "rgbcolor", "dimmer", "dimmer_up", "dimmer_down", "dimmer_stop", "electric_meter_watt", "electric_meter_kwh" }
	},	
	["switch"] = {
		type = "switch.outlet", 
		category = "switch", 
		subcategory = "interior_plugin",
		items = { "switch", "electric_meter_watt", "electric_meter_kwh" }
	},	
	["window_cov"] = {
		type = "shutter.roller", 
		category = "window_cov", 
		subcategory = "window_cov",
		items = { "dimmer", "dimmer_up", "dimmer_down", "dimmer_stop", "switch", "goto_favorite", "shutter_state", "shutter_command" }
	},	
	["heater"] = {
-- Not yet working as expected
		type = "thermostat", 
		category = "hvac", 
		subcategory = "hvac",
		items = { "temp", "thermostat_setpoint", "thermostat_setpoint_heating", "thermostat_operating_state", "thermostat_mode" }
	},	
	["hvac"] = {
		type = "thermostat", 
		category = "hvac", 
		subcategory = "hvac",
		items = { "temp", "thermostat_setpoint", "thermostat_setpoint_heating", "thermostat_setpoint_cooling", "thermostat_operating_state", "thermostat_mode", "thermostat_fan_mode", "thermostat_fan_state" }
	},	
	["power_meter"] = { 
		type = "meter.power", 
		category = "power_meter", 
		subcategory = "",
		items = { "electric_meter_watt", "electric_meter_kwh", "electric_meter_amper", "electric_meter_volt" }
	},	
	["co_sensor"] = { 
		type = "sensor", 
		category = "security_sensor", 
		subcategory = "co",
		items = { "co_alarm" }
	},	
	["co2_sensor"] = { 
		type = "sensor", 
		category = "security_sensor", 
		subcategory = "co2",
		items = { "co2_alarm" }
	},	
	["dw_sensor"] = { 
		type = "sensor", 
		category = "security_sensor", 
		subcategory = "door",
		items = { "dw_state" }
	},	
	["gas_sensor"] = { 
		type = "sensor", 
		category = "security_sensor", 
		subcategory = "gas",
		items = { "gas_alarm" }
	},	
	["glass_sensor"] = { 
		type = "sensor", 
		category = "security_sensor", 
		subcategory = "glass",
		items = { "glass_breakage_alarm" }
	},	
	["humidity_sensor"] = { 
		type = "sensor", 
		category = "humidity", 
		subcategory = "",
		items = { "humidity" }
	},	
	["leak_sensor"] = { 
		type = "sensor", 
		category = "security_sensor", 
		subcategory = "leak",
		items = { "water_leak_alarm" }
	},	
	["light_sensor"] = { 
		type = "sensor", 
		category = "light_sensor", 
		subcategory = "",
		items = { "lux" }
	},	
	["motion_sensor"] = { 
		type = "sensor", 
		category = "security_sensor", 
		subcategory = "motion",
		items = { "motion" }
	},	
	["smoke_sensor"] = { 
		type = "sensor", 
		category = "security_sensor", 
		subcategory = "smoke",
		items = { "smoke_alarm" }
	},	
	["siren"] = { 
		type = "sensor", 
		category = "siren", 
		subcategory = "",
		items = { "switch", "siren_alarm" }
	},	
	["temperature_sensor"] = { 
		type = "sensor", 
		category = "temperature", 
		subcategory = "",
		items = { "temp" }
	},	
	["uv_sensor"] = { 
		type = "sensor", 
		category = "uv_sensor", 
		subcategory = "",
		items = { "ultraviolet" }
	}
}

-- Define item details
-- Should match firmware\plugins\zwave\scripts\model\items\default as much as possible.
local ItemDetails = {
	battery = { 
		value_type = "int", 
		value = 100, 
		has_getter = true, 
		has_setter = false
	}, 
	switch = {
		value_type = "bool", 
		value = false, 
		has_getter = true, 
		has_setter = true
	}, 
	dimmer = {
		value_type = "int", 
		has_getter = true, 
		has_setter = true, 
		value = 0, 
		value_min = 0, 
		value_max = 100
	}, 
	dimmer_up = { 
		value_type = "int", 
		value = 0, 
		has_getter = false, 
		has_setter = true
	},
	dimmer_down = {
		value_type = "int", 
		value = 0, 
		has_getter = false, 
		has_setter = true
	},
	dimmer_stop = { 
		value_type = "int", 
		value = 0, 
		has_getter = false, 
		has_setter = true
	},
	electric_meter_watt = { 
		value_type = "power", 
		value = {value = 0, scale = "watt"}, 
		has_getter = true,
		has_setter = false
	}, 
	electric_meter_kwh = { 
		value_type = "amount_of_useful_energy", 
		value = {value = 0, scale = "kilo_watt_hour"}, 
		has_getter = true, 
		has_setter = false
	},
	electric_meter_amper = {
		value_type = "electric_current", 
		value = {value = 0, scale = "ampere"}, 
		has_getter = true, 
		has_setter = false
	},
	electric_meter_volt = { 
		value_type = "electric_potential", 
		value = {value = 0, scale = "volt"}, 
		has_getter = true, 
		has_setter = false
	},
	rgbcolor = { 
		value_type = "rgb",
		value = { wwhite = 0, cwhite = 0, red = 0, green = 0, blue = 0, amber = 0, cyan = 0, purple = 0 },
		has_getter = true, 
		has_setter = true
	},
	co_alarm = { 
		value_type = "token",
		value = "unknown", 
		enum= { "no_co", "co_detected", "unknown" },
		has_getter = true, 
		has_setter = false
	},
	co2_alarm = { 
		value_type = "token",
		value = "unknown", 
		enum= { "no_co2", "co2_detected", "unknown" },
		has_getter = true, 
		has_setter = false
	},
	dw_state = { 
		value_type = "token",
		value = "unknown", 
		enum= { "dw_is_opened", "dw_is_closed", "unknown" },
		has_getter = true, 
		has_setter = false
	},
	gas_alarm = { 
		value_type = "token",
		value = "unknown", 
		enum= { "no_gas", "combustible_gas_detected", "unknown" },
		has_getter = true, 
		has_setter = false
	},
	glass_breakage_alarm = { 
		value_type = "token",
		value = "unknown", 
		enum= { "no_glass_breakage", "glass_breakage", "unknown" },
		has_getter = true, 
		has_setter = false
	},
	humidity= { 
		value_type = "humidity",
		value = {value = 0, scale = "percent"},
		has_getter = true,
		has_setter = false
	},
	water_leak_alarm = { 
		value_type = "token",
		value = "unknown", 
		enum= { "no_water_leak", "water_leak_detected", "unknown" },
		has_getter = true, 
		has_setter = false
	},
	lux = {  
		value_type = "illuminance",
		value = {value = 0, scale = "percent"},
		has_getter = true,
		has_setter = false
	},
	motion = { 
		value_type = "bool",
		value = false,
		has_getter = true,
		has_setter = false
	},
	smoke_alarm = { 
		value_type = "token",
		value = "unknown", 
		enum= { "no_smoke", "smoke_detected", "unknown" },
		has_getter = true, 
		has_setter = false
	},
	temp = { 
		value_type = "temperature",
		value = {value = 0, scale = temp_units},
		value_min = {value = -85, scale = temp_units},
		value_max = {value = 100, scale = temp_units},
		has_getter = true,
		has_setter = false
	},
	thermostat_operating_state = { 
		value_type = "token",
		value = "idle", 
		enum = { "idle", "heating", "cooling", "fan_only", "pending_heat", "pending_cool", "vent_economizer", "aux_heating", "2nd_stage_heating", "2nd_stage_cooling", "2nd_stage_aux_heat", "3rd_stage_aux_heat", "2nd_stage_fan", "3rd_stage_fan" },
		has_getter = true, 
		has_setter = true
	},
	thermostat_mode = { 
		value_type = "token",
		value = "auto", 
		enum = { "off", "heat", "cool", "auto", "aux", "resume", "fan_only", "furnace", "dry_air", "moist_air", "auto_change_over", "saving_heat", "saving_cool", "away_heat", "away_cool", "full_power", "special", "eco", "emergency_heating", "precooling", "sleep" },
		has_getter = true, 
		has_setter = true
	},
	thermostat_fan_mode = { 
		value_type = "token",
		value = "fanmode_off", 
		enum = { "fanmode_on_auto_low", "fanmode_on_low", "fanmode_on_auto_high", "fanmode_on_high", "fanmode_on_auto_medium", "fanmode_on_medium", "fanmode_on_circulation", "fanmode_on_humidity_circulation", "fanmode_on_lr_circulation", "fanmode_on_ud_circulation", "fanmode_on_quiet_circulation", "fanmode_on_auto", "fanmode_on", "fanmode_off_auto_low", "fanmode_off_low", "fanmode_off_auto_high", "fanmode_off_high", "fanmode_off_auto_medium", "fanmode_off_medium", "fanmode_off_circulation", "fanmode_off_humidity_circulation", "fanmode_off_lr_circulation", "fanmode_off_ud_circulation", "fanmode_off_quiet_circulation", "fanmode_off" },
		has_getter = true, 
		has_setter = true
	},
	thermostat_fan_state = { 
		value_type = "token",
		value = "idle_off", 
		enum = { "idle_off", "running_low", "running_high", "running_medium", "circulation_mode", "humidity_circulation_mode", "right_left_circulation_mode", "up_down_circulation_mode", "quiet_circulation_mode" },
		has_getter = true, 
		has_setter = true
	},
	thermostat_setpoint = { 
		value_type = "temperature",
		value = {value = 0, scale = temp_units},
		value_min = {value = -32, scale = temp_units},
		value_max = {value = 45, scale = temp_units},
		has_getter = true,
		has_setter = true
	},
	thermostat_setpoint_heating = { 
		value_type = "temperature",
		value = {value = 0, scale = temp_units},
		value_min = {value = 15, scale = temp_units},
		value_max = {value = 45, scale = temp_units},
		has_getter = true,
		has_setter = true
	},
	thermostat_setpoint_cooling = { 
		value_type = "temperature",
		value = {value = 0, scale = temp_units},
		value_min = {value = 15, scale = temp_units},
		value_max = {value = 45, scale = temp_units},
		has_getter = true,
		has_setter = true
	},
	ultraviolet = { 
		value_type = "ultraviolet",
		value = {value = 0, scale = "uv_index"},
		has_getter = true,
		has_setter = false
	},
	goto_favorite = { 
		value_type = "bool",
		value = false,
		has_getter = false,
		has_setter = true
	},
	siren_alarm = { 
		value_type = "token",
		value = "unknown",
		enum = { "siren_inactive", "siren_active", "unknown" },
		has_getter = true,
		has_setter = false
	},
	shutter_state = { 
		value_type = "token",
		value = "idle",
		enum = { "idle", "learn_upper", "change_roll_direction", "learn_lower", "learn_favorite" },
		has_getter = true,
		has_setter = false
	},
	shutter_command = { 
		value_type = "token",
		value = "off",
		enum = { "off", "store", "learn_upper", "learn_lower", "learn_favorite", "change_roll_direction" },
		has_getter = false,
		has_setter = true
	}	
}

-- First run of plugin, do set-ups needed
local function set_configuration(config)
	-- Start with setting the log level.
	logger.setLevel(config.log_level or 99)
	logger.debug("set_configuration.config=%1", config)
	if not storage.exists("PLUGIN") then
		-- First run, create storage objects we needed. Currently these values are not shown in UI.
		storage.set_string("PLUGIN", PLUGIN)
	end
	local vera_names = {}
	local veras = config.veras or {}
	-- Update config variables for defined veras
	for _, vera in pairs(veras) do
		local vc = {}
		if storage.exists("VB_config_"..vera.name) then
			-- Vera is known
			logger.debug("Updating configuration for %1", vera.name)
		else
			-- Vera is new
			logger.debug("Creating configuration for %1", vera.name)
		end
		vc.name = vera.name
		vc.type = vera.type
		vc.ip = vera.ip
		storage.set_table("VB_config_"..vera.name, vc)
		storage.set_number("VB_RC_"..vera.name, 0)
		table.insert(vera_names, vera.name)
	end
	temp_units = config.temp_units or "celsius"
	storage.set_string("temp_units", temp_units)
	storage.set_number("max_retry_count", 5)
	storage.set_number("log_level", config.log_level)
	storage.set_table("VB_veras", vera_names)
end

-- Create a new device
local function add_device(behavior, gw, name, room, battery_powered, vera_name, vera_id)
	local cnfg = {}
	local room_id = room
--	if room and room ~= "" then
--		room_id = loadfile("HUB:"..PLUGIN.."/scripts/utils/get_config")().get(room)
--	end
	
	-- Find behavior details
	local map = DeviceMap[behavior]
	if not map then
		return nil, "unsupported behavior "..(behavior or "nil")
	end
	
	local newdev,err = core.add_device({
			gateway_id = gw,
			type = map.type,
			device_type_id = "VeraBridge_"..behavior,
			name = name,
			room_id = room_id,
			category = map.category,
			subcategory = map.subcategory,
			battery_powered = battery_powered,
			info = {manufacturer = "Rene Boer", model = "VeraBridge", remote_device = vera_name.."_"..vera_id}
		})
	if newdev then
		cnfg.behavior = behavior
		cnfg.deviceId = newdev
		cnfg.name = name
		cnfg.vera_name = vera_name
		-- Add battery item if user wants it.
		if battery_powered then 
			local base_item = ItemDetails["battery"]
			base_item.name = "battery"
			base_item.device_id = newdev
			local it, err = core.add_item(base_item)
			if it then
				if base_item.has_getter then cnfg["battery_id"] = it	end
			else
				logger.err("failed to add item %1 to device %2", "battery", newdev)
			end
		end
		for _, item in pairs(map.items) do
			local base_item = ItemDetails[item]
			if base_item then
				base_item.name = item
				base_item.device_id = newdev
				if behavior == "heater" and item == "thermostat_mode" then
					logger.info("set mode for heater device")
					base_item.value = "heat"
					base_item.enum = { "off", "heat", "auto" }
				end
				local it, err = core.add_item(base_item)
				if it then
					-- We have getter, so capture item id for it to handle updates from Vera.
					if base_item.has_getter then cnfg[item.."_id"] = it	end
				else
					logger.err("failed to add item %1 to device %2", item, newdev)
				end
			else
				logger.warn("cannot map %1, check ItemDetails.", item)
			end
		end
		return cnfg
	else
		return nil,err
	end
end

-- Create the devices as found in the VeraBridge.json
local function create_devices(veras)
	logger.debug("create_devices.veras=%1", veras)

	-- Loop over devices and see what we need to create, update
	local gateway = core.get_gateway()
	local veras = veras or {}
	local devices = {}

	for _,vera in ipairs(veras) do
		local device_count = 0
		for _,d in ipairs(vera.devices) do
			local id = math.floor(d.device_id)
			if id > 0 then
				local cnfg = storage.get_table("VB_DC_"..vera.name..id)
				-- Do we have an existing device?
				if cnfg == nil then
					logger.notice("Creating new device %1 for %2.", d.name, vera.name)
					cnfg, err = add_device(d.behavior, gateway.id, d.name, d.room_id, d.battery_powered or false, vera.name, id, d.meters)
					if cnfg then
						storage.set_table("VB_D_"..cnfg.deviceId, {name = vera.name, device_id = id} )
						storage.set_table("VB_DC_"..vera.name..id, cnfg)
						-- Device is ready to go.
						core.update_reachable_state(cnfg.deviceId, true)
						core.update_ready_state(cnfg.deviceId, true)
					else
						-- Failure delete device from storage
						logger.err("Unable to create device %1, error %2", id, err)
					end	
				else
					logger.debug("Device %1 for %2 exists.", id, vera.name)
				end
				if cnfg then 
					devices[cnfg.deviceId] = true 
					device_count = device_count + 1
				end
			else
				logger.debug("Device %1 for %2 is set to ignore.", id, vera.name)
			end
		end
		local vc = storage.get_table("VB_config_"..vera.name)
		vc.device_count = device_count
		storage.set_table("VB_config_"..vera.name, vc)
	end
	return devices
end

-- See if we have any obsolete devices no longer mapped. If so remove and clean up.
-- Should all be nicely handled by code, but who knows.
local function 	cleanup_devices(active_devices)
	-- Find the devices for this gateway. Check  
	local gateway = core.get_gateway()
	local self_id = gateway.id
	local found = false
	local devices = core.get_devices() or {}
	logger.debug("Gateway has %1 devices", #devices)
	local gateway_devices = {}
	for _,d in ipairs(devices) do
		if d.gateway_id == self_id then
--			logger.debug("Device %1 id %2 table %3", d.name, d.id, d)
			gateway_devices[d.id] = d.id
		end
	end
	
	-- See if devices are unknown, of so remove
	for _,id in pairs(gateway_devices) do
		local cnfg = nil
		local vera = storage.get_table("VB_D_"..id)
		if vera then
			cnfg = storage.get_table("VB_DC_"..vera.name..math.floor(vera.device_id))
		end
		if cnfg and active_devices[id] then
			logger.debug("Keep device %1, %2", id, cnfg.name)
		else
			logger.debug("Remove device %1, no known mapping", id)
			storage.delete("VB_D_"..id)
			if vera then
				storage.delete("VB_DC_"..vera.name..math.floor(vera.device_id))
			end
			core.remove_device(id)
		end
	end
end

-- Kick off polling for all Vera.
local function start_polling()
	local veras = storage.get_table("VB_veras")
	local cnt = 1
	for _,vera in ipairs(veras) do
		local vc = storage.get_table("VB_config_"..vera)
		if vc.device_count ~= 0 then

			-- At startup pull all data from Vera
			storage.set_string("VB_DV_"..vera,"0")

			-- Start polling timer
			local int = 10 + 3 * cnt
			cnt = cnt + 1
			logger.debug("Setting timer for %1 to poll in %2 sec.", vera, int)
			timer.set_timeout(int*1000, "HUB:"..PLUGIN.."/scripts/poll", { name = vera })
		else
			logger.info("No active devices found for %1, not polling.", vera)
		end
	end	
end

local function startup(startup_args)
	logger.debug("startup.startup_args=%1", startup_args)

	local json = require("HUB:"..PLUGIN.."/scripts/utils/dkjson")
	local config_file = "/home/data/custom_plugins/"..PLUGIN.."/"..PLUGIN..".json"
	
	local platform = _G._PLATFORM or "linux"
	local hw_rev = _G._HARDWARE_REVISION or 1
	logger.debug("Platform=%1, Hardware Revision %2", platform, hw_rev)
	
	local gateway = core.get_gateway()
	if gateway == nil then
		logger.crit("Failed to get a gateway. Check config.json.")
		return false
	else
		logger.info("My gateway is %1",gateway.id)
	end	
	
	-- Read configuration file for Solar meter device(s) to create.
	local config
	local f = io.open(config_file, "r")
	if f then
		config = json.decode((f:read("*a")))
		f:close()
		if type(config) ~= "table" then
			logger.crit("Unable to decode configuration file %1.", config_file)
			return false
		end
		logger.info("Read configuration version %1.", config.version)
	else
		logger.crit("Unable to read configuration file %1.", config_file)
		return false
	end
	-- Do plugin configuration
	set_configuration(config)

	-- Add Vera Virtual devices
	local devices = create_devices(config.veras)
	
	-- Remove any devices we no longer know.
	cleanup_devices(devices)

	-- Kick off polling all Veras.
	start_polling()

	-- Subscribe to device change events.
	if core.subscribe then
		core.subscribe("HUB:"..PLUGIN.."/scripts/event_handler", {exclude=false,rules={{event="device_updated"}}})
	end

	-- some clean up options. used as needed.
end

-- Actually run the startup function; pass all arguments, let the function sort it out.
startup(...)
