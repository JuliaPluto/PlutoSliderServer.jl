import HTTP
import Sockets
import Logging: global_logger, ConsoleLogger
import GitHubActions: GitHubActionsLogger

function hello()

    global_logger(GitHubActionsLogger())


    port = rand(12345:65000)
    host = "127.0.0.1"



    hostIP = parse(Sockets.IPAddr, host)
    serversocket = Sockets.listen(hostIP, UInt16(port))


    @info "# Starting server..."


    http_server = HTTP.serve!(hostIP, UInt16(port), server=serversocket) do req
        return HTTP.Response(200)
    end

    @info "# Server started"


    close(http_server)

end


t = @async try
    hello()
catch e
    @error "Error in server" exception = (e, catch_backtrace())
end


wait(t)