function write_start(state::WriterState, unit::Float64)
    write_byte(state, 1) # START
    write_bn_string(state, "1.0")
    write_real(state, 1e6 / unit)
    write_byte(state, 0) # offset-flag
    for _ in 1:12
        write_byte(state, 0x00) # table-offsets
    end
end

function write_end(state::WriterState)
    write_byte(state, 2) # END
    padding_string = "In the beginning was the Word, and the Word was with God, and the Word was a god. What has come into existence by means of him was life, and the life was the light of men. The Word became flesh and resided among us; he was full of divine favor and truth."
    write_a_string(state, padding_string) # Make END record exactly 256 bytes long
    write_byte(state, 0) # Validation scheme: No validation
end

function write_cellname(state::WriterState, name::Symbol)
    write_byte(state, 3) # CELLNAME
    write_bn_string(state, name)
end

function write_propname(state::WriterState, name::Symbol)
    write_byte(state, 7) # PROPNAME
    write_bn_string(state, name)
end

function write_layername(state::WriterState, layer::Layer)
    write_byte(state, 11) # LAYERNAME
    write_bn_string(state, layer.name)
    write_interval(state, layer.layerNumber)
    write_interval(state, layer.datatypeNumber)
end

function write_textlayername(state::WriterState, layer::Layer)
    write_byte(state, 12) # LAYERNAME
    write_bn_string(state, layer.name)
    write_interval(state, layer.layerNumber)
    write_interval(state, layer.datatypeNumber)
end

function write_cell(state::WriterState, cell::Cell)
    @assert isempty(shapes(cell)) "Can't write shapes of non-lazy-loaded cells yet"
    for placement in placements(cell)
        if !isone(placement.magnification) || !iszero(mod(placement.rotation, 90))
            write_placement_mag_angle(state, placement)
        else
            write_placement(state, placement)
        end
    end
end

function write_cell(state::WriterState, cell::LazyCell)
    write_byte(state, 13) # CELL
    # Write a new reference number
    wui(state, state.cellnameReferences[cell.name])

    # When writing a LazyCell, we mostly just have to copy-paste bytes onto our target buffer.
    # To figure out how many bytes to copy, we invoke the same parser that we also use for
    # lazily parsing a cell.
    cell_parser_state = LazyCellParserState(cell.bytes, 1)
    nbytes = length(cell.bytes)
    while cell_parser_state.pos < nbytes
        record_type = read_byte(cell_parser_state)
        copywrite_record(record_type, state, cell, cell_parser_state)
    end
end

function copywrite_placement(
    state::WriterState,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState
)
    write_byte(state, 17) # PLACEMENT
    info_byte = read_byte(cell_parser_state)
    write_cellname_reference(state, cell, cell_parser_state, info_byte)

    # After writing the new reference, we copy the remaining records.
    remaining_record_start = cell_parser_state.pos
    bit_is_one(info_byte, 3) && skip_integer(cell_parser_state)
    bit_is_one(info_byte, 4) && skip_integer(cell_parser_state)
    bit_is_one(info_byte, 5) && skip_repetition(cell_parser_state)
    record_end = cell_parser_state.pos - 1
    nbytes = record_end - remaining_record_start + 1
    write_bytes(state, view(cell_parser_state.buf, remaining_record_start:record_end), nbytes)
end

function write_placement(
    state::WriterState,
    placement::CellPlacement
)
    info_byte = 0b11110000
    cellname = placement.cellName
    cellname_explicit = cellname != state.mod.placementCell
    cellname_explicit ? (state.mod.placementCell = cellname) : set_bit_to_zero(info_byte, 1)

    x = placement.location[1]
    x_explicit = x != state.mod.placementX
    x_explicit ? (state.mod.placementX = x) : set_bit_to_zero(info_byte, 3)

    y = placement.location[2]
    y_explicit = y != state.mod.placementY
    y_explicit ? (state.mod.placementY = y) : set_bit_to_zero(info_byte, 4)

    info_byte |= (UInt8(placement.rotation ÷ 90) << 1)

    rep = placement.repetition
    has_repetition = !isnothing(rep)
    has_repetition && set_bit_to_one(info_byte, 5)
    
    flipped = placement.flipped
    flipped && set_bit_to_one(info_byte, 8)

    write_byte(state, 17) # PLACEMENT
    write_byte(state, info_byte)
    cellname_explicit && wui(state, state.cellnameReferences[cell.name])
    x_explicit && wui(state, x)
    y_explicit && wui(state, y)
    has_repetition && write_repetition(state, rep)
