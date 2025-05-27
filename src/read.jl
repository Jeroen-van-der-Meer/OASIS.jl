function read_unsigned_integer(buf; pos::Int = 1)
    output = 0
    shift = 0
    while true
        b = get_byte(buf, pos)
        output += UInt64(b & 0x7F) << shift
        b & 0x80 == 0 && break
        pos += 1
        shift += 7
    end
    return output
end

function read_signed_integer(buf; pos::Int = 1)
    unsigned_output = read_unsigned_integer(buf; pos)
    sign = unsigned_output & one(UInt64)
    output = signed(unsigned_output >> 1)
    iszero(sign) ? output : -output
end

function get_byte(buf::AbstractVector{UInt8}, pos::Int)
    @inbounds b = buf[pos]
    return b
end
