struct Shape{T}
    shape::T
    layerNumber::UInt64 # If T = Text, this refers to textlayerNumber
    datatypeNumber::UInt64 # If T = Text, this refers to texttypeNumber
    repetition::Union{Nothing, Vector{Point{2, Int64}}, PointGridRange}
end

abstract type AbstractReference end

struct NumericReference <: AbstractReference
    name::String
    number::UInt64
end

function find_reference(number::UInt64, references::AbstractVector{NumericReference})
    index = findfirst(r -> r.number == number, references)
    return references[index].name
end

function find_reference(name::String, references::AbstractVector{NumericReference})
    index = findfirst(r -> r.name == name, references)
    return references[index].number
end

struct LayerReference <: AbstractReference
    name::String
    layerInterval::Interval
    datatypeInterval::Interval
end

function find_reference(l::UInt64, d::UInt64, refs::AbstractVector{LayerReference})
    index = findfirst(r -> (l in r.layerInterval && d in r.datatypeInterval), refs)
    return refs[index].name
end

Base.@kwdef struct References
    cellNames::Vector{NumericReference} = []
    textStrings::Vector{NumericReference} = []
    layerNames::Vector{LayerReference} = []
    textLayerNames::Vector{LayerReference} = []
    cells::Vector{NumericReference} = []
end

Base.@kwdef mutable struct Metadata
    version::VersionNumber = v"1.0"
    unit::Float64 = 1.0
end

struct Text
    textNumber::UInt64
    location::Point{2, Int64}
    repetition::Union{Nothing, Vector{Point{2, Int64}}, PointGridRange}
end

"""
    Path(points::AbstractVector{<:Point}, width)

A Path is a polyline with finite width, or equivalently, a `GeometryBasis.LineString` with
specified width.
"""
struct Path{Dim, T<:Real} <: AbstractGeometry{Dim, T}
    points::Vector{Point{Dim, T}}
    width::T
end

struct CellPlacement
    nameNumber::UInt64
    location::Point{2, Int64}
    rotation::Float64
    magnification::Float64
    repetition::Union{Nothing, Vector{Point{2, Int64}}, PointGridRange}
end

struct Cell
    shapes::Vector{Shape} # Might have references to other cells within them?
    cells::Vector{CellPlacement} # Other cells
    nameNumber::UInt64
end

Base.@kwdef struct Oasis
    cells::Vector{Cell} = []
    metadata::Metadata = Metadata()
    references::References = References()
end

mutable struct ParserState
    oas::Oasis # Contents of the OASIS file.
    currentCell::Cell # Current cell we're looking at.
    buf::Vector{UInt8} # Mmapped buffer of OASIS file.
    pos::Int64 # Byte position in buffer.
    mod::ModalVariables # Modal variables according to OASIS spec.
end

function ParserState(buf::Vector{UInt8})
    return ParserState(Oasis(), Cell([], [], 0), buf, 1, ModalVariables())
end

struct CellHierarchy
    hierarchy::Dict{UInt64, Vector{UInt64}}
    root::UInt64
    
    function CellHierarchy(h)
        all_nodes = Set(keys(h))
        child_nodes = Set(v for children in values(h) for v in children)
        root = first(setdiff(all_nodes, child_nodes))
        return new(h, root)
    end
end

CellHierarchy(oas::Oasis) = CellHierarchy(
    Dict(c.nameNumber => [i.nameNumber for i in c.cells]
    for c in oas.cells)
)
