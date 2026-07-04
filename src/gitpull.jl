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

    run(`$(git()) -C $(dir) fetch origin $(branch_name) --quiet`)

    local_hash = read(`$(git()) -C $(dir) rev-parse HEAD`, String)
    remote_hash = read(`$(git()) -C $(dir) rev-parse FETCH_HEAD`, String)

    local_hash == remote_hash
end


function pullhard(dir=".")
    branch_name = current_branch_name(dir)

    run(`$(git()) -C $(dir) reset --hard origin/$(branch_name)`)
end

function fetch_pull(dir="."; pull_sleep=1)
    in_sync = fetch(dir)

    if !in_sync
        pullhard(dir)
        sleep(pull_sleep)
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
