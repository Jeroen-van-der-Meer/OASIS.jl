function read_or_modal(
    io::IO,
    modals::ModalVariables,
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

function read_or_nothing(
    io::IO,
    modals::ModalVariables,
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
