"""
    struct Shape(shape, layerNumber, datatypeNumber, repetition)

Geometric shape (such as a polygon or rectangle) or text.

# Properties

- `shape`: The actual shape. If the shape is geometric, then `shape::GeometryBasics.GeometryPrimitive{2, Int64}`,
  unless the shape is a path, in which case `shape::OASIS.Path` because `GeometryBasics` doesn't
  have an appropriate object to encode paths. If the shape is text, then `shape::OASIS.Text`.
- `layerNumber::UInt64`: The layer that your shape lives in. You can find the name of the layer
  using the `references` field of your `Oasis` object.
- `datatypeNumber::UInt64`: The 'datatype' that your shape lives in. To clarify, if your shape
  lives in `(1/0)`, then `datatypeNumber = 0`.
- `repetition`: Specifies whether the shape is repeated. If not, `repetition = nothing`.
"""
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
    Path(points, width)

A polyline with finite width, or equivalently, a `GeometryBasis.LineString` with specified
width.
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

"""
    struct Cell(shapes, cells, nameNumber)

# Arguments

- `shapes::Vector{Shape}`: Lists the shapes, such as polygons and lines, that are contained in
  the cell.
- `cells::Vector{CellPlacement}`: Lists all other cells that are placed in this cell.
- `nameNumber::UInt64`: The number corresponding to the name of the cell. You can find the
  corresponding string in the `references` field of your `Oasis` object.
"""
struct Cell
    shapes::Vector{Shape} # Might have references to other cells within them?
    cells::Vector{CellPlacement} # Other cells
    nameNumber::UInt64
end

"""
    struct Oasis(cells, metadata, references)

Object containing all the data of your OASIS file.

# Arguments

- `cells::Vector{Cell}`: The actual contents.
- `metadata::Metadata`: File version and length unit.
- `references::References`: To save on storage space, in an OASIS file, names of cells, layers,
  etc. are stored only once and are then referenced with a number. We mirror this behaviour in
  `OASIS.jl`.
"""
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
