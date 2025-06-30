using GeometryBasics
using Makie
using OasisTools
import OasisTools: ParserState, CellParserState
import Suppressor
using Test

include("read_data_test.jl")
include("read_oasis_test.jl")
include("write_data_test.jl")
include("plots_test.jl")
