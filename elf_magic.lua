-- spec followed: https://refspecs.linuxbase.org/elf/elf.pdf
-- referenced also: https://linux.die.net/man/5/elf
local bit, LuaClass
local Writer = require('elf_writer')

local function void_func() end

do
	local aux = require('elf_aux')

	bit = aux.bit
	LuaClass = aux.LuaClass
end

local Enum = {
	-- file header
	Class = {NONE = 0, B32 = 1, B64 = 2},
	Endian = {NONE = 0, L2C = 1, B2C = 2},
	OS_ABI = {
		NONE = 0x00,
		System_V = 0x00,
		HP_UX = 0x01,
		NetBSD = 0x02,
		Linux = 0x03,
		GNU_Hurd = 0x04,
		Solaris = 0x06,
		AIX = 0x07,
		IRIX = 0x08,
		FreeBSD = 0x09,
		Tru64 = 0x0A,
		Novell_Modesto = 0x0B,
		OpenBSD = 0x0C,
		OpenVMS = 0x0D,
		NonStop_Kernel = 0x0E,
		AROS = 0x0F,
		Fenix_OS = 0x10,
		CloudABI = 0x11,
	},
	FileType = {
		NONE = 0x0,
		REL = 0x1,
		EXEC = 0x2,
		DYN = 0x3,
		CORE = 0x4,
		LOOS = 0xFE00,
		HIOS = 0xFEFF,
		LOPROC = 0xFF00,
		HIPROC = 0xFFFF,
	},
	Machine = {
		NONE = 0x00,
		M32 = 0x01,
		SPARC = 0x02,
		x86 = 0x03,
		_68K = 0x04,
		_88K = 0x05,
		_860 = 0x07,
		MIPS = 0x08,
		MIPS_RS4_BE = 0x0A,
		PowerPC = 0x14,
		S390 = 0x16,
		ARM = 0x28,
		SuperH = 0x2A,
		IA_64 = 0x32,
		x86_64 = 0x3E,
		AArch64 = 0xB7,
		RISC_V = 0xF3,
	},
	PHOffset = {NONE = 0x00, B32 = 0x34, B64 = 0x40},

	-- program header
	SegmentType = {
		NULL = 0x0,
		LOAD = 0x1,
		DYNAMIC = 0x2,
		INTERP = 0x3,
		NOTE = 0x4,
		SHLIB = 0x5,
		PHDR = 0x6,
		TLS = 0x7,
		LOOS = 0x60000000,
		HIOS = 0x6FFFFFFF,
		LOPROC = 0x70000000,
		HIPROC = 0x7FFFFFFF,
	},
	SegmentFlags = {NONE = 0x0, X = 0x1, W = 0x2, R = 0x4, MARKPROC = 0xF0000000},

	-- section header
	SectionType = {
		NULL = 0x00,
		PROGBITS = 0x01,
		SYMTAB = 0x02,
		STRTAB = 0x03,
		RELA = 0x04,
		HASH = 0x05,
		DYNAMIC = 0x06,
		NOTE = 0x07,
		NOBITS = 0x08,
		REL = 0x09,
		SHLIB = 0x0A,
		DYNSYM = 0x0B,
		INIT_ARRAY = 0x0E,
		FINI_ARRAY = 0x0F,
		PREINIT_ARRAY = 0x10,
		GROUP = 0x11,
		SYMTAB_SHNDX = 0x12,
		NUM = 0x13,
		LOOS = 0x60000000,
	},
	SectionFlags = {NONE = 0x0, WRITE = 0x1, ALLOC = 0x2, EXECINSTR = 0x4, MASKPROC = 0xf0000000},
}

local DEFAULT_PROGRAM_HEADER = {
	p_type = Enum.SegmentType.NULL,
	p_flags = Enum.SegmentFlags.NONE, -- may be ahead
	p_offset = 0,
	p_vaddr = 0,
	p_paddr = 0,
	p_filesz = 0,
	p_memsz = 0,
	p_align = 0,
}

local DEFAULT_SECTION_HEADER = {
	sh_name = 0,
	sh_type = Enum.SectionType.NULL,
	sh_flags = Enum.SectionFlags.NONE,
	sh_addr = 0,
	sh_offset = 0,
	sh_size = 0,
	sh_link = 0,
	sh_info = 0,
	sh_addralign = 0,
	sh_entsize = 0,
}

--
-- ELF
--   TYPE
--

