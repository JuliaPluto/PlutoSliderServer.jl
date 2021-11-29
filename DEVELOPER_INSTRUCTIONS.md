
# How to develop this package

If you are not @fonsp and you are interested in developing this, get in touch!

### Step 1 (only once)

Clone this repo to say `~/PlutoSliderServer.jl/`.

Clone Pluto.jl to say `~/Pluto.jl/`.

Create a new VS Code session and add both folders. You are interested in these files:

-   `Pluto.jl/frontend/components/Editor.js` search for `use_slider_server`
-   `Pluto.jl/frontend/common/PlutoHash.js`
-   `PlutoSliderServer.jl/src/PlutoSliderServer.jl`
-   `PlutoSliderServer.jl/src/MoreAnalysis.jl`
-   `PlutoSliderServer.jl/test/runtestserver.jl`

### Step 2 (only once)

```julia
julia> ]
pkg> dev ~/PlutoSliderServer.jl
pkg> dev ~/Pluto.jl
```

### Step 3 (every time)

You can run the bind server like so:

```
bash> cd PlutoSliderServer.jl
bash> julia --project -e "import Pkg; Pkg.instantiate()"
bash> julia --project test/runtestserver.jl
```

Edit the `runtestserver.jl` file to suit your needs.

The bind server will start running on port 2341. It can happen that HTTP.jl does a goof and the port becomes unavaible until you reboot. Edit `runtestserver.jl` to change the port.

### Step 4 (every time)

If you run the Slider server using the `runtestserver.jl`, it will also run a static HTTP server for the exported files on the same port. E.g. the export for `test/dir1/a.jl` will be available at `localhost:2345/test/dir1/a.html`.

Go to `localhost:2345/test/dir1/a.html`.

Pluto's assets are also being server over this server, you can edit them and refresh.
