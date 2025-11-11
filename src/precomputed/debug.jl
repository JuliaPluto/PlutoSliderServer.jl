
# this file is included in src/PlutoSliderServer.jl
# yolo

import Pluto: Pluto, @asynclog, tamepath, is_pluto_notebook
import Configurations
using FromFile

@from "./index.jl" import variable_groups, generate_precomputed_staterequests_report
@from "../Types.jl" import RunningNotebook
@from "../Configuration.jl" import PlutoDeploySettings
@from "../MoreAnalysis.jl" import bound_variable_connections_graph


function start_debugging(notebook_path::String; kwargs...)
    notebook_path = tamepath(notebook_path)
    @assert is_pluto_notebook(notebook_path)

    settings = Configurations.from_kwargs(PlutoDeploySettings; kwargs...)


    @info "Running notebook..."

    pluto_session = Pluto.ServerSession(; options=settings.Pluto)
    notebook = Pluto.SessionActions.open(pluto_session, notebook_path; run_async=false)

    @info "Notebook ready! Starting server..."

    pluto_session.options.server.show_file_system = false
    t = @asynclog Pluto.run(pluto_session)
    sleep(1)

    repeat = true
    while repeat
        connections = bound_variable_connections_graph(notebook)

        run = RunningNotebook(;
            path=notebook_path,
            notebook=notebook,
            bond_connections=connections,
            original_state=Pluto.notebook_to_js(notebook),
        )

        groups = variable_groups(connections; pluto_session, notebook=run.notebook)

        report =
            generate_precomputed_staterequests_report(groups, run; settings, pluto_session)

        for _ = 1:first(displaysize(stdout))
            println(stdout)
        end
        show(stdout, MIME"text/plain"(), report)
        println(stdout)
        println(stdout)


        repeat = Base.prompt("Run again? (y/n)"; default="y") == "y"
    end

    wait(t)

end