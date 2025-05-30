
function skip_integer(io::IO)
    while true
        b = read(io, UInt8)
        b & 0x80 == 0 && return
    end
end

skip_ratio(io::IO) = (skip_integer(io); skip_integer(io))

skip_four_byte_float(io::IO) = skip(io, 4)

skip_eight_byte_float(io::IO) = skip(io, 8)

const REAL_SKIPPER_PER_FORMAT = (
    skip_integer,
    skip_integer,
    skip_integer,
    skip_integer,
    skip_ratio,
    skip_ratio,
    skip_four_byte_float,
    skip_eight_byte_float
)

skip_real(io::IO, format::UInt8) = REAL_SKIPPER_PER_FORMAT[format + 1](io)

skip_real(io::IO) = skip_real(io, read(io, UInt8))

skip_string(io::IO) = skip(io, read(io, UInt8))

function skip_property_value(io::IO)
    type = read(io, UInt8)
    if type <= 0x07
        skip_real(io, type)
    elseif type <= 0x09
        skip_integer(io)
    else
        # Not clear to me if this is correct. Is propstring-reference-number encoded in the
        # same way as a string?
        skip_string(io)
    end
end
