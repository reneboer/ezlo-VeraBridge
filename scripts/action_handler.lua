-- HTTP handler without any actions.
local storage = require("storage")
local http = require("http")
local PLUGIN = storage.get_string("PLUGIN")
local logger = require("HUB:"..PLUGIN.."/scripts/utils/log").setPrefix(PLUGIN.."/scripts/action_handler").setLevel(storage.get_number("log_level") or 99)


local function vb_action_handler(event)
	local ed = event.data
	local vera_name = ed.user_data
	if event.event == "http_data_send" then
		logger.info("I have nothing to send??")
	elseif event.event == "http_data_received" then
		if ed.code == 200 then
			logger.debug("HTTP response %1 ", ed.data)
		else
			logger.err("We got data, but not what we expected :-). HTTP return code %1", ed.code)
		end
		-- Clear retry counter
		storage.set_number("VB_RC_"..vera_name, 0)
	elseif event.event == "http_connection_closed" then
		if ed.reason.code ~= 0 then
--			logger.debug("http event %1", event)
			if ed.reason.code == 6 then
				-- Timeout for action URL, resend until successful or max retries reached.
				local rc = storage.get_number("VB_RC_"..vera_name)
				if rc < storage.get_number("max_retry_count") then
					logger.debug("Retry Vera Action URL: %1", ed.url)
					storage.set_number("VB_RC_"..vera_name, rc + 1)
					http.request { url = ed.url, handler = "HUB:"..PLUGIN.."/scripts/action_handler", user_data = vera_name }
				else
					storage.set_number("VB_RC_"..vera_name, 0)
					logger.err("max retries exceeded for action ", ed.url)
				end
			else
				logger.info("Connection to %1 closed. Reason %2", vera_name, ed.reason)
			end
		end
	else
		logger.err("unexpected event type %1", event.event)
	end
end

vb_action_handler(...)
