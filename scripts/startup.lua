--[[
	Vera device Bridge plugin for Ezo Linux based hubs
	
	File	: startup.lua
	Version	: 0.1
	Author	: Rene Boer
--]]
local PLUGIN = "VeraBridge"
local storage = require("storage")
local core = require("core")
local timer = require("timer")
local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/startup").setLevel(storage.get_number("log_level") or 99)


-- First run of plugin, do set-ups needed
local function set_configuration(config)
	-- Start with setting the log level.
	logger.setLevel(config.log_level or 99)
	logger.debug("set_configuration.config=%1", config)
	if storage.get_string("PLUGIN") == nil then
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
		table.insert(vera_names, vera.name)
	end
	storage.set_number("log_level", config.log_level)
	storage.set_table("VB_veras", vera_names)
end

local function create_devices(veras)
	logger.debug("create_devices.veras=%1", veras)

	-- Loop over devices and see what we need to create, update
	local gateway = core.get_gateway()
	local veras = veras or {}
	for _,vera in ipairs(veras) do
		for _,d in ipairs(vera.devices) do
			local id = math.floor(d.device_id)
			local cnfg = storage.get_table("VB_DC_"..vera.name..id)
			-- Do we have an existing device?
			if cnfg == nil then
				-- Create new device for behavior
				local adder = loadfile( "HUB:"..PLUGIN.."/scripts/devices/"..d.behavior.."_add" )
				if adder then
					logger.notice("Creating new device %1 for %2.", d.name, vera.name)
					cnfg, err = adder(gateway.id, d.name, d.room_id, vera.name..id, d.meters)
					if cnfg then
						storage.set_table("VB_D_"..cnfg.deviceId, {name = vera.name, device_id = id} )
						-- Device is ready to go.
						core.update_reachable_state(cnfg.deviceId, true)
						core.update_ready_state(cnfg.deviceId, true)
					else
						-- Failure delete device from storage
						storage.delete("VB_DC_"..vera.name..id)
						logger.err("Unable to create device %1, error %2", id, err)
					end	
				else
					logger.warn("No device definition found for behavior %1. Device %2 for %3 not created.", d.behavior, id, vera.name)
				end
			else
				logger.debug("Device %1 for %2 exists.", id, vera.name)
			end
			if cnfg then
				cnfg.behavior = d.behavior
				cnfg.vera_name = vera.name
				cnfg.name = d.name
				storage.set_table("VB_DC_"..vera.name..id, cnfg)
			end
		end
	end
end

-- See if we have any obsolete devices no longer mapped. If so remove and clean up.
local function 	cleanup_devices()
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
		if cnfg then
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
local function start_polling(veras)
	local veras = veras or {}
	local cnt = 1
	for _,vera in ipairs(veras) do
		-- At startup pull all data from Vera
		storage.set_string("VB_DV_"..vera.name,"0")

		-- Start polling timer
		local int = 10 + 5 * cnt
		cnt = cnt + 1
		logger.debug("Setting timer for %1 to poll in %2 sec.", vera.name, int)
		timer.set_timeout(int*1000, "HUB:"..PLUGIN.."/scripts/poll", { name = vera.name })
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
	create_devices(config.veras)
	
	-- Remove any devices we no longer know.
	cleanup_devices()

	-- Kick off polling all Veras.
	start_polling(config.veras)

	-- some clean up options. used as needed.
end

-- Actually run the startup function; pass all arguments, let the function sort it out.
startup(...)
