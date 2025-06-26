skip_record(state) = return

function skip_propname_impl(state)
    skip_string(state)
end

function skip_propname_ref(state)
    skip_string(state)
    skip_integer(state)
end

function skip_propstring_impl(state)
    skip_string(state)
end

function skip_propstring_ref(state)
    skip_string(state)
    skip_integer(state)
end

function skip_cell(state)
    while true
        # The reason we look ahead one byte is because we cannot tell in advance when the CELL
        # record ends. If it ends, this function will likely return to the main parser which
        # also needs to read a byte to find the next record.
        @inbounds record_type = state.buf[state.pos]
        is_end_of_cell(state, record_type) ? break : state.pos += 1
        # We 'parse' each record within the cell, but this amounts to skipping each record.
        parse_record(record_type, state, true)
    end
end

function skip_cell_ref(state)
    cellname_number = rui(state)
    cell = LazyCell(state.pos, Dict())
    state.currentCell = cell

    skip_cell(state)
    state.oas.cells[cellname_number] = state.currentCell
end

function skip_cell_str(state)
    cellname_string = read_string(state)
    cellname_number = _cellname_to_cellname_number(state, cellname_string)
    cell = LazyCell(state.pos, Dict())
    state.currentCell = cell

    skip_cell(state)
    state.oas.cells[cellname_number] = state.currentCell
end

function skip_placement(state)
    info_byte = read_byte(state)
    cellname_explicit = bit_is_nonzero(info_byte, 1)
    if cellname_explicit
        cellname_as_ref = bit_is_nonzero(info_byte, 2)
        if cellname_as_ref
            cellname_number = rui(state)
        else
            cellname = read_string(state)
            cellname_number = _cellname_to_cellname_number(state, cellname)
        end
        # Update the modal variable. We choose to always save the reference number instead of
        # the string.
        state.mod.placementCell = cellname_number
    else
        cellname_number = state.mod.placementCell
    end
    bit_is_nonzero(info_byte, 3) && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    if bit_is_nonzero(info_byte, 5)
        nrep = read_nrep(state)
    else
        nrep = 1
    end
    if haskey(state.currentCell.placements, cellname_number)
        state.currentCell.placements[cellname_number] += nrep
    else
        state.currentCell.placements[cellname_number] = nrep
    end
end

function skip_placement_mag_angle(state)
    info_byte = read_byte(state)
    cellname_explicit = bit_is_nonzero(info_byte, 1)
    if cellname_explicit
        cellname_as_ref = bit_is_nonzero(info_byte, 2)
        if cellname_as_ref
            cellname_number = rui(state)
        else
            cellname = read_string(state)
            cellname_number = _cellname_to_cellname_number(state, cellname)
        end
        # Update the modal variable. We choose to always save the reference number instead of
        # the string.
        state.mod.placementCell = cellname_number
    else
        cellname_number = state.mod.placementCell
    end
    bit_is_nonzero(info_byte, 6) && skip_real(state)
    bit_is_nonzero(info_byte, 7) && skip_real(state)
    bit_is_nonzero(info_byte, 3) && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    if bit_is_nonzero(info_byte, 5)
        nrep = read_nrep(state)
    else
        nrep = 1
    end
    if haskey(state.currentCell.placements, cellname_number)
        state.currentCell.placements[cellname_number] += nrep
    else
        state.currentCell.placements[cellname_number] = nrep
    end
end

function skip_text(state)
    info_byte = read_byte(state)
    if bit_is_nonzero(info_byte, 2)
        if bit_is_nonzero(info_byte, 3)
            skip_integer(state)
        else
            skip_string(state)
        end
    end
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_repetition(state)
end

function skip_rectangle(state)
    info_byte = read_byte(state)
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 2) && skip_integer(state)
    bit_is_nonzero(info_byte, 3) && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_repetition(state)
end

function skip_polygon(state)
    info_byte = read_byte(state)
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 3) && skip_point_list(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_repetition(state)
end

function skip_path(state)
    info_byte = read_byte(state)
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 2) && skip_integer(state)
    if bit_is_nonzero(info_byte, 1)
        extension_scheme = read_byte(state)
        if bit_is_nonzero(extension_scheme, 5) && bit_is_nonzero(extension_scheme, 6)
            skip_integer(state)
        end
        if bit_is_nonzero(extension_scheme, 7) && bit_is_nonzero(extension_scheme, 8)
            skip_integer(state)
        end
    end
    bit_is_nonzero(info_byte, 3) && skip_point_list(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_repetition(state)
end

function skip_trapezoid(state, delta_a_explicit::Bool, delta_b_explicit::Bool)
    info_byte = read_byte(state)
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 2) && skip_integer(state)
    bit_is_nonzero(info_byte, 3) && skip_integer(state)
    delta_a_explicit && skip_integer(state)
    delta_b_explicit && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_repetition(state)
end

function skip_ctrapezoid(state)
    info_byte = read_byte(state)
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 1) && skip_integer(state)
    bit_is_nonzero(info_byte, 2) && skip_integer(state)
    bit_is_nonzero(info_byte, 3) && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_repetition(state)
end

function skip_circle(state)
    info_byte = read_byte(state)
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 3) && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_integer(state)
end

function skip_property(state)
    info_byte = read_byte(state)
    if bit_is_nonzero(info_byte, 6)
        if bit_is_nonzero(info_byte, 7)
            skip_integer(state)
        else
            skip_string(state)
        end
    end
    if !bit_is_nonzero(info_byte, 5)
        number_of_values = info_byte >> 4
        if number_of_values == 0x0f
            number_of_values = rui(state)
        end
        for _ in 1:number_of_values
            skip_property_value(state)
        end
    end
end

function skip_cblock(state)
    skip_integer(state)
    skip_integer(state)
    comp_byte_count = rui(state)
    skip_bytes(state, comp_byte_count)
end
