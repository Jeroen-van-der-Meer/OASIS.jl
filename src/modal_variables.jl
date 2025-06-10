Base.@kwdef mutable struct ModalVariables
    repetition::AbstractVector{Point2i} = []
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
    polygonPointList::Vector{Point2i} = []
    pathHalfwidth::Int64 = 0 # FIXME: Type
    pathPointList::Int64 = 0 # FIXME: Type
    pathStartExtension::Int64 = 0 # FIXME: Type
    pathEndExtension::Int64 = 0 # FIXME: Type
    ctrapezoidType::Int64 = 0 # FIXME: Type
    circleRadius::Int64 = 0 # FIXME: Type
end
