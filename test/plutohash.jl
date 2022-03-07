using Test
import PlutoSliderServer: plutohash, base64urlencode, base64urldecode
import HTTP

@testset "PlutoHash" begin
    @test plutohash("Hannes") == "OI48wVWerxEEnz5lIj6CPPRB8NOwwba-LkFYTDp4aUU"
    @test base64urlencode(UInt8[0, 0, 63, 0, 0, 62, 42]) == "AAA_AAA-Kg"

    dir = mktempdir()
    for _ = 1:50
        data = rand(UInt8, rand(60:80))
        e = base64urlencode(data)
        @test base64urldecode(e) == data

        # URI escaping/unescaping should have no effect
        @test HTTP.unescapeuri(e) == e
        @test HTTP.escapeuri(e) == e

        # it should be a legal filename
        p = joinpath(dir, e)
        write(p, "123")
        @test read(p, String) == "123"
        isfile(p)
        rm(p)
        @assert !isfile(p)
    end
end