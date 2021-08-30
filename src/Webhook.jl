using FromFile

using HTTP
using SHA

# This function wraps our functions with PlutoSliderServer context. run_server & start_dir are set by the webhook options.
function register_webhook!(hook::Function, router)

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
    function handle_github_webhook(request::HTTP.Request)
        # Need to save configuration
        if get(ENV, "GITHUB_SECRET", "") !== ""
            security_test = validate_github_headers(request, ENV["GITHUB_SECRET"])
            if !security_test
                return HTTP.Response(501, "Not authorized!")
            end
        end

        @async try
            run(`git pull`)
            # run(`git checkout`)
            
            hook()
        catch e
            @warn "Fail in reloading " e
            showerror(stderr, e, stacktrace(catch_backtrace()))
            rethrow(e)
        end
        sleep(max(rand(), 0.1)) # That's both trigger async AND protection against timing attacks :O
        return HTTP.Response(200, "Webhook accepted, async job started!")
    end

    # Register Webhook
    HTTP.@register(router, "POST", "/github_webhook/", handle_github_webhook)
end


function validate_github_headers(request, secret=ENV["GITHUB_SECRET"])
    i = findfirst(a -> lowercase(a.first) == lowercase("X-Hub-Signature-256"), request.headers)
    if (isnothing(i))
        @warn "Can't validate webhook request: `X-Hub-Signature-256` header not found"
        return false
    end
    secure_header = request.headers[i].second
    digest = "sha256=" * bytes2hex(hmac_sha256(collect(codeunits(secret)), request.body))
    sleep(max(0.1, rand()/2))
    return digest == secure_header
end
