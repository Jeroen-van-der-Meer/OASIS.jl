using Makie

@testset "Plots" begin
    filename = "polygon.oas" # 130.900 μs (86 allocations: 4.84 KiB)
    filepath = joinpath(@__DIR__, "testdata", filename)
    oas = oasisread(filepath)
    fig = plot_cell(oas["TOP"])
    @test fig isa Makie.Figure
end
