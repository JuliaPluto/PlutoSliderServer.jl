import Pluto: Token
export withlock

# LOCK

const locked_objects = Dict{UInt,Token}()
function withlock(f, x)
    l = get!(Token, locked_objects, objectid(x))
    take!(l)
    local result
    try
        result = f()
    catch e
        rethrow(e)
    finally
        put!(l)
    end
    result
end
