export to_local_path, to_url_path

"""Convert URL path using `/` separators to OS-specific path."""
function to_local_path(s::AbstractString)
    Sys.iswindows() ? replace(s, '/' => '\\') : s
end

"""Convert a local path to URL form with `/` separators."""
function to_url_path(s::AbstractString)
    Sys.iswindows() ? replace(s, '\\' => '/') : s
end

