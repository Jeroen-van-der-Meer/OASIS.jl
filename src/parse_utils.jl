function read_or_modal(
    io::IO,
    reader::Function,
    modal::Symbol,
    info_byte::UInt8,
    position::Int64
)
    if bit_is_nonzero(info_byte, position)
        v = reader(io)
        setproperty!(modals, modal, v)
        return v
    else
        return getproperty(modals, modal)
    end
end

# If an x or y value is parsed, we require logic to deal with the current value of xy-mode.
function read_or_modal_xy(
    io::IO,
    #reader::Function, # The reader is always read_signed_integer.
    modalX::Symbol,
    modalY::Symbol,
    info_byte::UInt8,
    position::Int64 # Position of bit determining x-value; the y-value is always the next bit.
)
    if modals.xyAbsolute
        x = read_or_modal(io, read_signed_integer, modalX, info_byte, position)
        y = read_or_modal(io, read_signed_integer, modalY, info_byte, position + 1)
    else
        if bit_is_nonzero(info_byte, position)
            x = read_signed_integer(io) + getproperty(modals, X)
            setproperty!(modals, modalX, x)
        else
            x = getproperty(modals, modalX)
        end
        if bit_is_nonzero(info_byte, position + 1)
            y = read_signed_integer(io) + getproperty(modals, modalX)
            setproperty!(modals, modalY, y)
        else
            y = getproperty(modals, modalY)
        end
    end
    return x, y
end

function read_or_nothing(
    io::IO,
    reader::Function,
    modal::Symbol,
    info_byte::UInt8,
    position::Int64
)
    if bit_is_nonzero(info_byte, position)
        v = reader(io)
        setproperty!(modals, modal, v)
        return v
    else
        return nothing
    end
end

function bit_is_nonzero(byte::UInt8, position)
    return isone(byte >> (8 - position) & 0x01)
end

# PLACEMENT records can either use CELLNAME references or strings to refer to what cell is being
# placed. For consistency, we wish to always log a reference number. However, there is no
# guarantee that such reference exists, so we'll have to manually create it.
function cellname_to_cellname_number(cellname::String)
    cellname_number = find_reference(number, oas.references.cellNames)
    if isnothing(cellname_number)
        cellname_number = rand(UInt64)
        push!(oas.references.cellNames, NumericReference(cellname, cellname_number))
    end
end
