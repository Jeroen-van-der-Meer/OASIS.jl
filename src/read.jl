function rui(io::IO) # read_unsigned_integer; using shorthand since this function is used often
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
    unsigned_output = rui(io)
    return unsigned_to_signed(unsigned_output)
end

read_positive_whole_number(io::IO) = signed(rui(io))
read_negative_whole_number(io::IO) = -signed(rui(io))
read_positive_reciprocal(io::IO) = 1 / rui(io)
read_negative_reciprocal(io::IO) = -1 / rui(io)
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

function read_real(io::IO, format::UInt8)
    return REAL_READER_PER_FORMAT[format + 1](io)
end

function read_real(io::IO)
    format = read(io, UInt8)
    return read_real(io, format)
end

function read_string(io::IO)
    length = read(io, UInt8)
    s = read(io, length)
    return String(s)
end

function read_1_delta(io::IO, dir)
    # dir 0: east/west; dir 1: north/south
    mag = read_signed_integer(io)
    return iszero(dir) ? Point{2, Int64}(mag, 0) : Point{2, Int64}(0, mag)
end

east_integer(mag::UInt64) = Point{2, Int64}(signed(mag), 0)
north_integer(mag::UInt64) = Point{2, Int64}(0, signed(mag))
west_integer(mag::UInt64) = Point{2, Int64}(-signed(mag), 0)
south_integer(mag::UInt64) = Point{2, Int64}(0, -signed(mag))
northeast_integer(mag::UInt64) = Point{2, Int64}(signed(mag), signed(mag))
northwest_integer(mag::UInt64) = Point{2, Int64}(-signed(mag), signed(mag))
southwest_integer(mag::UInt64) = Point{2, Int64}(-signed(mag), -signed(mag))
southeast_integer(mag::UInt64) = Point{2, Int64}(signed(mag), -signed(mag))

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

function read_2_delta(Δ::UInt64)
    dir = Δ & 0x03 # Last 2 bits
    magnitude = Δ >> 2 # Remaining bits
    return DELTA_READER_PER_DIRECTION[dir + 1](magnitude)
end

read_2_delta(io::IO) = read_2_delta(rui(io))

function read_3_delta(Δ::UInt64)
    dir = Δ & 0x07 # Last 3 bits
    magnitude = Δ >> 3 # Remaining bits
    return DELTA_READER_PER_DIRECTION[dir + 1](magnitude)
end

read_3_delta(io::IO) = read_3_delta(rui(io))

function read_g_delta(io::IO)
    Δ = rui(io)
    form = Δ & 0x01 # Last bit
    Δ >>= 1
    # g-delta comes in two forms
    if form == 0x00
        return read_3_delta(Δ) # Remaining bits to be read out as 3-delta
    else
        Δ2 = rui(io)
        return Point{2, Int64}(unsigned_to_signed(Δ), unsigned_to_signed(Δ2))
    end
end

struct PointGridRange <: AbstractRange{Point2i}
    start::Point2i
    nstepx::Int64
    nstepy::Int64
    stepx::Point2i
    stepy::Point2i
end
Base.first(r::PointGridRange) = r.start
Base.step(r::PointGridRange) = (r.stepx, r.stepy)
Base.last(r::PointGridRange) = r.start + (r.nstepx - 1) * r.stepx + (r.nstepy - 1) * r.stepy
function Base.getindex(r::PointGridRange, i::Integer)
    1 <= i <= length(r) || throw(BoundsError(r, i))
    s1 = r.nstepx
    ix = rem(i - 1, s1)
    iy = div(i - 1, s1)
    return r.start + ix * r.stepx + iy * r.stepy
end
function Base.getindex(r::PointGridRange, i::Integer, j::Integer)
    s1, s2 = size(r)
    1 <= i <= s1 || throw(BoundsError(r, [i, j]))
    1 <= j <= s2 || throw(BoundsError(r, [i, j]))
    return r.start + (i - 1) * r.stepx + (j - 1) * r.stepy
end
Base.size(r::PointGridRange) = (r.nstepx, r.nstepy)
Base.length(r::PointGridRange) = prod(size(r))
function Base.iterate(r::PointGridRange, i::Integer = zero(length(r)))
    i += oneunit(i)
    length(r) < i && return nothing
    r[i], i
