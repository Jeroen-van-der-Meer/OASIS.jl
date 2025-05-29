function read_or_modal(
    os::OasisStream,
    reader::Function,
    modal::Symbol,
    info_byte::UInt8,
    position::Int64
)
    if bit_is_nonzero(info_byte, position)
        v = reader(os.io)
        setproperty!(os.modals, modal, v)
        return v
    else
        return getproperty(os.modals, modal)
    end
end

function read_or_nothing(
    os::OasisStream,
    reader::Function,
    modal::Symbol,
    info_byte::UInt8,
    position::Int64
)
    if bit_is_nonzero(info_byte, position)
        v = reader(os.io)
        setproperty!(os.modals, modal, v)
        return v
    else
        return nothing
    end
end

function bit_is_nonzero(byte::UInt8, position)
    return isone(byte >> (8 - position) & 0x01)
end
