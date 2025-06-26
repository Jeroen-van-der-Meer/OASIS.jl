Base.@kwdef mutable struct ModalVariables
    repetition::AbstractVector{Point{2, Int64}} = []
    placementX::Int64 = 0
    placementY::Int64 = 0
    placementCell::UInt64 = 0
    layer::UInt64 = 0
    datatype::UInt64 = 0
    textlayer::UInt64 = 0
    texttype::UInt64 = 0
    textX::Int64 = 0
    textY::Int64 = 0
    textString::UInt64 = 0
    geometryX::Int64 = 0
    geometryY::Int64 = 0
    xyAbsolute::Bool = true
    geometryW::UInt64 = 0
    geometryH::UInt64 = 0
    polygonPointList::Vector{Point{2, Int64}} = []
    pathHalfwidth::UInt64 = 0
    pathPointList::Vector{Point{2, Int64}} = []
    pathStartExtension::Int64 = 0
    pathEndExtension::Int64 = 0
    ctrapezoidType::UInt64 = 0
    circleRadius::UInt64 = 0
end

Base.@kwdef mutable struct LazyModalVariables
    nrep::Int64 = 0
    placementCell::UInt64 = 0
end
