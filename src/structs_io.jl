abstract type AbstractParserState end

"""
    struct ParserState

Struct used to encode the state of the OASIS file parser.

# Properties

- `oas::Oasis`: Contents of the OASIS file.
- `buf::Vector{UInt8}`: Mmapped buffer of OASIS file.
- `pos::Int64`: Byte position in buffer.
- `lazy::Bool`: Whether or not we should parse lazily. It is only invoked when encountering a
  CELL record and deciding whether to spawn a `CellParserState` or a `LazyCellParserState`.

See also [`WriterState`](@ref), [`CellParserState`](@ref).
"""
mutable struct ParserState <: AbstractParserState
    oas::Oasis
    buf::Vector{UInt8}
    pos::Int64
    lazy::Bool
end

function ParserState(buf::AbstractVector{UInt8}; lazy::Bool = false)
    return ParserState(Oasis(buf), buf, 1, lazy)
end

"""
    struct CellParserState

Struct used to encode the state of the CELL record parser.

# Properties

- `shapes::Vector{Shape}`: The shapes it's collecting.
- `placements::Vector{CellPlacement}`: The placements it's collecting.
- `buf::Vector{UInt8}`: Mmapped buffer of OASIS file.
- `pos::Int64`: Byte position in buffer.
- `mod::ModalVariables`: Modal variables it needs to keep track of.
- `references::References`: Taken from the `references` field of the upstream `Oasis` object.
  These are only used if a TEXT record is encountered.

See also [`LazyCellParserState`](@ref).
"""
mutable struct CellParserState <: AbstractParserState
    shapes::Vector{Shape}
    placements::Vector{CellPlacement}
    buf::Vector{UInt8}
    pos::Int64
    mod::ModalVariables
    references::References
end

function CellParserState(state::ParserState)
    return CellParserState([], [], state.buf, state.pos, ModalVariables(), state.oas.references)
end

function CellParserState(buf::AbstractVector{UInt8})
    return CellParserState([], [], buf, 1, ModalVariables(), References())
end

"""
    struct LazyCellParserState

Struct used to encode the state of the lazy CELL record parser.

# Properties

- `placements::Dict{UInt64, Int64}`: `LazyCellParserState` keeps track of how often cells are
  placed within each other. This is the minimum amount of information needed to generate a cell
  hierarchy.
- `buf::Vector{UInt8}`: Mmapped buffer of OASIS file.
- `pos::Int64`: Byte position in buffer.
- `mod::LazyModalVariables`: Unlike `CellParserState`, `LazyCellParserState` only needs to
  remember two modal variables: the last cell that has been placed, and the amount of times it
  has been placed.

See also [`CellParserState`](@ref).
"""
mutable struct LazyCellParserState <: AbstractParserState
    placements::Dict{UInt64, Int64}
    buf::Vector{UInt8}
    pos::Int64
    mod::LazyModalVariables
end

function LazyCellParserState(state::ParserState)
    return LazyCellParserState(Dict(), state.buf, state.pos, LazyModalVariables())
end

new_state(state::ParserState, new_buf::AbstractVector{UInt8}) =
    ParserState(state.oas, new_buf, 1, state.lazy)

new_state(state::CellParserState, new_buf::AbstractVector{UInt8}) =
    CellParserState(state.shapes, state.placements, new_buf, 1, state.mod, state.references)

new_state(state::LazyCellParserState, new_buf::AbstractVector{UInt8}) =
    LazyCellParserState(state.placements, new_buf, 1, state.mod)

"""
    struct WriterState

Struct used to encode the state of the OASIS file writer.

See also [`ParserState`](@ref), [`WriterState`](@ref).
"""
mutable struct WriterState
    # Not decided yet.
    io::IOStream # Where you're saving to.
    buf::Vector{UInt8} # An output buffer of some size, probably big.
    # Is it worth separately storing bufsize? Remember we will call length(buf) for every byte...
    bufsize::Int64 # Length of buffer stored separately.
    pos::Int64 # Position in buffer.
    mod::ModalVariables
end

WriterState(filename::AbstractString, bufsize::Integer) = WriterState(
    open(filename, "w"), Vector{UInt8}(undef, bufsize), bufsize, 1, ModalVariables()
)
