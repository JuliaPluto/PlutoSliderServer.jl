# PlutoSliderServer.jl

> _**not just sliders!**_

Web server to run just the @bind parts of a [Pluto.jl](https://github.com/fonsp/Pluto.jl) notebook. 

See it in action at [computationalthinking.mit.edu](https://computationalthinking.mit.edu/Spring21/week1/)! Sliders, buttons and camera inputs work _instantly_, without having to wait for a Julia process. Plutoplutopluto

## How it works

TODO

## How to use this package

TBA: There will be a simple 1.2.3. checklist to get this running on heroku for your own repository. It is designed to be used in a **containerized** environment (such as heroku, docker, digitalocean apps, ...), in a **push to deploy** setting.

## How to develop this package

If you are not @fonsp and you are interested in developing this, get in touch.

### Step 1 (only once)

Clone this repo to say `~/PlutoSliderServer.jl/`.

Clone Pluto.jl to say `~/Pluto.jl/` and checkout the `slider-server-client-1` branch. This is a fork of the `binder-static-to-live-1` branch, have a look at the difference between those two, not between ` slider-server-client-1`` and  `master`.

Create a new VS Code session and add both folders. You are interested in these files:

-   `Pluto.jl/frontend/components/Editor.js` search for `use_slider_server`
-   `Pluto.jl/frontend/common/PlutoHash.js`
-   `PlutoSliderServer.jl/src/PlutoSliderServer.jl`
-   `PlutoSliderServer.jl/src/MoreAnalysis.jl`
-   `PlutoSliderServer.jl/test/runtestserver.jl`

(FYI since these files _use_ Pluto, you can't develop them inside Pluto.)

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
bash> julia --project test/runtestserver.jl
```

Edit the `runtestserver.jl` file to suit your needs.

The bind server will start running on port 2345. It can happen that HTTP.jl does a goof and the port becomes unavaible until you reboot. Edit `runtestserver.jl` to change the port.

### Step 4 (every time)

We need to serve Pluto's static assets over HTTP, we use Pluto for that.

```julia
julia> import Pluto; Pluto.run(require_secret_for_access=false, require_secret_for_open_links=false, launch_browser=false, port=1234)
```

This server always serves the latest files, so editing `.js` files takes effect after refreshing the browser.

### Step 5 -- easy version (every time)

If you run the Slider server using the runtestserver.jl, it will also run a static HTTP server for the exported files on the same port. E.g. the export for `test/dir1/a.jl` will be available at `localhost:2345/test/dir1/a.html`.

Go to `localhost:2345/test/dir1/a.html`.


### Step 5 -- hard version (every time)

You can now open the editor in 'serverless' mode, by going to `http://localhost:1234/editor.html`. This should be stuck at "loading", because it has no backend connection and no statedump.

You need to provide the editor with a notebook file and a notebook statedump, which need to be accessible via URLs, **with CORS enabled**. 

If you run the Slider server using the runtestserver.jl, it will also run a static HTTP server for the exported files on the same port. E.g. the files for `test/dir1/a.jl` will be available at `localhost:2345/test/dir1/a.jl`, `localhost:2345/test/dir1/a.jlstate`.


##### Using the statefile

You need to URL-encode the URLs to the statefile and the julia file. (Open node and call `encodeURIComponent`.) Use them in the URL query to tell Pluto where to find the files:

For example, I have:
- Pluto (as CDN) at: `http://localhost:1234/editor.html`
- notebook file at: `https://mkhj.fra1.cdn.digitaloceanspaces.com/slider-server-tests/onedefinesanother.jl`
- notebook state dump at: `https://mkhj.fra1.cdn.digitaloceanspaces.com/slider-server-tests/onedefinesanother.jlstate`
- bind server at: `http://localhost:3456/`

This becomes:

> [http://localhost:1234/editor.html?statefile=https%3A%2F%2Fmkhj.fra1.cdn.digitaloceanspaces.com%2Fslider-server-tests%2Fonedefinesanother.jlstate&notebookfile=https%3A%2F%2Fmkhj.fra1.cdn.digitaloceanspaces.com%2Fslider-server-tests%2Fonedefinesanother.jl&disable_ui=yes&slider_server_url=http%3A%2F%2Flocalhost%3A3345%2F](http://localhost:1234/editor.html?statefile=https%3A%2F%2Fmkhj.fra1.cdn.digitaloceanspaces.com%2Fslider-server-tests%2Fonedefinesanother.jlstate&notebookfile=https%3A%2F%2Fmkhj.fra1.cdn.digitaloceanspaces.com%2Fslider-server-tests%2Fonedefinesanother.jl&disable_ui=yes&slider_server_url=http%3A%2F%2Flocalhost%3A3345%2F)

with whitespace:

```
http://localhost:1234/editor.html?
    statefile=
        https%3A%2F%2Fmkhj.fra1.cdn.digitaloceanspaces.com%2Fslider-server-tests%2Fonedefinesanother.jlstate
    &notebookfile=
        https%3A%2F%2Fmkhj.fra1.cdn.digitaloceanspaces.com%2Fslider-server-tests%2Fonedefinesanother.jl
    &disable_ui=
        yes
    &slider_server_url=
        http%3A%2F%2Flocalhost%3A3345%2F
```

## Running it, not developing it

TODO TODO

```julia
julia> ]
pkg> activate --temp
pkg> add https://github.com/JuliaPluto/PlutoSliderServer.jl

julia> import PlutoSliderServer; PlutoSliderServer.run_directory("~/cool_notebooks/")
```

```sh
julia --project=. -e "import PlutoSliderServer; PlutoSliderServer.run_directory(ARGS[1])" ~/cool_notebooks/
```
