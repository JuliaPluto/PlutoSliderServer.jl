import PlutoSliderServer
import PlutoSliderServer: bound_variable_connections_graph
import PlutoSliderServer.Pluto

using Test

@testset "Bond connections" begin
    file = joinpath(@__DIR__, "parallelpaths4.jl")

    newpath = tempname()
    Pluto.readwrite(file, newpath)

    notebook = Pluto.load_notebook(newpath)
    # Run pluto's analysis. This is like opening the notebook, without actually running it
    # s = Pluto.ServerSession()
    # Pluto.update_save_run!(s, notebook, notebook.cells; run)
    notebook.topology = Pluto.updated_topology(notebook.topology, notebook, notebook.cells)

    # bound_variables = (map(notebook.cells) do cell
    #     MoreAnalysis.find_bound_variables(cell.parsedcode)
    # end)

    # @show bound_variables

    connections = bound_variable_connections_graph(notebook)
    # @show connections

    @test !isempty(connections)
    wanted_connections = Dict(
        :x         => [:y, :x],
        :y         => [:y, :x],
        :show_dogs => [:show_dogs],
        :b         => [:b],
        :c         => [:c],
        :five1     => [:five1],
        :five2     => [:five2],
        :six1      => [:six2, :six1],
        :six2      => [:six3, :six2, :six1],
        :six3      => [:six3, :six2],
        :cool1     => [:cool1, :cool2],
        :cool2     => [:cool1, :cool2],
        :world     => [:world],
        :boring    => [:boring],
    )

    transform(d) = Dict(k => sort(v) for (k, v) in d)

    @test transform(connections) == transform(wanted_connections)
end