end

function copywrite_placement_mag_angle(
    state::WriterState,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState
)
    write_byte(state, 18) # PLACEMENT
    info_byte = read_byte(cell_parser_state)
    write_cellname_reference(state, cell, cell_parser_state, info_byte)

    # After writing the new reference, we copy the remaining records.
    remaining_record_start = cell_parser_state.pos
    bit_is_one(info_byte, 6) && skip_real(cell_parser_state)
    bit_is_one(info_byte, 7) && skip_real(cell_parser_state)
    bit_is_one(info_byte, 3) && skip_integer(cell_parser_state)
    bit_is_one(info_byte, 4) && skip_integer(cell_parser_state)
    bit_is_one(info_byte, 5) && skip_repetition(cell_parser_state)
    record_end = cell_parser_state.pos - 1
    nbytes = record_end - remaining_record_start + 1
    write_bytes(state, view(cell_parser_state.buf, remaining_record_start:record_end), nbytes)
end

function copywrite_text(
    state::WriterState,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState
)
    write_byte(state, 19) # TEXT
    info_byte = read_byte(cell_parser_state)
    write_text(state, cell, cell_parser_state, info_byte)

    # After writing the new reference, we copy the remaining records.
    remaining_record_start = cell_parser_state.pos
    bit_is_one(info_byte, 8) && skip_integer(cell_parser_state)
    bit_is_one(info_byte, 7) && skip_integer(cell_parser_state)
    bit_is_one(info_byte, 4) && skip_integer(cell_parser_state)
    bit_is_one(info_byte, 5) && skip_integer(cell_parser_state)
    bit_is_one(info_byte, 6) && skip_repetition(cell_parser_state)
    record_end = cell_parser_state.pos - 1
    nbytes = record_end - remaining_record_start + 1
    write_bytes(state, view(cell_parser_state.buf, remaining_record_start:record_end), nbytes)
end

function write_property(state::WriterState, propname::Integer, propvalue::Symbol)
    write_byte(state, 28) # PROPERTY
    write_byte(state, 0b00010111) # Single value; property name referenced numerically
    wui(state, propname) # Numerical reference to property name
    write_property_value(state, propvalue)
end

function copywrite_cblock(
    state::WriterState,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState
)
    # To handle a CBLOCK, we temporarily replace the buffer of the lazy cell parser, and continue
    # our copywriting adventure.
    skip_byte(cell_parser_state) # comp_type
    uncomp_byte_count = rui(cell_parser_state)
    comp_byte_count = rui(cell_parser_state)

    comp_bytes = view_bytes(cell_parser_state, comp_byte_count)
    z = DeflateDecompressorStream(IOBuffer(comp_bytes))
    buf_decompress = Vector{UInt8}(undef, uncomp_byte_count)
    read!(z, buf_decompress)
    close(z)

    cell_parser_decomp = new_state(cell_parser_state, buf_decompress)
    while cell_parser_decomp.pos <= uncomp_byte_count
        record_type = read_byte(cell_parser_decomp)
        copywrite_record(record_type, state, cell, cell_parser_decomp)
    end
end

function copywrite_record(
    record_type::UInt8,
    state::WriterState,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState
)
    # PLACEMENT and TEXT records need special attention as they contain internal references (to
    # cell name and text strings, respectively), which are unique to the file they are
    # contained in.
    record_type == 17 && return copywrite_placement(state, cell, cell_parser_state)
    record_type == 18 && return copywrite_placement_mag_angle(state, cell, cell_parser_state)
    record_type == 19 && return copywrite_text(state, cell, cell_parser_state)

    # CBLOCK records also need special attention because they need to be uncompressed.
    record_type == 34 && return copywrite_cblock(state, cell, cell_parser_state)

    # All remaining records can be copy-pasted.
    record_start = cell_parser_state.pos - 1
    read_record(record_type, cell_parser_state)
    record_end = cell_parser_state.pos - 1
    nbytes = record_end - record_start + 1
    write_bytes(state, view(cell_parser_state.buf, record_start:record_end), nbytes)
end
