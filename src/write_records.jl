function write_start(state::WriterState, oas::Oasis)
    write_byte(state, 1) # START
    version = "$(oas.metadata.version.major).$(oas.metadata.version.minor)"
    write_bn_string(state, version)
    unit = oas.metadata.unit
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

function write_cellname(state::WriterState, cellname::String)
    write_byte(state, 3) # CELLNAME
    write_bn_string(state, cellname)
end

function write_textstring(state::WriterState, textstring::String)
    write_byte(state, 5) # TEXTSTRING
    write_bn_string(state, textstring)
end

function write_layername(state::WriterState, layer_name, layer_interval, datatype_interval)
    write_byte(state, 11) # LAYERNAME
    write_bn_string(state, layer_name)
    write_interval(state, layer_interval)
    write_interval(state, datatype_interval)
end

function write_textlayername(state::WriterState, textlayer_name, textlayer_interval, texttype_interval)
    write_byte(state, 12) # LAYERNAME
    write_bn_string(state, textlayer_name)
    write_interval(state, textlayer_interval)
    write_interval(state, texttype_interval)
end

function write_cell(state::WriterState, oas::Oasis, cell_number::UInt64, cell::LazyCell)
    write_byte(state, 13) # CELL
    # Write a new reference number
    new_cell_number = find_reference(
        cell.source,
        cell_number,
        oas.references.cellNames
    ) - 1
    wui(state, new_cell_number)

    # When writing a LazyCell, we mostly just have to copy-paste bytes onto our target buffer.
    # To figure out how many bytes to copy, we invoke the same parser that we also use for
    # lazily parsing a cell.
    cell_parser_state = LazyCellParserState(cell.bytes, 1)
    nbytes = length(cell.bytes)
    while cell_parser_state.pos < nbytes
        record_type = read_byte(cell_parser_state)
        copywrite_record(record_type, state, oas, cell, cell_parser_state)
    end
    state.pos += nbytes # Off by 1?
end

function copywrite_placement(
    state::WriterState,
    oas::Oasis,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState
)
    write_byte(state, 17) # PLACEMENT
    info_byte = read_byte(cell_parser_state)
    # If the text reference is explicit, the second bit indicates that a reference number is used.
    # When writing our file, we always use a reference, so we set the second bit to 1.
    info_byte_to_write = info_byte | 0b01000000
    write_byte(state, info_byte_to_write)

    text_explicit = bit_is_nonzero(info_byte, 1)
    if text_explicit
        text_as_ref = bit_is_nonzero(info_byte, 2)
        if text_as_ref
            cell_number = rui(cell_parser_state)
            new_cell_number = find_reference(
                cell.source,
                cell_number,
                oas.references.cellNames
            ) - 1
        else
            cell_name = read_string(cell_parser_state)
            new_cell_number = find_reference(
                cell.source,
                cell_name,
                oas.references.cellNames
            ) - 1
        end
        @assert new_cell_number isa Int64
        wui(state, new_cell_number)
    end

    # After writing the new reference, we copy the remaining records.
    remaining_record_start = cell_parser_state.pos
    bit_is_nonzero(info_byte, 3) && skip_integer(cell_parser_state)
    bit_is_nonzero(info_byte, 4) && skip_integer(cell_parser_state)
    bit_is_nonzero(info_byte, 5) && skip_repetition(cell_parser_state)
    record_end = cell_parser_state.pos - 1
    nbytes = record_end - remaining_record_start + 1
    write_bytes(state, view(cell_parser_state.buf, remaining_record_start:record_end), nbytes)
end

