import LibGit2
import Git: git

function current_branch_name(dir=".")
    repo = LibGit2.GitRepo(dir)
    LibGit2.isattached(repo) ? 
        LibGit2.shortname(LibGit2.head(repo)) : 
        "HEAD"
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

function get_git_hash(path::String)
	repo = LibGit2.GitRepo(path)
	oid  = LibGit2.head_oid(repo)
	first(string(oid), 7)
end

const get_git_hash_cache = Dict{String,Tuple{Float64,String}}()
function get_git_hash_cached(path; max_age=30.0)
	if haskey(get_git_hash_cache, path)
		last_time, last_result = get_git_hash_cache[path]
		if time() - last_time < max_age
			return last_result
		end
	end

	result = try
		get_git_hash(path)
	catch e
		""
	end
	get_git_hash_cache[path] = (time(), result)
	result
end
