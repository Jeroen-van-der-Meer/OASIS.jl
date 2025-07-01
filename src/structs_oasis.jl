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
    source::Symbol
    name::String
    number::UInt64
end

function get_reference(
    source::Symbol,
    number::Integer,
    references::AbstractVector{NumericReference}
)
    index = find_reference(source, number, references)
    isnothing(index) && return
    return references[index].name
end

function find_reference(
    source::Symbol,
    number::Integer,
    references::AbstractVector{NumericReference}
)
    return findfirst(r -> (r.source == source && r.number == number), references)
end

function get_reference(
    source::Symbol,
    name::AbstractString,
    references::AbstractVector{NumericReference}
)
    index = find_reference(source, name, references)
    isnothing(index) && return
    return references[index].number
end

function find_reference(
    source::Symbol,
    name::AbstractString,
    references::AbstractVector{NumericReference}
)
    return findfirst(r -> (r.source == source && r.name == name), references)
end

function get_reference(
    name::AbstractString,
    references::AbstractVector{NumericReference}
)
    index = find_reference(name, references)
    isnothing(index) && return
    return references[index].number
end

function find_reference(
    name::AbstractString,
    references::AbstractVector{NumericReference}
)
    return findfirst(r -> r.name == name, references)
end

struct LayerReference <: AbstractReference
    name::String
    layerInterval::Interval
    datatypeInterval::Interval
end

function get_reference(l::UInt64, d::UInt64, refs::AbstractVector{LayerReference})
    index = findfirst(r -> (l in r.layerInterval && d in r.datatypeInterval), refs)
    return refs[index].name
end

Base.@kwdef struct References
    cellNames::Vector{NumericReference} = []
    textStrings::Vector{NumericReference} = []
    layerNames::Vector{LayerReference} = []
    textLayerNames::Vector{LayerReference} = []
end

Base.@kwdef mutable struct Metadata
    source::Symbol = Symbol()
    version::VersionNumber = v"1.0"
    unit::Float64 = 1.0
end

struct Text # Might want to think of a better name for this struct, since Text is used by Docs.
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

"""
    struct CellPlacement

Object encoding the placement of a cell in another cell.

# Properties

- `nameNumber::UInt64`: The cell name number for the cell that is being placed.
- `location::Point{2, Int64}`: Where the cell will be placed.
- `rotation::Float64`: Counterclockwise rotation (in degrees) of the cell.
- `magnification::Float64`: Magnification of the cell.
- `flipped::Bool`: Indicates whether or not the cell is reflected (or flipped) around the
  x-axis. Note: If a cell is flipped and has nonzero rotation, then the flip is applied first,
  and the rotation is applied second.
- `repetition`: Specifies whether the shape is repeated. If not, `repetition = nothing`.
"""
struct CellPlacement
    nameNumber::UInt64
    location::Point{2, Int64}
    rotation::Float64
    magnification::Float64
    flipped::Bool
    repetition::Union{Nothing, Vector{Point{2, Int64}}, PointGridRange}
end

"""
    struct Cell(shapes, placements, nameNumber)

# Properties

- `shapes::Vector{Shape}`: Lists the shapes, such as polygons and lines, that are contained in
  the cell.
- `placements::Vector{CellPlacement}`: Lists all other cells that are placed in this cell.

See also [`LazyCell`](@ref).
"""
struct Cell
    source::Symbol
    shapes::Vector{Shape} # Might have references to other cells within them?
    placements::Vector{CellPlacement} # Other cells
end

"""
    shapes(cell)

List the shapes contained in `cell`. Not yet supported for `LazyCell`s.
"""
shapes(cell::Cell) = cell.shapes

"""
    placements(cell)

List the placements contained in `cell`. Not yet supported for `LazyCell`s.
"""
placements(cell::Cell) = cell.placements

"""
    struct LazyCell(byte, placements)

Lazy-loaded version of a `Cell`.

# Properties

- `source::Symbol`: Name of the file the cell came from.
- `bytes::Vector{UInt8}`: Bytes of the corresponding CELL record.

See also [`Cell`](@ref), [`load_cell!`](@ref).
"""
struct LazyCell
    source::Symbol
    bytes::SubArray{UInt8, 1, Vector{UInt8}, Tuple{UnitRange{Int64}}, true}
end

Base.@kwdef struct CellHierarchy
    hierarchy::Dict{UInt64, Vector{UInt64}} = Dict()
    roots::Vector{UInt64} = []
end

