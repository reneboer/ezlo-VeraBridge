--[[

Handle polling timer for Bridged Vera. Send http get for lu_status2

--]]
local function vb_poll(args)
	local storage = require("storage")
	local PLUGIN = storage.get_string("PLUGIN")
	local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/poll").setLevel(storage.get_number("log_level") or 99)
	local http = require("http")

	-- Must have vera name in arg.
	local vera_name = args.name
	-- Fire off the connection to get lu_status2 from Vera
	local vera = storage.get_table("VB_config_"..vera_name)
	if vera then
		local dv = storage.get_string("VB_DV_"..vera_name) or "0"
		if dv ~= "-1" then
			-- Build Vera/openLuup URL
			local veraURI = "/data_request?id=lu_status2&output_format=json&Timeout=60&DataVersion=" .. dv
			local vt = string.upper(vera.type)
			if vt == "VERA" then
				veraURI = "http://" .. vera.ip .. "/port_3480" .. veraURI
			elseif vt == "OPENLUUP" then
				-- Handle 3480 port number (openLuup)
				veraURI = "http://" .. vera.ip .. ":3480" .. veraURI
			else
				logger.err("Unsupported hub type %1. Expect Vera or openLuup.", vera.type)
				return
			end	
			logger.debug("Vera %1 Poll URL: %2", vera_name, veraURI)
			http.request { url = veraURI, handler = "HUB:"..PLUGIN.."/scripts/update", user_data = vera_name}
		else
			logger.info("Instructed %1 to stop polling.", vera_name)
		end
	else
		logger.err("No device configurations known.")
	end

end

vb_poll(...)
