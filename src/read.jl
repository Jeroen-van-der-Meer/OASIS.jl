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

function unsigned_to_signed(x::UInt64)
    sign = x & one(UInt64)
    output = signed(x >> 1)
    iszero(sign) ? output : -output
end

function read_signed_integer(io::IO)
    unsigned_output = read_unsigned_integer(io)
    return unsigned_to_signed(unsigned_output)
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

function read_string(io::IO)
    length = read(io, UInt8)
    s = read(io, length)
    return String(s)
end

function read_1_delta(io::IO, dir)
    # dir 0: east/west; dir 1: north/south
    mag = read_signed_integer(io)
    return iszero(dir) ? (mag, 0) : (0, mag)
end

east_integer(mag::UInt64) = (signed(mag), 0)
north_integer(mag::UInt64) = (0, signed(mag))
west_integer(mag::UInt64) = (-signed(mag), 0)
south_integer(mag::UInt64) = (0, -signed(mag))
northeast_integer(mag::UInt64) = (signed(mag), signed(mag))
northwest_integer(mag::UInt64) = (-signed(mag), signed(mag))
southwest_integer(mag::UInt64) = (-signed(mag), -signed(mag))
southeast_integer(mag::UInt64) = (signed(mag), -signed(mag))

const DELTA_READER_PER_DIRECTION = (
    east_integer,
    north_integer,
    west_integer,
    south_integer,
    northeast_integer,
    northwest_integer,
    southwest_integer,
    southeast_integer
)

function read_2_delta(io::IO)
    Δ = read_unsigned_integer(io)
    dir = Δ & 0x03 + 1 # Last 2 bits
    magnitude = Δ >> 2 # Remaining bits
    return DELTA_READER_PER_DIRECTION[dir](magnitude)
end

function read_3_delta(Δ::UInt64)
    dir = Δ & 0x07 + 1 # Last 3 bits
    magnitude = Δ >> 3 # Remaining bits
    return DELTA_READER_PER_DIRECTION[dir](magnitude)
end

function read_3_delta(io::IO)
    Δ = read_unsigned_integer(io)
    return read_3_delta(Δ)
end

function read_g_delta(io::IO)
    Δ = read_unsigned_integer(io)
    form = Δ & 0x01 # Last bit
    Δ >>= 1
    # g-delta comes in two forms
    if form == 0x00
        return read_3_delta(Δ) # Remaining bits to be read out as 3-delta
    else
        Δ2 = read_unsigned_integer(io)
        return (unsigned_to_signed(Δ), unsigned_to_signed(Δ2))
    end
end

read_1_delta_list_horizontal_first(io::IO, vc::UInt8) = [read_1_delta(io, i % 2) for i in 0:(vc - 1)]
read_1_delta_list_vertical_first(io::IO, vc::UInt8) = [read_1_delta(io, i % 2) for i in 1:vc]
read_2_delta_list(io::IO, vc::UInt8) = [read_2_delta(io) for _ in 1:vc]
read_3_delta_list(io::IO, vc::UInt8) = [read_3_delta(io) for _ in 1:vc]

const POINT_LIST_READ_PER_TYPE = (
    read_1_delta_list_horizontal_first,
    read_1_delta_list_vertical_first,
    read_2_delta_list,
    read_3_delta_list,
    #read_g_delta_list,
    #read_g_double_delta_list
)

function read_point_list(io::IO)
    type = read(io, UInt8) + 1
    vertex_count = read(io, UInt8)
    return POINT_LIST_READ_PER_TYPE[type](io, vertex_count)
end
