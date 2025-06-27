module OasisTools

using CodecZlib
using GeometryBasics
import Mmap: mmap

export Cell
export cell_name
export cell_names
export cell_number
export CellPlacement
export cells
export LazyCell
export LazyOasis
export Oasis
export oasisread
export placements
export plot_cell
export plot_shape!
export PointGridRange
export Shape
export shapes
export show_cells
export show_shapes

# Structs
include("modal_variables.jl")
include("structs_data.jl")
include("structs_oasis.jl")
include("structs_io.jl")
include("shows.jl")

# Reading
include("read_data.jl")
include("read_records.jl")
include("read_utils.jl")
include("read_oasis.jl")

# Skipping
include("skip_data.jl")
include("skip_records.jl")

# Writing
include("write_data.jl")

# Plotting
function plot_cell end
function plot_shape! end
if !isdefined(Base, :get_extension)
    include("../ext/OasisPlots.jl")
end

# Consts
const MAGIC_BYTES = [0x25, 0x53, 0x45, 0x4d, 0x49, 0x2d, 0x4f, 0x41, 0x53, 0x49, 0x53, 0x0d, 0x0a]
const TESTDATA_DIRECTORY = joinpath(@__DIR__, "..", "test", "testdata")

end # module OasisTools
