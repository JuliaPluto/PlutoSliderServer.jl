import Git: git

function current_branch_name(dir=".")
    cd(dir) do
        read(`$(git()) rev-parse --abbrev-ref HEAD`, String) |> strip
    end
end


function fetch(dir=".")::Bool

    branch_name = current_branch_name(dir)


    cd(dir) do
        run(`$(git()) fetch origin $(branch_name) --quiet`)

        local_hash = read(`$(git()) rev-parse HEAD`, String)
        remote_hash = read(`$(git()) rev-parse \@\{u\}`, String)

        return local_hash == remote_hash
    end

end


function pullhard(dir=".")

    branch_name = current_branch_name(dir)

    cd(dir) do
        run(`$(git()) reset --hard origin/$(branch_name)`)
    end

end

function fetch_pull(dir=","; pull_sleep=1)
    in_sync = fetch(dir)

    if !in_sync
        pullhard(dir)
        sleep(pull_sleep)
    end
end


function poll_pull_loop(dir="."; interval=5)
    while true
        try
            fetch_pull(dir)
        catch e
            @error "Error in poll_pull_loop" exception=(e, catch_backtrace())
        end
        sleep(interval)
    end
end