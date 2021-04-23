module Webhook
    export register_webhook!

    using FromFile
    @from "./Actions.jl" using Actions
    using HTTP

    # This function wraps our functions with PlutoSliderServer context. run_server & start_dir are set by the webhook options.
    function register_webhook!(router, notebook_sessions, server_session, settings, static_dir)


        function reload_filesystem(request::HTTP.Request)
            # Need to save configuration
            if get(ENV, "GITHUB_SECRET", "") !== ""
                security_test = validate_github_headers(request, ENV["GITHUB_SECRET"])
                if !security_test
                    return HTTP.Response(501, "Not authorized!")
                end
            end

            params = HTTP.queryparams(HTTP.URI(request.target))
            github_url = get(get(JSON.parse(String(request.body)), "repository", Dict()), "html_url", nothing)
            folder = !isnothing(github_url) ? split(github_url, "/")[end] : "spam"
            exclude_hases = get(params, "exclude", [])
            @async try
                if length(folder) > 0 
                    toclone = github_url
                    this_folder = pwd()
                    @info this_folder
                    run(`rm -rf "$folder"`)
                    # Clone without history
                    # Fetch/Pull if you have latest
                    # Also have some cleanup around!
                    run(`git clone --depth 1 "$toclone"`)
                else 
                    return HTTP.Response(501, "Can't pull")
                end
                start_dir = "$this_folder/$folder"

                @info "New Settings" Text(settings)

                paths = [path for path in find_notebook_files_recursive(start_dir) if !isnothing(path)]
                new_hashes = map(path_hash, paths)

                running_hashes = map(notebook_sessions) do sesh
                    sesh isa RunningNotebookSession ? sesh.hash : nothing
                end

                to_delete = [h for h in running_hashes if !(h ∈ new_hashes) && !isnothing(h)]
                to_start = [h for h in new_hashes if !(h ∈ running_hashes) && !isnothing(h)]
                to_run = [p for p in paths if (path_hash(p) ∈ to_start)]
                @info "delete" to_delete
                @info "start" to_start
                @info "to run: " to_run
                for hash in to_delete
                    remove_from_session!(notebook_sessions, server_session, hash)
                end

                for hash in to_start
                    runpath = paths[findfirst(h -> hash === h, new_hashes)]
                    add_to_session!(notebook_sessions, server_session, path, settings, run_server=true, start_dir)
                    @info "started" runpath
                    generate_static_export(path, settings, original_state=nothing, output_dir=".", jl_contents=nothing)
                end
                # Create index!
                if settings.SliderServer.serve_static_export_folder && settings.Export.create_index
                    output_dir = something(ENV["current_root"], settings.Export.output_dir, "$start_dir")
                    write(joinpath(output_dir, "index.html"), default_index((
                        without_pluto_file_extension(path) => without_pluto_file_extension(path) * ".html"
                        for path in to_run
                    )))
                    @info "Wrote index to" output_dir
                end
                @info "run successully!"
            catch e
                @warn "Fail in reloading " e
                showerror(stderr, e, stacktrace(catch_backtrace()))
                rethrow(e)
             HTTP.Response(503, "Failed to reload")
             finally
            end
            sleep(max(rand(), 0.1)) # That's both trigger async AND protection against timing attacks :O
            return HTTP.Response(200, "Webhook accepted, async job started!")

        end
        # Register Webhook
        HTTP.@register(router, "POST", "/github_webhook/", reload_filesystem)

        if static_dir === nothing
            function serve_pluto_asset(request::HTTP.Request)
                uri = HTTP.URI(request.target)
                
                filepath = Pluto.project_relative_path("frontend", relpath(HTTP.unescapeuri(uri.path), "/pluto_asset/"))
                Pluto.asset_response(filepath)
            end
            HTTP.@register(router, "GET", "/pluto_asset/*", serve_pluto_asset)
            function serve_asset(request::HTTP.Request)
                uri = HTTP.URI(request.target)
                
                filepath = joinpath(static_dir, relpath(HTTP.unescapeuri(uri.path), "/"))
                Pluto.asset_response(filepath)
            end
            HTTP.@register(router, "GET", "/*", serve_asset)
        end
    end




    function validate_github_headers(request, secret=ENV["GITHUB_SECRET"])
        i = findfirst(a -> lowercase(a.first) == lowercase("X-Hub-Signature-256"), request.headers)
        if (isnothing(i))
            @warn "Can't validate: header not found"
            return false
        end
        secure_header = request.headers[i].second
        digest = "sha256=" * bytes2hex(hmac_sha256(collect(codeunits(secret)), request.body))
        security_test = digest == secure_header
        sleep(max(0.1, rand()/2))
        if !security_test
            return HTTP.Response(501, "Not authorized!")
        end
        return security_test
    end

end