end

collect_repetitions_x(io, nrep; grid::Int64 = 1) = pushfirst!(grid .* cumsum([Point{2, Int64}(rui(io), 0) for _ in 1:(nrep - 1)]), (0, 0))
collect_repetitions_y(io, nrep; grid::Int64 = 1) = pushfirst!(grid .* cumsum(pushfirst!([Point{2, Int64}(0, rui(io)) for _ in 1:(nrep - 1)])), (0, 0))
collect_repetitions_g(io, nrep; grid::Int64 = 1) = pushfirst!(grid .* cumsum(pushfirst!([read_g_delta(io) for _ in 1:(nrep - 1)])), (0, 0))

read_repetition_type_0(io::IO) = @error "Not implemented" # To be dealt with when we have modal vars
read_repetition_type_1(io::IO) = PointGridRange((0, 0), rui(io) + 2, rui(io) + 2, (rui(io), 0), (0, rui(io)))
read_repetition_type_2(io::IO) = PointGridRange((0, 0), rui(io) + 2, 1, (rui(io), 0), (1, 1))
read_repetition_type_3(io::IO) = PointGridRange((0, 0), 1, rui(io) + 2, (1, 1), (0, rui(io)))
read_repetition_type_4(io::IO) = collect_repetitions_x(io, rui(io) + 2)
read_repetition_type_5(io::IO) = collect_repetitions_x(io, rui(io) + 2; grid = signed(rui(io)))
read_repetition_type_6(io::IO) = collect_repetitions_y(io, rui(io) + 2)
read_repetition_type_7(io::IO) = collect_repetitions_y(io, rui(io) + 2; grid = signed(rui(io)))
read_repetition_type_8(io::IO) = PointGridRange((0, 0), rui(io) + 2, rui(io) + 2, read_g_delta(io), read_g_delta(io))
read_repetition_type_9(io::IO) = PointGridRange((0, 0), rui(io) + 2, 1, read_g_delta(io), (1, 1))
read_repetition_type_10(io::IO) = collect_repetitions_g(io, rui(io) + 2)
read_repetition_type_11(io::IO) = collect_repetitions_g(io, rui(io) + 2; grid = signed(rui(io)))

const REPETITION_READER_PER_TYPE = (
    read_repetition_type_0,
    read_repetition_type_1,
    read_repetition_type_2,
    read_repetition_type_3,
    read_repetition_type_4,
    read_repetition_type_5,
    read_repetition_type_6,
    read_repetition_type_7,
    read_repetition_type_8,
    read_repetition_type_9,
    read_repetition_type_10,
    read_repetition_type_11
)

function read_repetition(io::IO)
    type = read(io, UInt8)
    return REPETITION_READER_PER_TYPE[type + 1](io)
end

read_1_delta_list_horizontal_first(io::IO, vc::UInt8) = [read_1_delta(io, i % 2) for i in 0:(vc - 1)]
read_1_delta_list_vertical_first(io::IO, vc::UInt8) = [read_1_delta(io, i % 2) for i in 1:vc]
read_2_delta_list(io::IO, vc::UInt8) = [read_2_delta(io) for _ in 1:vc]
read_3_delta_list(io::IO, vc::UInt8) = [read_3_delta(io) for _ in 1:vc]
read_g_delta_list(io::IO, vc::UInt8) = [read_g_delta(io) for _ in 1:vc]

const POINT_LIST_READER_PER_TYPE = (
    read_1_delta_list_horizontal_first,
    read_1_delta_list_vertical_first,
    read_2_delta_list,
    read_3_delta_list,
    read_g_delta_list,
    cumsum ∘ read_g_delta_list
)

function read_point_list(io::IO)
    type = read(io, UInt8)
    vertex_count = read(io, UInt8)
    return POINT_LIST_READER_PER_TYPE[type + 1](io, vertex_count)
end

function read_property_value(io::IO)
    type = read(io, UInt8)
    if type <= 0x07
        return read_real(io, type)
    elseif type == 0x08
        return rui(io)
    elseif type == 0x09
        return read_signed_integer(io)
    elseif type <= 0x0f
        # Not clear to me if this is correct. Is propstring-reference-number encoded in the
        # same way as a string?
        return read_string(io)
    end
end
