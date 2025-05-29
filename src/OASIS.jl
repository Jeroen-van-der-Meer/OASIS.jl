module OASIS

using GeometryBasics

export Cell
export OasisFile
export oasisread
export PointGridRange
export Shape

include("read_data.jl")
include("stream.jl")
include("structs.jl")
include("parse_records.jl")
include("parse_utils.jl")

const MAGIC_BYTES = [0x25, 0x53, 0x45, 0x4d, 0x49, 0x2d, 0x4f, 0x41, 0x53, 0x49, 0x53, 0x0d, 0x0a]

function oasisread(filename::AbstractString)
    file = open(filename)
    os = OasisStream(file)
    of = OasisFile()
    header = read(os.io, 13)
    @assert all(header .== MAGIC_BYTES) "Wrong header bytes; likely not an OASIS file."
    while true
        record_type = read(os.io, UInt8)
        record_type == 0x02 && break # Stop when encountering END record. Ignoring checksum.
        RECORD_PARSER_PER_TYPE[record_type + 1](os, of)
    end
    close(file)
    return of
end

end # module OASIS
