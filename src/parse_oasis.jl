const MAGIC_BYTES = [0x25, 0x53, 0x45, 0x4d, 0x49, 0x2d, 0x4f, 0x41, 0x53, 0x49, 0x53, 0x0d, 0x0a]

"""
    oasisread(filename; kw...)

Read your OASIS file in Julia.

# Keyword Arguments

- `lazy::Bool = false`: If set to `true`, `oasisread` will use an experimental lazy loader
  which does not load the contents of the cells into memory until a cell explicitly gets
  prompted.

# Example

```jldoctest
julia> using OasisTools;

julia> filename = joinpath(OasisTools.TESTDATA_DIRECTORY, "polygon.oas");

julia> oas = oasisread(filename)
OASIS file v1.0 with the following cells:
TOP
```

# Caveats

- There *will* be bugs.
- Properties are currently ignored.
- Backwards-compatible extensions are not supported. You will get an error if your file contains
  any.
- Curvilinear features are not yet supported.
"""
function oasisread(filename::AbstractString; lazy::Bool = false)
    buf = mmap(filename)
    if lazy
        state = LazyParserState(buf)
    else
        state = ParserState(buf)
    end

    header = read_bytes(state, 13)
    @assert all(header .== MAGIC_BYTES) "Wrong header bytes; likely not an OASIS file."

    while true
        record_type = read_byte(state)
        record_type == 0x02 && break # Stop when encountering END record. Ignoring checksum.
        parse_record(record_type, state, false)
    end

    return state.oas
end
