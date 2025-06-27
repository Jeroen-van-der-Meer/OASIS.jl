"""
    struct ParserState

Struct used to encode the state of the OASIS file parser.

# Properties

- `oas::Oasis`: Contents of the OASIS file.
- `currentCell::Cell`: Cell we're looking at whil parsing.
- `buf::Vector{UInt8}`: Mmapped buffer of OASIS file.
- `pos::Int64`: Byte position in buffer.
- `mod::ModalVariables`: Modal variables, following the OASIS spec.

See also [`LazyParserState`](@ref), [`WriterState`](@ref).
"""
mutable struct ParserState
    oas::Oasis
    currentCell::Cell
    buf::Vector{UInt8}
    pos::Int64
    mod::ModalVariables
end

function ParserState(buf::Vector{UInt8})
    return ParserState(Oasis(), Cell([], []), buf, 1, ModalVariables())
end

"""
    struct ParserState

Struct used to encode the state of the lazy OASIS file parser.

# Properties

- `oas::LazyOasis`: Contents of the OASIS file.
- `currentCell::LazyCell`: Cell we're looking at whil parsing.
- `buf::Vector{UInt8}`: Mmapped buffer of OASIS file.
- `pos::Int64`: Byte position in buffer.
- `mod::LazyModalVariables`: Only a few modal variables are kept track of in this parser.s

See also [`ParserState`](@ref), [`WriterState`](@ref).
"""
mutable struct LazyParserState
    oas::LazyOasis
    currentCell::LazyCell
    buf::Vector{UInt8}
    pos::Int64
    mod::LazyModalVariables
end

function LazyParserState(buf::Vector{UInt8})
    return LazyParserState(LazyOasis(buf), LazyCell(0, Dict()), buf, 1, LazyModalVariables())
end

new_state(oas::Oasis, cell::Cell, buf::Vector{UInt8}) = ParserState(oas, cell, buf, 1, ModalVariables())
new_state(oas::LazyOasis, cell::LazyCell, buf::Vector{UInt8}) = LazyParserState(oas, cell, buf, 1, LazyModalVariables())

"""
    struct WriterState

Struct used to encode the state of the OASIS file writer.

See also [`LazyParserState`](@ref), [`WriterState`](@ref).
"""
mutable struct WriterState
    # Not decided yet.
    io::IOStream # Where you're saving to.
    buf::Vector{UInt8} # An output buffer of some size, probably big.
    # Is it worth separately storing buflen? Remember we will call length(buf) for every byte...
    buflen::Int64 # Length of buffer stored separately.
    pos::Int64 # Position in buffer.
    mod::ModalVariables
end

WriterState(filename::AbstractString, buflen::Integer) = WriterState(
    IOStream(filename), Vector{UInt8}(undef, buflen), buflen, 1, ModalVariables()
)
