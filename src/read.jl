function read_unsigned_integer(io::IO)
    output = 0
    shift = 0
    while true
        b = read(io, UInt8)
        output += UInt64(b & 0x7F) << shift
        b & 0x80 == 0 && break
        shift += 7
    end
    return output
end

function read_signed_integer(io::IO)
    unsigned_output = read_unsigned_integer(io)
    sign = unsigned_output & one(UInt64)
    output = signed(unsigned_output >> 1)
    iszero(sign) ? output : -output
end

read_positive_whole_number(io::IO) = signed(read_unsigned_integer(io))
read_negative_whole_number(io::IO) = -signed(read_unsigned_integer(io))
read_positive_reciprocal(io::IO) = 1 / read_unsigned_integer(io)
read_negative_reciprocal(io::IO) = -1 / read_unsigned_integer(io)
read_positive_ratio(io::IO) = read_positive_whole_number(io) / read_positive_whole_number(io)
read_negative_ratio(io::IO) = read_negative_whole_number(io) / read_positive_whole_number(io)
read_four_byte_float(io::IO) = Float64(read(io, Float32))
read_eight_byte_float(io::IO) = read(io, Float64)

const REAL_READER_PER_FORMAT = (
    read_positive_whole_number,
    read_negative_whole_number,
    read_positive_reciprocal,
    read_negative_reciprocal,
    read_positive_ratio,
    read_negative_ratio,
    read_four_byte_float,
    read_eight_byte_float
)

function read_real(io::IO)
    real_format = read(io, UInt8) + 1
    return REAL_READER_PER_FORMAT[real_format](io)
end


