function read_and_reset(state, nbytes::Integer)
    l = state.buf[1:nbytes]
    state.pos = 1
    return l
end

@testset "Write data" begin
    state = OasisTools.WriterState("temp", 1024 * 1024)
    @testset "Write unsigned integers" begin
        OasisTools.wui(state, 0)
        @test read_and_reset(state, 1) == [0x00]
        OasisTools.wui(state, 127)
        @test read_and_reset(state, 1) == [0x7f]
        OasisTools.wui(state, 128)
        @test read_and_reset(state, 2) == [0x80, 0x01]
        OasisTools.wui(state, 16383)
        @test read_and_reset(state, 2) == [0xff, 0x7f]
        OasisTools.wui(state, 16384)
        @test read_and_reset(state, 3) == [0x80, 0x80, 0x01]
    end
    @testset "Write signed integers" begin
        OasisTools.write_signed_integer(state, 0)
        @test read_and_reset(state, 1) == [0x00]
        OasisTools.write_signed_integer(state, 1)
        @test read_and_reset(state, 1) == [0x02]
        OasisTools.write_signed_integer(state, -1)
        @test read_and_reset(state, 1) == [0x03]
        OasisTools.write_signed_integer(state, 63)
        @test read_and_reset(state, 1) == [0x7e]
        OasisTools.write_signed_integer(state, -64)
        @test read_and_reset(state, 2) == [0x81, 0x01]
        OasisTools.write_signed_integer(state, 8191)
        @test read_and_reset(state, 2) == [0xfe, 0x7f]
        OasisTools.write_signed_integer(state, -8192)
        @test read_and_reset(state, 3) == [0x81, 0x80, 0x01]
    end
end
