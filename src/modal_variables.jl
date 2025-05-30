Base.@kwdef mutable struct ModalVariables
    repetition::AbstractVector{Point2i} = []
    placementX::Int64 = 0 # FIXME: Type
    placementY::Int64 = 0 # FIXME: Type
    placementCell::Int64 = 0 # FIXME: Type
    layer::UInt64 = 0
    datatype::UInt64 = 0
    textlayer::Int64 = 0 # FIXME: Type
    texttype::Int64 = 0 # FIXME: Type
    textX::Int64 = 0 # FIXME: Type
    textY::Int64 = 0 # FIXME: Type
    textString::Int64 = 0 # FIXME: Type
    geometryX::Int64 = 0
    geometryY::Int64 = 0
    xyAbsolute::Bool = true
    geometryW::Int64 = 0 # FIXME: Type
    geometryH::Int64 = 0 # FIXME: Type
    polygonPointList::Vector{Point2i} = []
    pathHalfwidth::Int64 = 0 # FIXME: Type
    pathPointList::Int64 = 0 # FIXME: Type
    pathStartExtension::Int64 = 0 # FIXME: Type
    pathEndExtension::Int64 = 0 # FIXME: Type
    ctrapezoidType::Int64 = 0 # FIXME: Type
    circleRadius::Int64 = 0 # FIXME: Type
end