function copywrite_placement_mag_angle(
    state::WriterState,
    oas::Oasis,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState
)
    write_byte(state, 18) # PLACEMENT
    info_byte = read_byte(cell_parser_state)
    # If the text reference is explicit, the second bit indicates that a reference number is used.
    # When writing our file, we always use a reference, so we set the second bit to 1.
    info_byte_to_write = info_byte | 0b01000000
    write_byte(state, info_byte_to_write)

    text_explicit = bit_is_nonzero(info_byte, 1)
    if text_explicit
        text_as_ref = bit_is_nonzero(info_byte, 2)
        if text_as_ref
            cell_number = rui(cell_parser_state)
            new_cell_number = find_reference(
                cell.source,
                cell_number,
                oas.references.cellNames
            ) - 1
        else
            cell_name = read_string(cell_parser_state)
            new_cell_number = find_reference(
                cell.source,
                cell_name,
                oas.references.cellNames
            ) - 1
        end
        @assert new_cell_number isa Int64
        wui(state, new_cell_number)
    end

    # After writing the new reference, we copy the remaining records.
    remaining_record_start = cell_parser_state.pos
    bit_is_nonzero(info_byte, 6) && skip_real(cell_parser_state)
    bit_is_nonzero(info_byte, 7) && skip_real(cell_parser_state)
    bit_is_nonzero(info_byte, 3) && skip_integer(cell_parser_state)
    bit_is_nonzero(info_byte, 4) && skip_integer(cell_parser_state)
    bit_is_nonzero(info_byte, 5) && skip_repetition(cell_parser_state)
    record_end = cell_parser_state.pos - 1
    nbytes = record_end - remaining_record_start + 1
    write_bytes(state, view(cell_parser_state.buf, remaining_record_start:record_end), nbytes)
end

function copywrite_text(
    state::WriterState,
    oas::Oasis,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState
)
    write_byte(state, 19) # TEXT
    info_byte = read_byte(cell_parser_state)
    # If the text reference is explicit, the third bit indicates that a reference number is used.
    # When writing our file, we always use a reference, so we set the third bit to 1.
    info_byte_to_write = info_byte | 0b00100000
    write_byte(state, info_byte_to_write)

    text_explicit = bit_is_nonzero(info_byte, 2)
    if text_explicit
        text_as_ref = bit_is_nonzero(info_byte, 3)
        if text_as_ref
            text_number = rui(cell_parser_state)
            new_text_number = find_reference(
                cell.source,
                text_number,
                oas.references.textStrings
            ) - 1
        else
            text = read_string(cell_parser_state)
            new_text_number = find_reference(
                cell.source,
                text,
                oas.references.textStrings
            ) - 1
        end
        @assert new_text_number isa Int64
        wui(state, new_text_number)
    end
    
    # After writing the new reference, we copy the remaining records.
    remaining_record_start = cell_parser_state.pos
    bit_is_nonzero(info_byte, 8) && skip_integer(cell_parser_state)
    bit_is_nonzero(info_byte, 7) && skip_integer(cell_parser_state)
    bit_is_nonzero(info_byte, 4) && skip_integer(cell_parser_state)
    bit_is_nonzero(info_byte, 5) && skip_integer(cell_parser_state)
    bit_is_nonzero(info_byte, 6) && skip_repetition(cell_parser_state)
    record_end = cell_parser_state.pos - 1
    nbytes = record_end - remaining_record_start + 1
    write_bytes(state, view(cell_parser_state.buf, remaining_record_start:record_end), nbytes)
end

function copywrite_cblock(
    state::WriterState,
    oas::Oasis,
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
        copywrite_record(record_type, state, oas, cell, cell_parser_decomp)
    end
end

function copywrite_record(
    record_type::UInt8,
    state::WriterState,
    oas::Oasis,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState
)
    # PLACEMENT and TEXT records need special attention as they contain internal references (to
    # cell name and text strings, respectively), which are unique to the file they are
    # contained in.
    record_type == 17 && return copywrite_placement(state, oas, cell, cell_parser_state)
    record_type == 18 && return copywrite_placement_mag_angle(state, oas, cell, cell_parser_state)
    record_type == 19 && return copywrite_text(state, oas, cell, cell_parser_state)
    # CBLOCK records also need special attention because they need to be uncompressed.
    record_type == 34 && return copywrite_cblock(state, oas, cell, cell_parser_state)

    # All remaining records can be copy-pasted.
    record_start = cell_parser_state.pos - 1
    read_record(record_type, cell_parser_state)
    record_end = cell_parser_state.pos - 1
    nbytes = record_end - record_start + 1
    write_bytes(state, view(cell_parser_state.buf, record_start:record_end), nbytes)
end
