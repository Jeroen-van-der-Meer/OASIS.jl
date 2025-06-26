"""
    struct Shape(shape, layerNumber, datatypeNumber, repetition)

Geometric shape (such as a polygon or rectangle) or text.

# Properties

- `shape`: The actual shape. If the shape is geometric, then `shape::GeometryBasics.GeometryPrimitive{2, Int64}`,
  unless the shape is a path, in which case `shape::OasisTools.Path` because `GeometryBasics`
  doesn't have an appropriate object to encode paths. If the shape is text, then
  `shape::OasisTools.Text`.
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

function find_reference(number::Integer, references::AbstractVector{NumericReference})
    index = findfirst(r -> r.number == number, references)
    isnothing(index) && return index
    return references[index].name
end

function find_reference(name::AbstractString, references::AbstractVector{NumericReference})
    index = findfirst(r -> r.name == name, references)
    isnothing(index) && return index
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
    placements::Vector{CellPlacement} # Other cells
end

shapes(cell::Cell) = cell.shapes
placements(cell::Cell) = cell.placements

# This should be a recursive function somehow...
# Should return I guess a dictionary where, for each relevant cell ID, it spits out coordinates.
# Problem: How will we do this with our lazy parser? it would be a pain to go through everything
# yet again....
# That said, it's probably the best option.

struct LazyCell
    byte::Int64
    placements::Dict{UInt64, Int64} # Indicates how often other cells are placed in this one.
end

abstract type AbstractOasis end

"""
    struct Oasis(cells, metadata, references)

Object containing all the data of your OASIS file.

# Arguments

- `cells::Vector{Cell}`: The actual contents.
- `metadata::Metadata`: File version and length unit.
- `references::References`: To save on storage space, in an OASIS file, names of cells, layers,
  etc. are stored only once and are then referenced with a number. We mirror this behaviour in
  `OasisTools.jl`.
"""
Base.@kwdef struct Oasis <: AbstractOasis
    cells::Dict{UInt64, Cell} = Dict()
    metadata::Metadata = Metadata()
    references::References = References()
end

struct LazyOasis <: AbstractOasis
    buf::Vector{UInt8} # Mmapped buffer of OASIS file.
    cells::Dict{UInt64, LazyCell}
    metadata::Metadata
    references::References
end

function LazyOasis(buf::Vector{UInt8})
    return LazyOasis(buf, Dict(), Metadata(), References())
end

function Base.getindex(oas::AbstractOasis, cell_name::String)
    return getindex(cells(oas), cell_number(oas, cell_name))
end

cells(oas::AbstractOasis) = oas.cells
cell_names(oas::AbstractOasis) = [c.name for c in oas.references.cellNames]
cell_name(oas::AbstractOasis, cell_number::Integer) = find_reference(cell_number, oas.references.cellNames)
cell_number(oas::AbstractOasis, cell_name::AbstractString) = find_reference(cell_name, oas.references.cellNames)

mutable struct ParserState
    oas::Oasis # Contents of the OASIS file.
    currentCell::Cell # Current cell we're looking at.
    buf::Vector{UInt8} # Mmapped buffer of OASIS file.
    pos::Int64 # Byte position in buffer.
    mod::ModalVariables # Modal variables according to OASIS spec.
end

function ParserState(buf::Vector{UInt8})
    return ParserState(Oasis(), Cell([], []), buf, 1, ModalVariables())
end

mutable struct LazyParserState
    oas::LazyOasis # Lazily loaded contents of the OASIS file.
    currentCell::LazyCell # Current cell we're looking at.
    buf::Vector{UInt8} # Mmapped buffer of OASIS file.
    pos::Int64 # Byte position in buffer.
    mod::LazyModalVariables
end

function LazyParserState(buf::Vector{UInt8})
    return LazyParserState(LazyOasis(buf), LazyCell(0, Dict()), buf, 1, LazyModalVariables())
end

new_state(oas::Oasis, cell::Cell, buf::Vector{UInt8}) = ParserState(oas, cell, buf, 1, ModalVariables())
new_state(oas::LazyOasis, cell::LazyCell, buf::Vector{UInt8}) = LazyParserState(oas, cell, buf, 1, LazyModalVariables())

struct CellHierarchy
    hierarchy::Dict{UInt64, Dict{UInt64, Int64}}
    roots::Set{UInt64}
end

function CellHierarchy(h::Dict{UInt64, Dict{UInt64, Int64}})
    all_nodes = Set(keys(h))
    child_nodes = Set(k for children in values(h) for (k, v) in pairs(children) if v > 0)
    roots = setdiff(all_nodes, child_nodes) # There can be multiple roots
    return CellHierarchy(h, roots)
end

function CellHierarchy(oas::Oasis)
    h = Dict{UInt64, Dict{UInt64, Int64}}()
    for (cell_number, cell) in pairs(oas.cells)
        if !haskey(h, cell_number)
            h[cell_number] = Dict()
        end
        for placement in cell.placements
            if haskey(h[cell_number], placement.nameNumber)
                h[cell_number][placement.nameNumber] += nrep(placement.repetition)
            else
                h[cell_number][placement.nameNumber] = nrep(placement.repetition)
            end
        end
    end
    return CellHierarchy(h)
end

CellHierarchy(oas::LazyOasis) = CellHierarchy(Dict(k => v.placements for (k, v) in pairs(oas.cells)))

nrep(::Nothing) = 1
nrep(rep::Vector{Point{2, Int64}}) = length(rep)
nrep(rep::PointGridRange) = length(rep)