local File = LuaClass('File', {
	-- identifier
	e_ident_magic = '\x7FELF',
	e_ident_class = Enum.Class.NONE,
	e_ident_data = Enum.Endian.NONE,
	e_ident_version = 1,
	e_ident_OS_ABI = Enum.OS_ABI.NONE,
	e_ident_ABI_version = 0,

	-- metadata
	e_type = Enum.FileType.NONE,
	e_machine = Enum.Machine.NONE,
	e_version = 1,
	e_entry = 0,
	e_phoff = Enum.PHOffset.NONE,
	e_shoff = 0,
	e_flags = 0,
	e_ehsize = 0,
	e_phentsize = 0,
	e_phnum = 0,
	e_shentsize = 0,
	e_shnum = 0,
	e_shstrndx = 0,
}, function(self) self.segment_list = {} end)

function File:push_segment(seg) table.insert(self.segment_list, seg) end

function File:set_file_class(t)
	if t == Enum.Class.B32 then
		self.e_phoff = Enum.PHOffset.B32
	elseif t == Enum.Class.B64 then
		self.e_phoff = Enum.PHOffset.B64
	else
		error('invalid file class', 2)
	end

	self.e_ident_class = t
end

function File:get_sizes()
	local e_class = self.e_ident_class

	if e_class == Enum.Class.B32 then
		return 0x34, 0x20, 0x28
	elseif e_class == Enum.Class.B64 then
		return 0x40, 0x38, 0x40
	else
		error('invalid file class', 2)
	end
end

function File:update()
	local sections = {}
	local m_phnum = #self.segment_list
	local m_ehsize, m_phentsize, m_shentsize = self:get_sizes()
	local f_index = m_phnum * m_phentsize + m_ehsize

	for _, seg in ipairs(self.segment_list) do
		seg.p_offset = f_index
		seg.p_paddr = f_index
		seg.p_vaddr = f_index % math.max(1, seg.p_align)
		seg:update()

		if seg.class_name == 'MemorySegment' then
			local sect_list = seg.section_list
			local sect_num = #sect_list

			if sect_num ~= 0 then
				local last = sect_list[sect_num]
				f_index = last.sh_offset + last.sh_size

				for i = 1, sect_num do table.insert(sections, sect_list[i]) end
			end
		end
	end

	if m_phnum ~= 0 then
		self.e_phoff = m_ehsize
		self.e_phnum = m_phnum
		self.e_phentsize = m_phentsize
	end

	if #sections ~= 0 then
		self.e_shoff = f_index
		self.e_shnum = #sections
		self.e_shentsize = m_shentsize
	end

	self.e_ehsize = m_ehsize

	for i, v in ipairs(sections) do
		if v.class_name == 'StringSection' and v:get_index '.shstrtab' == v.sh_name then
			self.e_shstrndx = i - 1
			break
		end
	end
end

local function aux_seg_hdr_to_str(W, seg)
	W:i2b(seg.p_type)

	if W.long_size == 8 then W:i2b(seg.p_flags) end

	W:l2b(seg.p_offset)
	W:l2b(seg.p_vaddr)
	W:l2b(seg.p_paddr)
	W:l2b(seg.p_filesz)
	W:l2b(seg.p_memsz)

	if W.long_size == 4 then W:i2b(seg.p_flags) end

	W:l2b(seg.p_align)
end

local function aux_sect_hdr_to_str(W, sect)
	W:i2b(sect.sh_name)
	W:i2b(sect.sh_type)
	W:l2b(sect.sh_flags)
	W:l2b(sect.sh_addr)
	W:l2b(sect.sh_offset)
	W:l2b(sect.sh_size)
	W:i2b(sect.sh_link)
	W:i2b(sect.sh_info)
	W:l2b(sect.sh_addralign)
	W:l2b(sect.sh_entsize)
end

function File:to_bin_str()
	local is_little = self.e_ident_data == Enum.Endian.L2C
	local long_size = self.e_ident_class == Enum.Class.B64 and 8 or 4
	local W = Writer.new(is_little, long_size)
	local sections = {}

	-- file header
	W:str2b(self.e_ident_magic)
	W:b2b(self.e_ident_class)
	W:b2b(self.e_ident_data)
	W:b2b(self.e_ident_version)
	W:b2b(self.e_ident_OS_ABI)
	W:b2b(self.e_ident_ABI_version)
	W:pad(7)
	W:s2b(self.e_type)
	W:s2b(self.e_machine)
	W:i2b(self.e_version)
	W:l2b(self.e_entry)
	W:l2b(self.e_phoff)
	W:l2b(self.e_shoff)
	W:i2b(self.e_flags)
	W:s2b(self.e_ehsize)
	W:s2b(self.e_phentsize)
	W:s2b(self.e_phnum)
	W:s2b(self.e_shentsize)
	W:s2b(self.e_shnum)
	W:s2b(self.e_shstrndx)

	for _, seg in ipairs(self.segment_list) do
		aux_seg_hdr_to_str(W, seg)

		if seg.class_name == 'MemorySegment' then
			for _, sect in ipairs(seg.section_list) do table.insert(sections, sect) end
		end
	end

	for _, sect in ipairs(sections) do sect:data_to_str(W) end

	for _, sect in ipairs(sections) do aux_sect_hdr_to_str(W, sect) end

	return W:to_bin_str()