"""
    struct Oasis(cells, metadata, references)

Object containing all the data of your OASIS file.

# Properties

- `cells::Dict{UInt64, Union{Cell, LazyCell}}`: The actual contents. All cells, indexed by
  their name number. The cells can either be `Cell` objects or lazy-loaded `LazyCell` objects.
- `hierarchy::CellHierarchy`: Overview of hierarchy of cells and their placements. Not guaranteed
  to be available if the OASIS file was lazy-loaded.
- `metadata::Metadata`: File version and length unit.
- `references::References`: To save on storage space, in an OASIS file, names of cells, layers,
  etc. are stored only once and are then referenced with a number. We mirror this behaviour in
  `OasisTools.jl`.
"""
Base.@kwdef struct Oasis
    cells::Dict{UInt64, Union{Cell, LazyCell}} = Dict()
    hierarchy::CellHierarchy = CellHierarchy()
    metadata::Metadata = Metadata()
    references::References = References()
end

function Base.getindex(oas::Oasis, cell_name::String)
    return getindex(cells(oas), cell_number(oas, cell_name))
end

"""
    cells(oas)

Returns an overview of all cells in your OASIS file, indexed by the cell name number. You can
find the corresponding cell name of a number `n` by running `cell_name(oas, n)`.

# Example

```jldoctest
julia> using OasisTools;

julia> filename = joinpath(OasisTools.TESTDATA_DIRECTORY, "polygon.oas");

julia> oas = oasisread(filename);

julia> cls = cells(oas);

julia> keys(cls)
KeySet for a Dict{UInt64, Union{Cell, LazyCell}} with 1 entry. Keys:
  0x0000000000000000

julia> cell_name(oas, 0x00)
"TOP"
```
"""
cells(oas::Oasis) = oas.cells

"""
    cell_names(oas)

Returns a list of all cell names in your OASIS file.

# Example

```jldoctest
julia> using OasisTools;

julia> filename = joinpath(OasisTools.TESTDATA_DIRECTORY, "boxes.oas");

julia> oas = oasisread(filename);

julia> cell_names(oas)
2-element Vector{String}:
 "TOP"
 "BOTTOM"
```
"""
cell_names(oas::Oasis) = [c.name for c in oas.references.cellNames]

"""
    cell_name(oas, cell_number)

Look up the cell name corresponding to a cell name number.

# Example

```jldoctest
julia> using OasisTools;

julia> filename = joinpath(OasisTools.TESTDATA_DIRECTORY, "polygon.oas");

julia> oas = oasisread(filename);

julia> cell_name(oas, 0x00) # `cell_name(oas, 0)` also works
"TOP"

julia> isnothing(cell_name(oas, 0x01)) # Non-existent cell name number; returns nothing
true
```

See also [`cell_number`](@ref).
"""
cell_name(oas::Oasis, cell_number::Integer) = get_reference(oas.metadata.source, cell_number, oas.references.cellNames)

"""
    cell_number(oas, cell_name)

Look up the cell name number corresponding to a cell name.

# Example

```jldoctest
julia> using OasisTools;

julia> filename = joinpath(OasisTools.TESTDATA_DIRECTORY, "polygon.oas");

julia> oas = oasisread(filename);

julia> cell_number(oas, "TOP")
0x0000000000000000

julia> isnothing(cell_number(oas, "asdf")) # Non-existent cell name; returns nothing
true
```

See also [`cell_name`](@ref).
"""
cell_number(oas::Oasis, cell_name::AbstractString) = get_reference(cell_name, oas.references.cellNames)

"""
    load_cell!(oas, cell_name)

Load a cell into memory. Use this function to convert individual `LazyCell`s into `Cell`s.

# Example

```jldoctest
julia> using OasisTools;

julia> filename = joinpath(OasisTools.TESTDATA_DIRECTORY, "nested.oas");

julia> oas = oasisread(filename; lazy = true);

julia> typeof(oas["BOTTOM"])
LazyCell

julia> load_cell!(oas, "BOTTOM");

julia> typeof(oas["BOTTOM"])
Cell
```
"""
function load_cell!(oas::Oasis, cell_name::AbstractString)
    name_number = cell_number(oas, cell_name)
    lazy_cell = oas.cells[name_number]
    load_cell!(oas, name_number, lazy_cell)
end

load_cell!(::Oasis, ::UInt64, ::Cell) = return

function load_cell!(oas::Oasis, cell_number::UInt64, lazy_cell::LazyCell)
    state = CellParserState(oas, lazy_cell.bytes)
    while state.pos < length(lazy_cell.bytes)
        record_type = read_byte(state)
        read_record(record_type, state)
    end
    cell = Cell(oas.metadata.source, state.shapes, state.placements)
    oas.cells[cell_number] = cell
    oas.hierarchy.hierarchy[cell_number] = unique(p.nameNumber for p in cell.placements)
    return oas
end
