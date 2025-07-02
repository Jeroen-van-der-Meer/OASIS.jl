function write_new_reference(
    state::WriterState,
    cell::LazyCell,
    cell_parser_state::LazyCellParserState,
    info_byte::UInt8,
    byte_position::Integer,
    references::Vector{NumericReference}
)
    # When writing a LazyCell, we must be careful to update any TEXT and PLACEMENT records,
    # because these contain internal references to a text string and cell name, respectively,
    # and this reference may have changed. We opt to log a reference number when possible, and to
    # base this reference number on the (fixed) index of the corresponding reference as stored
    # in the Oasis object.

    # We read the original reference (which can either be a string or a number) and figure out
    # the new reference number that has to be written.
    if bit_is_one(info_byte, byte_position) # Reference is explicit
        if bit_is_one(info_byte, byte_position + 1) # Reference is in the form of a number
            number = rui(cell_parser_state)
            # If the reference is in the form of a number, that means a reference matching the
            # number to a string must have existed elsewhere in the original file, and we are
            # guaranteed to have catalogued this reference while parsing the file. Therefore,
            # we know that a reference is guaranteed to be found.
            new_number = find_reference(cell.source, number, references) - 1
            write_byte(state, info_byte)
            wui(state, new_number)
        else # Reference is in the form of a string
            name = read_string(cell_parser_state)
            ref_index = find_reference(cell.source, name, references)
            if isnothing(ref_index)
                # It is possible for the string to not exist in the list of references. This
                # can only occur for TEXT records with explicit strings in lazy-loaded cells.
                write_byte(state, info_byte)
                write_a_string(state, name)
            else
                # Change the bit indicating that the reference was a string, because we choose
                # to store a number instead.
                info_byte = set_bit_to_one(info_byte, byte_position + 1)
                write_byte(state, info_byte)
                new_number = ref_index - 1
                wui(state, new_number)
            end
        end
    else
        # If the bit at `byte_position` is 0, then a modal variable is used to refer to the
        # right text string / cell name. Since our LazyCell writer writes sequentially, we can
        # be sure that the value of this modal variable will be correct by the time it reaches
        # this record.
        write_byte(state, info_byte)
        return
    end
end

function set_bit_to_one(byte::UInt8, position::Integer)
    byte |= (0x01 << (8 - position))
end