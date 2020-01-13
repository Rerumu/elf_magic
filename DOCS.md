All classes share the `class_name` string of their type name.

## **Magic Classes**
Magic Classes are the main classes used to create ELF files and iteract with them.

### `File`
The `File` class holds information about an ELF file and handles serialization.

```Lua
-- fields
e_ident_magic = '\x7FELF';
e_ident_class = Enum.Class.NONE;
e_ident_data = Enum.Endian.NONE;
e_ident_version = 1;
e_ident_OS_ABI = Enum.OS_ABI.NONE;
e_ident_ABI_version = 0;
e_type = Enum.FileType.NONE;
e_machine = Enum.Machine.NONE;
e_version = 1;
e_entry = 0;
e_phoff = Enum.PHOffset.NONE;
e_shoff = 0;
e_flags = 0;
e_ehsize = 0;
e_phentsize = 0;
e_phnum = 0;
e_shentsize = 0;
e_shnum = 0;
e_shstrndx = 0;
segment_list: table;

-- methods
push_segment(seg: BaseSegment) -> nil;
set_file_class(t: Enum.Class) -> nil;
get_sizes() -> integer, integer, integer;
update() -> nil;
```

* `push_segment`: Pushes `BaseSegment` `seg` to the `segment_list` of the file.
* `set_file_class`: Sets the file class (architecture) and checks its validity.
* `get_sizes`: Gets the sizes of the `ehsize`, `phentsize`, and `shentsize` based on the file class.
* `update`: Updates addresses and offsets using its segments and their content.

### `BaseSegment`
Base class which all segments inherit from. Provides the default fields and functions.

```Lua
-- fields
p_type = Enum.SegmentType.NULL;
p_flags = Enum.SegmentFlags.NONE;
p_offset = 0x0;
p_vaddr = 0x0;
p_paddr = 0x0;
p_filesz = 0;
p_memsz = 0;
p_align = 0;

-- methods
update() -> nil;
```

* `update`: Updates addresses and offsets of the segment.

### `HDRSegment` : _`BaseSegment`_
This segment should be the first in the `File`. Sets its offset from the ELF magic to the end of the headers.

### `MemorySegment` : _`BaseSegment`_
A segment that holds `BaseSection`s to be loaded into memory during program startup.

```Lua
-- fields
ld_sections: table;

-- methods
push_section(section: BaseSection) -> nil;
```

* `push_section`: Pushes a `BaseSection` `section` to the `section_list` list.

### `BaseSection`
Base class which all sections inherit from. Provides the default fields and functions.

```Lua
-- fields
sh_name = 0;
sh_type = Enum.SectionType.NULL;
sh_flags = Enum.SectionFlags.NONE;
sh_addr = 0x0;
sh_offset = 0x0;
sh_size = 0;
sh_link = 0;
sh_info = 0;
sh_addralign = 0;
sh_entsize = 0;

-- methods:
update() -> nil;
data_to_str(W: Writer) -> nil;
```

* `update`: Updates addresses and offsets of the section.
* `data_to_str`: Writes the section's binary data to `Writer` `W`.

### `NullSection` : _`BaseSection`_
A section with no information, or placeholder.

### `StringSection` : _`BaseSection`_
Holds strings and handles their caching and indexing.

```Lua
-- fields
ss_strings: table;
ss_size: integer;

-- methods
push(str: string) -> integer;
get_index(str: string) -> integer;
ref(str: string) -> integer;
set_as_name_list() -> nil;
```

* `push`: Pushes a `string` `str` into the section `ss_strings`.
* `get_index`: Gets the index of the first character of `string` `str` in the flat section, otherwise returns `false`.
* `ref`: Looks up the index of `string` `str` in the flat section and pushes a new reference if not found.
* `set_as_name_list`: Sets the section name to `".shstrtab"` and removes flags to comply with ELF section name list.

### `DataSection` : _`BaseSection`_
Holds a memory section. The section can hold read-only, executable, or writeable data.

```Lua
-- fields
ds_data: table;
ds_size: integer;

-- methods
set_as_code() -> nil;
lookup(exp_tt: integer, exp_dt: string, exp_ext: any) -> integer;
push_data(dt: string) -> integer;
push_int(int: integer, len: integer) -> integer;
push_string(str: string) -> integer;
ref_data(dt: string) -> integer;
ref_int(int: integer, len: integer) -> integer;
ref_string(str: string) -> integer;
```

* `set_as_code`: Sets the section flags and alignment to store code.
* `lookup`: Looks up the `string` `exp_dt` with type `integer` `exp_tt` and optional info `string`  `exp_ext` in the data section.
* `push_data`: Pushes the literal data `string` `dt`.
* `push_int`: Pushes the `integer` `int` of `integer` `len` size bytes.
* `push_string`: Pushes the null terminated `string` `str`.
* `ref_data`: Looks up `string` `dt` or pushes a new one if not found.
* `ref_int`: Looks up `integer` `int` or pushes a new one if not found.
* `ref_string`: Looks up null terminated `string` `str` or pushes a new one if not found.

## Auxiliary Classes
Auxiliary Classes are classes made to aid in functionality of the main classes.

### `Writer`
The `Writer` class handles an efficient buffer for transforming `File`s into their binary representation.

```Lua
-- fields
write_int: function;
long_size: integer;
buffer: table;

-- methods
Writer(is_little: boolean, long_size: integer);
write_le_int(int: integer, len: integer) -> nil;
write_be_int(int: integer, len: integer) -> nil;
b2b(bt: byte) -> nil;
s2b(sht: short) -> nil;
i2b(int: integer) -> nil;
l2b(long: long) -> nil;
str2b(str: string) -> nil;
pad(len: integer) -> nil;
to_bin_str() -> string;
```

* `Writer`: Initializes a new `Writer` with `is_little` dictating little or big endian and `long_size` dictating the length of the `long` data type.
* `write_le_int`: Writes a little endian integer `int` of size `len` to its `buffer`.
* `b2b`: Writes a single byte `bt` into the buffer.
* `s2b`: Writes a short `sht` into the buffer.
* `i2b`: Writes an integer `int` into the buffer.
* `l2b`: Writes a long `long` into the buffer.
* `str2b`: Writes the string `str` into the buffer without null terminator.
* `pad`: Writes `len` amount of nulls into the buffer.
* `to_bin_str`: Concatenates and returns the buffer.
