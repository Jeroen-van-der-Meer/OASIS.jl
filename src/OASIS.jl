module OASIS

using CodecZlib
using GeometryBasics
using Mmap

export Cell
export Oasis
export oasisread
export PointGridRange
export Shape
export show_cells

include("read_data.jl")
include("skip_data.jl")
include("modal_variables.jl")
include("structs.jl")
include("parse_records.jl")
include("parse_utils.jl")
include("shows.jl")

const MAGIC_BYTES = [0x25, 0x53, 0x45, 0x4d, 0x49, 0x2d, 0x4f, 0x41, 0x53, 0x49, 0x53, 0x0d, 0x0a]

function oasisread(filename::AbstractString)
    buf = Mmap.mmap(filename)
    state = ParserState(buf)

    header = read_bytes(state, 13)
    @assert all(header .== MAGIC_BYTES) "Wrong header bytes; likely not an OASIS file."

    while true
        record_type = read_byte(state)
        record_type == 0x02 && break # Stop when encountering END record. Ignoring checksum.
        parse_record(record_type, state)
    end

    return state.oas
end

end # module OASIS
