--[[
	teardown.lua
	Stop polling loops
--]]
local function vb_teardown()
	local storage = require("storage")
	local timer = require("timer")
	local PLUGIN = storage.get_string("PLUGIN")
	local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/teardown").setLevel(storage.get_number("log_level") or 99)

	logger.info("Stopping plugin %1", PLUGIN)
	local veras = storage.get_table("VB_veras")
	for _,vera in pairs(veras) do
		-- Set poll data version to -1 to stop pollers.
		storage.set_string("VB_DV_"..vera,"-1")
	end
end

vb_teardown(...)