function wui(state, int::UInt64) # write_unsigned_integer; using shorthand since this function is used often
    more_bytes_needed = true
    while more_bytes_needed
        b = UInt8(int & 0x7f)
        int >>= 7
        if iszero(int)
            more_bytes_needed = false
        else
            b |= 0x80 # Use first bit to mark that there are more bytes to come
        end
        write_byte(state, b)
    end
end

function wui(state, int::Int64)
    @assert int >= 0
    wui(state, unsigned(int))
end

function write_signed_integer(state, int::Int64)
    is_neg = int < 0
    uint = is_neg ? unsigned(-int) : unsigned(int)
    b = UInt8((uint & 0x3f) << 1)
    b |= is_neg # Use the last bit to indicate whether the represented number is negative
    uint >>= 6
    if iszero(uint)
        write_byte(state, b)
        return
    else
        b |= 0x80 # Use first bit to mark that there are more bytes to come
        write_byte(state, b)
        wui(state, uint)
    end
end

function write_byte(state, byte::UInt8)
    @inbounds state.buf[state.pos] = byte
    if state.pos == state.buflen
        write(state.io, buf)
        state.pos = 1
    else
        state.pos += 1
    end
end