end

--
-- SEGMENT
--   TYPES
--

local HDRSegment = LuaClass('HDRSegment', DEFAULT_PROGRAM_HEADER, function(self)
	self.p_type = Enum.SegmentType.LOAD
	self.p_flags = bit.bor(Enum.SegmentFlags.R, Enum.SegmentFlags.X)
	self.p_vaddr = 0x0
	self.p_paddr = 0x0
	self.p_align = 0x200000
end)

local MemorySegment = LuaClass('MemorySegment', DEFAULT_PROGRAM_HEADER, function(self)
	self.p_type = Enum.SegmentType.LOAD
	self.p_flags = bit.bor(Enum.SegmentFlags.R, Enum.SegmentFlags.X)
	self.p_vaddr = 0x0
	self.p_paddr = 0x0
	self.p_align = 0x200000
	self.section_list = {}
end)

function HDRSegment:update()
	local f_index = self.p_offset

	self.p_offset = 0x0
	self.p_vaddr = 0x0
	self.p_paddr = 0x0
	self.p_filesz = f_index
	self.p_memsz = f_index
end

function MemorySegment:push_section(section) table.insert(self.section_list, section) end

function MemorySegment:update()
	local f_index = self.p_offset

	for _, sect in ipairs(self.section_list) do
		sect:update()
		sect.sh_addr = f_index
		sect.sh_offset = f_index
		f_index = f_index + sect.sh_size
	end

	self.p_filesz = f_index - self.p_offset
	self.p_memsz = self.p_filesz
end

--
-- SECTION
--   TYPES
--

local NullSection = LuaClass('NullSection', DEFAULT_SECTION_HEADER,
                             function(self) self.sh_type = Enum.SectionType.NULL end)

local StringSection = LuaClass('StringSection', DEFAULT_SECTION_HEADER, function(self)
	self.sh_type = Enum.SectionType.STRTAB
	self.sh_flags = Enum.SectionFlags.ALLOC
	self.ss_strings = {''}
	self.ss_size = 1
end)

local CodeSection = LuaClass('CodeSection', DEFAULT_SECTION_HEADER, function(self)
	self.sh_type = Enum.SectionType.PROGBITS
	self.sh_flags = bit.bor(Enum.SectionFlags.ALLOC, Enum.SectionFlags.EXECINSTR)
	self.sh_addralign = 0x10
	self.cs_instructions = {}
end)

NullSection.update = void_func
NullSection.data_to_str = void_func

function StringSection:push(str)
	local now_size = self.ss_size
	self.ss_size = now_size + #str + 1
	table.insert(self.ss_strings, str)

	return now_size
end

function StringSection:get_index(str)
	local index = 0
	local ok = false

	for _, v in ipairs(self.ss_strings) do
		if v == str then
			ok = true
			break
		end

		index = index + #v + 1
	end

	return ok and index
end

function StringSection:ref(str) return self:get_index(str) or self:push(str) end

function StringSection:set_as_name_list()
	self.sh_flags = Enum.SectionFlags.NONE
	self.sh_name = self:ref '.shstrtab'
end

function StringSection:update()
	local str_list = self.ss_strings
	local size = #str_list

	for i = 2, size do size = size + #str_list[i] end

	self.sh_size = size
end

function StringSection:data_to_str(W)
	for _, v in ipairs(self.ss_strings) do
		W:str2b(v)
		W:b2b(0)
	end
end

function CodeSection:push(inst) table.insert(self.cs_instructions, inst) end

function CodeSection:update()
	local size = 0

	for _, v in ipairs(self.cs_instructions) do size = size + #v end

	self.sh_size = size
end

function CodeSection:data_to_str(W) for _, v in ipairs(self.cs_instructions) do W:str2b(v) end end

return {
	Enum = Enum,
	File = File,
	Segment = {HDR = HDRSegment, Memory = MemorySegment},
	Section = {Null = NullSection, String = StringSection, Code = CodeSection},
}
