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

function find_reference(p::UInt64, references::AbstractVector{NumericReference})
    index = findfirst(r -> r.number == p, references)
    return references[index].name
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

@kwdef struct References
    cellNames::Vector{NumericReference} = []
    textStrings::Vector{NumericReference} = []
    layerNames::Vector{LayerReference} = []
    textLayerNames::Vector{LayerReference} = []
    cells::Vector{NumericReference} = []
end

@kwdef mutable struct Metadata
    version::VersionNumber = v"1.0"
    unit::Float64 = 1.0
end

abstract type AbstractOasisData end

struct Cell <: AbstractOasisData
    shapes::Vector{Shape} # Might have references to other cells within them
    nameNumber::UInt64
end

@kwdef struct Oasis <: AbstractOasisData
    cells::Vector{Cell} = [] # Might need to be the top cell instead
    metadata::Metadata = Metadata()
    references::References = References()
end