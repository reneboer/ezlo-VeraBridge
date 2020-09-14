-- Add an item based on standard zwave template
local function vb_add_item(device, default_type, default_value, enum)
	local base_item = require("HUB:zwave/scripts/model/items/default/"..default_type)
	base_item.device_id = device
	if default_value then base_item.value = default_value end
	if enum then base_item.enum = enum end
	return core.add_item(base_item)
end

return vb_add_item(...)