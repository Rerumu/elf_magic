local elf = require('elf_magic')

local elf_inst = elf.File.new()
local mem_seg = elf.Segment.Memory.new()
local null_sect = elf.Section.Null.new()
local code_sect = elf.Section.Code.new()
local str_sect = elf.Section.String.new()

elf_inst:set_file_class(elf.Enum.Class.B64) -- x64 file
elf_inst:push_segment(mem_seg) -- push memory load segment

mem_seg:push_section(null_sect) -- push sections (null is required as first)
mem_seg:push_section(code_sect)
mem_seg:push_section(str_sect)

str_sect:set_as_name_list() -- initialize name section (as opposed to normal strtab)
code_sect:push('\x55\x48\x89\xE5\xEB\x01\xCC\x5D\xC3')
-- https://defuse.ca/online-x86-assembler.htm
--[[
push rbp
mov rbp, rsp
jmp lbl
int 3
lbl:
pop rbp
ret
--]]

elf_inst.e_ident_data = elf.Enum.Endian.L2C
elf_inst.e_type = elf.Enum.FileType.EXEC
elf_inst.e_machine = elf.Enum.Machine.x86_64
code_sect.sh_name = str_sect:ref '.text' -- reference name

elf_inst:update() -- updates all offsets, sizes, etc
elf_inst.e_entry = code_sect.sh_offset -- our entry point is at the start of code_sect

do -- create the binary
	local fp = io.open('elf_file', 'wb')

	fp:write(elf_inst:to_bin_str())
	fp:close()
end
