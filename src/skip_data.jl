
function skip_integer(state)
    while true
        b = read_byte(state)
        b & 0x80 == 0 && return
    end
end

skip_ratio(state) = (skip_integer(state); skip_integer(state))

skip_four_byte_float(state) = state.pos += 4

skip_eight_byte_float(state) = state.pos += 8

function skip_real(state, format::UInt8)
    if format <= 0x03
        skip_integer(state)
    elseif format <= 0x05
        skip_ratio(state)
    elseif format == 0x06
        skip_four_byte_float(state)
    else
        skip_eight_byte_float(state)
    end
end

skip_real(state) = skip_real(state, read_byte(state))

function skip_string(state)
    length = rui(state)
    state.pos += length
end

function skip_property_value(state)
    type = read_byte(state)
    if type <= 0x07
        skip_real(state, type)
    elseif 0x0a <= type <= 0x0c
        skip_string(state)
    else
        skip_integer(state)
    end
end
