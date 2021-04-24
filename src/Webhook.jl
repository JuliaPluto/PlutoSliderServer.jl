module Webhook
    export register_webhook!

    using FromFile
    @from "Actions.jl" using Actions
    @from "Types.jl" using Types
    @from "FileHelpers.jl" import FileHelpers: find_notebook_files_recursive
    @from "Export.jl" import Export: default_index
    import Pluto: without_pluto_file_extension
    using HTTP

    # This function wraps our functions with PlutoSliderServer context. run_server & start_dir are set by the webhook options.
    function register_webhook!(router, notebook_sessions, server_session, settings, static_dir)

        """
        Handle any events from GitHub.
        Use with Webhook - see README for detailed HOWTO
        This function assumes you run slider server from a GitHub repository.
        When invoked (POST @ /github_webhook endpoint, properly authenticated)
        the server will try to
            - reload all changed files,
            - stop all deleted files and
            - start any new files
        respecting the settings (exlusions etc.)

        TODO: restart julia process if settings (assumed to be at
        `pluto-deployment-environment/PlutoDeployment.toml`) change.
        """
        function pull(request::HTTP.Request)
            # Need to save configuration
            if get(ENV, "GITHUB_SECRET", "") !== ""
                security_test = validate_github_headers(request, ENV["GITHUB_SECRET"])
                if !security_test
                    return HTTP.Response(501, "Not authorized!")
                end
            end

            # github_url = get(get(JSON.parse(String(request.body)), "repository", Dict()), "html_url", nothing)
            @async try
                run(`git pull`)
                # run(`git checkout`)
                config_toml_path = joinpath(Base.active_project() |> dirname, "PlutoDeployment.toml")
                new_settings = get_configuration(config_toml_path)
                @info new_settings
                @info new_settings == settings
                # TODO: Restart if settings changed
                old_paths = map(notebook_sessions) do sesh
                    sesh isa RunningNotebookSession ? sesh.path : nothing
                end
                old_hashes = map(notebook_sessions) do sesh
                    sesh isa RunningNotebookSession ? sesh.hash : nothing
                end

                new_paths = [path for path in find_notebook_files_recursive(settings.SliderServer.start_dir) if !isnothing(path) && path ∉ settings.SliderServer.exclude]
                renew_paths = [path for path in new_paths if path ∈ old_paths && path_hash(path) ∉ old_hashes]
                dead_paths =  [path for path in old_paths if path ∉ new_paths]

                running_hashes = map(notebook_sessions) do sesh
                    sesh isa RunningNotebookSession ? sesh.hash : nothing
                end

                to_delete = [path_hash(path) for path in dead_paths if !isnothing(path)]
                to_start = [path for path in new_paths if !isnothing(path) && path ∉ old_paths]
                to_renew = [path for path in renew_paths]
                @info "delete" to_delete
                @info "start" to_start
                @info "to run: " to_renew

                for hash in to_delete
                    remove_from_session!(notebook_sessions, server_session, hash)
                end

                for path in to_renew
                    session, jl_contents, original_state = renew_session!(notebook_sessions, server_session, path, settings)
                    if path ∉ settings.Export.exclude
                        generate_static_export(path, settings, original_state, settings.Export.output_dir, jl_contents)
                    end
                end

                for path in to_start
                    session, jl_contents, original_state = add_to_session!(notebook_sessions, server_session, path, settings, true, settings.SliderServer.start_dir)
                    if path ∉ settings.Export.exclude
                        generate_static_export(path, settings, original_state, settings.Export.output_dir, jl_contents)
                    end
                end
                # Create index!
                if settings.SliderServer.serve_static_export_folder && settings.Export.create_index

                    write(joinpath(settings.Export.output_dir, "index.html"), default_index((
                        without_pluto_file_extension(path) => without_pluto_file_extension(path) * ".html"
                        for path in to_start ∪ to_renew
                    )))
                    @info "Wrote index to" settings.Export.output_dir
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
        HTTP.@register(router, "POST", "/github_webhook/", pull)

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