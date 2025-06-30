skip_record(state::AbstractParserState) = return

function skip_propname_impl(state::ParserState)
    skip_string(state)
end

function skip_propname_ref(state::ParserState)
    skip_string(state)
    skip_integer(state)
end

function skip_propstring_impl(state::ParserState)
    skip_string(state)
end

function skip_propstring_ref(state::ParserState)
    skip_string(state)
    skip_integer(state)
end

function skip_placement(state::LazyCellParserState)
    info_byte = read_byte(state)
    cellname_explicit = bit_is_nonzero(info_byte, 1)
    if cellname_explicit
        cellname_as_ref = bit_is_nonzero(info_byte, 2)
        if cellname_as_ref
            cellname_number = rui(state)
        else
            cellname = read_string(state)
            cellname_number = _find_or_make_reference(state.oas.references.cellNames, cellname)
        end
        # Update the modal variable. We choose to always save the reference number instead of
        # the string.
        state.mod.placementCell = cellname_number
    else
        cellname_number = state.mod.placementCell
    end
    bit_is_nonzero(info_byte, 3) && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    nrep = read_nrep(state, info_byte, 5)
    if haskey(state.placements, cellname_number)
        state.placements[cellname_number] += nrep
    else
        state.placements[cellname_number] = nrep
    end
end

function skip_placement_mag_angle(state::LazyCellParserState)
    info_byte = read_byte(state)
    cellname_explicit = bit_is_nonzero(info_byte, 1)
    if cellname_explicit
        cellname_as_ref = bit_is_nonzero(info_byte, 2)
        if cellname_as_ref
            cellname_number = rui(state)
        else
            cellname = read_string(state)
            cellname_number = _find_or_make_reference(state.oas.references.cellNames, cellname)
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
    nrep = read_nrep(state, info_byte, 5)
    if haskey(state.placements, cellname_number)
        state.placements[cellname_number] += nrep
    else
        state.placements[cellname_number] = nrep
    end
end

function skip_text(state::LazyCellParserState)
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

function skip_rectangle(state::LazyCellParserState)
    info_byte = read_byte(state)
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 2) && skip_integer(state)
    bit_is_nonzero(info_byte, 3) && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_repetition(state)
end

function skip_polygon(state::LazyCellParserState)
    info_byte = read_byte(state)
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 3) && skip_point_list(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_repetition(state)
end

function skip_path(state::LazyCellParserState)
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

function skip_trapezoid(state::LazyCellParserState, delta_a_explicit::Bool, delta_b_explicit::Bool)
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

function skip_ctrapezoid(state::LazyCellParserState)
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

function skip_circle(state::LazyCellParserState)
    info_byte = read_byte(state)
    bit_is_nonzero(info_byte, 8) && skip_integer(state)
    bit_is_nonzero(info_byte, 7) && skip_integer(state)
    bit_is_nonzero(info_byte, 3) && skip_integer(state)
    bit_is_nonzero(info_byte, 4) && skip_integer(state)
    bit_is_nonzero(info_byte, 5) && skip_integer(state)
    bit_is_nonzero(info_byte, 6) && skip_integer(state)
end

function skip_property(state::AbstractParserState)
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
