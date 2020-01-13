local LuaClass
local db = string.char
local band, rshift

do
	local aux = require('elf_aux')

	band = aux.bit.band
	rshift = aux.bit.rshift
	LuaClass = aux.LuaClass
end

--
-- HELPER
--   & WRITER
--

local Writer = LuaClass('Writer', {}, function(self, is_little, long_size)
	self.write_int = is_little and self.write_le_int or self.write_be_int
	self.long_size = long_size
	self.buffer = {}
end)

function Writer:write_le_int(int, len)
	local buf = self.buffer
	local n = #buf

	for i = len, 1, -1 do buf[i + n] = db(band(rshift(int, i * 8 - 8), 0xFF)) end
end

function Writer:write_be_int(int, len)
	local buf = self.buffer
	local n = #buf

	for i = 1, len do buf[i + n] = db(band(rshift(int, i * 8 - 8), 0xFF)) end
end

function Writer:b2b(bt)
	local fb = self.buffer
	fb[#fb + 1] = db(bt)
end

function Writer:s2b(sht) return self:write_int(sht, 2) end

function Writer:i2b(int) return self:write_int(int, 4) end

function Writer:l2b(long) return self:write_int(long, self.long_size) end

function Writer:str2b(str)
	local fb = self.buffer

	fb[#fb + 1] = str
end

function Writer:pad(len)
	local fb = self.buffer
	local n = #fb

	for i = 1, len do fb[i + n] = '\0' end
end

function Writer:to_bin_str() return table.concat(self.buffer) end

return Writer
