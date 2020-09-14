-- HTTP handler without any actions.
local storage = require("storage")
local PLUGIN = storage.get_string("PLUGIN")
local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/gen_http_handler").setLevel(storage.get_number("log_level") or 99)


local function vb_gen_http_event(event)
	local ed = event.data
	if event.event == "http_data_send" then
		logger.info("I have nothing to send??")
	elseif event.event == "http_data_received" then
		if ed.code == 200 then
			logger.debug("HTTP response %1 ", ed.data)
		else
			logger.err("We got data, but not what we expected :-). HTTP return code %1", ed.code)
		end
	elseif event.event == "http_connection_closed" then
		if ed.reason.code ~= 0 then
			logger.info("connection closed. Reason %1", ed.reason)
		end
	else
		logger.err("unexpected event type %1", event.event)
	end
end

vb_gen_http_event(...)
