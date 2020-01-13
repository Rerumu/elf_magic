local pairs = pairs
local setmetatable = setmetatable

local bit = bit or bit32 or load [[
	return {
		band = function(a, b) return a & b end,
		bor = function(a, b) return a | b end,
		lshift = function(a, b) return a << b end,
		rshift = function(a, b) return a >> b end,
	}
]]()

local function LuaClass(name, template, init)
	local class_mt = {}

	function class_mt.new(...)
		local self = {class_name = name}

		for k, v in pairs(template) do self[k] = v end

		setmetatable(self, class_mt)
		init(self, ...)

		return self
	end

	class_mt.__index = class_mt
	class_mt.__metatable = name

	return class_mt
end

return {bit = bit, LuaClass = LuaClass}
