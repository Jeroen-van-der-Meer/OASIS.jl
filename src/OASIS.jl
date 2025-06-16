module OASIS

using CodecZlib
using GeometryBasics

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
    global modals = ModalVariables()
    global oas = Oasis()
    file = open(filename)
    header = read(file, 13)
    @assert all(header .== MAGIC_BYTES) "Wrong header bytes; likely not an OASIS file."
    while true
        record_type = read(file, UInt8)
        record_type == 0x02 && break # Stop when encountering END record. Ignoring checksum.
        RECORD_PARSER_PER_TYPE[record_type + 1](file)
    end
    close(file)
    return oas
end

end # module OASIS
