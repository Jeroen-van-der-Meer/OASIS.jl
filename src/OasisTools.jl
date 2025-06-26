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

include("parse_data.jl")
include("skip_data.jl")
include("modal_variables.jl")
include("structs.jl")
include("parse_records.jl")
include("skip_records.jl")
include("parse_utils.jl")
include("parse_oasis.jl")
include("shows.jl")

function plot_cell end
function plot_shape! end
if !isdefined(Base, :get_extension)
    include("../ext/OasisPlots.jl")
end

end # module OasisTools
