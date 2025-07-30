@testset "Manipulate OASIS objects" begin
    @testset "Add cells" begin
        oas = Oasis()
        add_cell!(oas, :NEW)
        @test oas[:NEW] isa Cell
        @test OasisTools.unit(oas[:NEW]) == OasisTools.DEFAULT_UNIT
        @test_throws Exception add_cell!(oas, :NEW)
    end
    @testset "Add layers" begin
        oas = Oasis()
        add_layer!(oas, :M0, 1, 0)
        add_layer!(oas, Layer("V0", 1, 1))
        add_layer!(oas, Layer("V0", OasisTools.Interval(2, 3), 2))
        @test_throws Exception add_layer!(oas, :M0, OasisTools.Interval(1, 2), OasisTools.Interval(0, 1))
    end
    @testset "Merge files" begin
        oas = Oasis()
        add_cell!(oas, :TOP1)
        add_layer!(oas, :M0, 1, 0)
        add_layer!(oas, :V0, 2, 0)
        oas2 = Oasis()
        add_cell!(oas2, :TOP1)
        add_cell!(oas2, :TOP2)
        add_layer!(oas2, :Metal0, 1, 0)
        add_layer!(oas2, :V0, 2, OasisTools.Interval(0, 1))
        merge_oases!(oas, oas2)
        @test length(cell_names(oas)) == 2
        @test name(layer(oas, 1, 0)) == Symbol("M0, Metal0")
        @test name(layer(oas, 2, 1)) == :V0
    end
end