struct Shape{T <: AbstractGeometry{2, Int64}}
    shape::T
    layerNumber::UInt64
    datatypeNumber::UInt64
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

struct CellPlacement
    nameNumber::UInt64
    location::Point{2, Int64}
    rotation::Float64
    magnification::Float64
    repetition::Union{Nothing, Vector{Point{2, Int64}}, PointGridRange}
end

struct Cell
    shapes::Vector{Shape} # Might have references to other cells within them
    cells::Vector{CellPlacement} # Other cells
    nameNumber::UInt64
end

Base.@kwdef struct Oasis
    cells::Vector{Cell} = [] # Might need to be the top cell instead
    metadata::Metadata = Metadata()
    references::References = References()
end