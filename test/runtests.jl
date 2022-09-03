import PlutoSliderServer
ENV["JULIA_DEBUG"] = PlutoSliderServer

# To run a test server:
# - Change the line below to `true`.
just_run_test_server = false
# - Pretend to run the tests: `pkg> test PlutoSliderServer`
# 
# This will:
# - Create a temporary folder with some notebook files.
# - Run the slider server on that folder on a random port. (Check the terminal for the locahost URL.)
# - Use your local copy of Pluto for the JS assets, instead of getting them from the CDN. This means that you can edit Pluto's JS files, refresh, and see the changes!

if just_run_test_server
    include("./runtestserver.jl")
else
    ENV["HIDE_PLUTO_EXACT_VERSION_WARNING"] = "true"
    include("./plutohash.jl")
    include("./configuration.jl")
    include("./static export.jl")
    include("./HTTP requests.jl")
    include("./Folder watching.jl")
    include("./Bond connections.jl")
end