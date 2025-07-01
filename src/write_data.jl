function wui(state, int::Unsigned) # write_unsigned_integer; using shorthand since this function is used often
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

function wui(state, int::Integer)
    @assert int >= 0
    wui(state, unsigned(int))
end

function write_signed_integer(state, int::Integer)
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

function write_real(state, real::Real)
    real_rounded = round(Int64, real)
    if real_rounded == real
        if real >= 0
            # Write positive whole number
            write_byte(state, 0x00)
            wui(state, real_rounded)
        else
            # Write negative whole number
            write_byte(state, 0x01)
            wui(state, -real_rounded)
        end
    else
        # Write Float64
        write_byte(state, 0x07)
        write_bytes(state, reinterpret(UInt64, real))
    end
end

function write_a_string(state, string::AbstractString) # a-string
    bytes = codeunits(string)
    nbytes = length(bytes)
    if !all(0x20 .<= bytes .<= 0x7e)
        @warn "Non-printable ASCII characters detected. Other software may not be able to read your output file."
    end
    wui(state, nbytes)
    write_bytes(state, bytes, nbytes)
end

function write_bn_string(state, string::AbstractString) # b-string and n-string
    bytes = codeunits(string)
    nbytes = length(bytes)
    if !all(0x21 .<= bytes .<= 0x7e)
        @warn "Non-printable ASCII characters detected. Other software may not be able to read your output file."
    end
    wui(state, nbytes)
    write_bytes(state, bytes, nbytes)
end

function write_interval_type_3(state, interval)
    write_byte(state, 3)
    wui(state, interval.low)
end

function write_interval_type_2(state, interval)
    write_byte(state, 2)
    wui(state, interval.low)
end

function write_interval_type_4(state, interval)
    write_byte(state, 4)
    wui(state, interval.low)
    wui(state, interval.high)
end

function write_interval(state, interval::Interval)
    if interval.low == interval.high
        write_interval_type_3(state, interval)
    elseif interval.high == typemax(UInt64)
        write_interval_type_2(state, interval)
    else
        write_interval_type_4(state, interval)
    end
end

function write_bytes(state, bytes::AbstractVector{UInt8}, nbytes::Integer = length(bytes))
    count = 0
    while true
        writeable = state.bufsize - state.pos + 1
        # If there's enough space, simply write out all bytes into the buffer.
        if writeable > nbytes - count
            @inbounds state.buf[state.pos:(state.pos + nbytes - count - 1)] .=
                bytes[(count + 1):end]
            state.pos += nbytes - count
            return
        # If not, write out until the end of the buffer, flush the buffer, then continue.
        else
            @inbounds state.buf[state.pos:(state.pos + writeable - 1)] .=
                bytes[(count + 1):(count + writeable)]
            write_buffer(state)
            count += writeable
        end
    end
end

function write_bytes(state, uint::UInt64)
    b = UInt8(uint & 0xff)
    write_byte(state, b)
    for _ in 1:7
        uint >>= 8
        b = UInt8(uint & 0xff)
        write_byte(state, b)
    end
end

write_byte(state, byte::Integer) = write_byte(state, UInt8(byte))

function write_byte(state, byte::UInt8)
    @inbounds state.buf[state.pos] = byte
    if state.pos == state.bufsize
        write_buffer(state)
    else
        state.pos += 1
    end
end

function write_buffer(state)
    write(state.io, state.buf)
    state.pos = 1
end
