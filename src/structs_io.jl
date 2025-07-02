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
    return ParserState(Oasis(), buf, 1, lazy)
end

"""
    struct CellParserState

Struct used to encode the state of the CELL record parser.

# Properties

- `oas::Oasis`: The upstream OASIS object we're appending to.
- `shapes::Vector{Shape}`: The shapes it's collecting.
- `placements::Vector{CellPlacement}`: The placements it's collecting.
- `buf::Vector{UInt8}`: Mmapped buffer of OASIS file.
- `pos::Int64`: Byte position in buffer.
- `mod::ModalVariables`: Modal variables it needs to keep track of.

See also [`LazyCellParserState`](@ref).
"""
mutable struct CellParserState <: AbstractParserState
    oas::Oasis
    shapes::Vector{Shape}
    placements::Vector{CellPlacement}
    buf::Vector{UInt8}
    pos::Int64
    mod::ModalVariables
end

function CellParserState(state::ParserState)
    return CellParserState(state.oas, [], [], state.buf, state.pos, ModalVariables())
end

function CellParserState(oas::Oasis, buf::AbstractVector{UInt8})
    return CellParserState(oas, [], [], buf, 1, ModalVariables())
end

function CellParserState(buf::AbstractVector{UInt8})
    return CellParserState(Oasis(), [], [], buf, 1, ModalVariables())
end

"""
    struct LazyCellParserState

Struct used to encode the state of the lazy CELL record parser.

# Properties

- `buf::Vector{UInt8}`: Mmapped buffer of OASIS file.
- `pos::Int64`: Byte position in buffer.

See also [`CellParserState`](@ref).
"""
mutable struct LazyCellParserState <: AbstractParserState
    buf::Vector{UInt8}
    pos::Int64
end

function LazyCellParserState(state::ParserState)
    return LazyCellParserState(state.buf, state.pos)
end

new_state(state::ParserState, new_buf::AbstractVector{UInt8}) =
    ParserState(state.oas, new_buf, 1, state.lazy)

new_state(state::CellParserState, new_buf::AbstractVector{UInt8}) =
    CellParserState(state.oas, state.shapes, state.placements, new_buf, 1, state.mod)

new_state(::LazyCellParserState, new_buf::AbstractVector{UInt8}) =
    LazyCellParserState(new_buf, 1)

"""
    struct WriterState

Struct used to encode the state of the OASIS file writer.

# Properties

- `oas::Oasis`: The object we're trying to save.
- `io::IOStream`: File we're saving to.
- `buf::Vector{UInt8}`: We write to the file in batches, and temporarily store the output in
  this buffer.
- `bufsize::Int64`: Size of `buf`.
- `pos::Int64`: Position in the buffer.

See also [`ParserState`](@ref), [`CellParserState`](@ref).
"""
mutable struct WriterState
    oas::Oasis # The object we're trying to save.
    io::IOStream # File we're saving to.
    buf::Vector{UInt8} # An output buffer of some size, probably big.
    bufsize::Int64 # Length of buffer stored separately.
    pos::Int64 # Position in buffer.
end

WriterState(oas::Oasis, filename::AbstractString, bufsize::Integer) = WriterState(
    oas, open(filename, "w"), Vector{UInt8}(undef, bufsize), bufsize, 1
)

WriterState(filename::AbstractString, bufsize::Integer) = WriterState(
    Oasis(), open(filename, "w"), Vector{UInt8}(undef, bufsize), bufsize, 1
)
