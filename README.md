# PlutoSliderServer.jl

> _**not just sliders!**_

Web server to run just the @bind parts of a [Pluto.jl](https://github.com/fonsp/Pluto.jl) notebook. 

See it in action at [computationalthinking.mit.edu](https://computationalthinking.mit.edu/Spring21/week1/)! Sliders, buttons and camera inputs work _instantly_, without having to wait for a Julia process. Plutoplutopluto

[![](https://data.jsdelivr.com/v1/package/gh/fonsp/Pluto.jl/badge)](https://www.jsdelivr.com/package/gh/fonsp/Pluto.jl)



# What can it do?

## 1. Static HTML export
PlutoSliderServer can **run a notebook** and generate the **export HTML** file. This will give you the same file as the export button inside Pluto (top right), but automatically, without opening a browser.

One use case is to automatically create a **GitHub Pages site form a repository with notebooks**. For this, take a look at [our template repository](https://github.com/JuliaPluto/static-export-template) that used GitHub Actions and PlutoSliderServer to generate a website on every commit.

### Example
```julia
PlutoSliderServer.export_notebook("path/to/notebook.jl")
# will create a file `path/to/notebook.html`
```

## 2. Run a slider server
The main functionality of PlutoSliderServer is to run a ***slider server***. This is a web server that **runs a notebook using Pluto**, and allows visitors to **change the values of `@bind`-ed variables**. 

The important **differences** between running a *slider server* and running Pluto with public access are:
- A *slider server* can only set `@bind` values, it is not possible to change the notebook's code.
- A *slider server* is **stateless**: it does not keep track of user sessions. Every request to a slider server is an isolated HTTP `GET` request, while Pluto maintains a WebSocket connection.
- Pluto synchronizes everything between all connected clients in realtime. The *slider server* does the opposite: all 'clients' are **disconnected**, they don't see the `@bind` values or state of others.

> **To learn more, watch the [PlutoCon 2020 presentation about how PlutoSliderServer works](https://www.youtube.com/watch?v=QZ3xlKm92tk)**.

### Example
```julia
PlutoSliderServer.run_notebook("path/to/notebook.jl")
# will create a file `path/to/notebook.html`

# TODO: example with configuration
```

## 3. _(WIP): Precomputed slider server_
Many input elements only have a finite number of possible values. For example `PlutoUI.Slider(5:15)` can only have 11 values. For finitie inputs like the slider, PlutoSliderServer can run the slider server **in advance**, and precompute the results to all possible inputs (in other words: precompute the response to all possible requests). 

This will generate a directory of subdirectories and files, each corresponding to a possible request. You can host this directory along with the generated HTML file (e.g. on GitHub pages), and Pluto will be able to use these pregenerated files as if they are a slider server! **You can get the interactivity of a slider server, without running a Julia server!**

#### Combinatorial explosion
We use the *bond connections graph* to understand which bound variables are co-dependent, and which are disconnected. For all groups of co-dependent variables, we precompute all possible combinations of their values. This allows us to **tame the 'combinatorical explosion'** that you would get when considering all possible combinations of all bound variables! If two variables are 'disconnected', then we don't need to consider possible *combinations* between them.

> This part is still work-in-progress: https://github.com/JuliaPluto/PlutoSliderServer.jl/pull/29

## Directories

All of the functionality above can also be used on all notebooks in a directory. PlutoSliderServer will scan a directory recursively for notebook files.

See `PlutoSliderServer.export_directory` and `PlutoSliderServer.run_directory`.

### Watching a directory

After scanning a directory for notebook files, you can ask Pluto to continue watching the directory for changes. When notebook files are added/removed, they are also added/removed from the server. When a notebook file changes, the notebook session is restarted.

This works especially well when this directory is a git-tracked directory. When running in a git directory, PlutoSliderServer can keep `git pull`ing the directory, updating from the repository automatically. 

See the `SliderServer_watch_dir` option and `PlutoSliderServer.run_git_directory`.

#### Continuous Deployment

The result is a *Continuous Deployment* setup: you can set up your PlutoSliderServer on a dedicated server running online, synced with your repository on github. You can then update the repository, and the PlutoSliderServer will update automatically.

The alternative is to redeploy the entire server every time a notebook changes. We found that this setup works fairly well, but causes long downtimes whenever a notebook changes, because all notebooks need to re-run. This can be a problem if your project consists of many notebooks, and they change frequently.

See `PlutoSliderServer.run_git_directory`.

# How does it work?

> [PlutoCon 2020 presentation about how PlutoSliderServer works](https://www.youtube.com/watch?v=QZ3xlKm92tk)

## Bond connections graph
A crucial idea in the PlutoSliderServer is the *bond connections graph*. This is a bit of a mathematical adventure, I tried my best to explain it **in the [PlutoCon 2020 presentation about how PlutoSliderServer works](https://www.youtube.com/watch?v=QZ3xlKm92tk)**. Here is another explanation in text:

### Example notebook

Let's take a look at this simple notebook:

```julia
@bind x Slider(1:10)

@bind y Slider(1:5)

x + y

@bind z Slider(1:100)

"Hello $(z)!"
```

We have three **bound variables**: `x`, `y` and `z`. When analyzed by Pluto, we find the dependecies between cels: `1 -> 3`, `2 -> 3`, `4 -> 5`. This means that, as a graph, the last two cells are completely disconnected from the rest of the graph. Our *bond connections graph* will capture this idea.

### Procedure
For each bound variable, we use Pluto's reactivity graph to know:
1. Which cells depend on the bound variable?
2. Which *other* bound variables are dependencies of a cell from (1)? These are called the co-dependencies of the bound variable.


In our example, `x` influences the result of `x + y`, which depends on `y`. So `x` and `y` are codependent. `z` is disconnected from `x` and `y`, so it forms its own group.

This forms a dictionary, which looks like:
```julia
Dict(
    :x => [:x, :y],
    :y => [:x, :y],
    :z => [:z],
)
```

For more examples, take a look at [this notebook](https://github.com/JuliaPluto/PlutoSliderServer.jl/blob/v0.2.6/test/parallelpaths4.jl), which has [this bond connection graph](https://github.com/JuliaPluto/PlutoSliderServer.jl/blob/v0.2.6/test/connections.jl#L28-L43).

### Application in the slider server

Now, whenever you send the value of a bound variable `x` to the slider server, you *also have to send the values of the co-dependencies of `x`*, which are `x` and `y` in our example. By sending both, you are sending all the information that is needed to fully determine the dependent cells.


### Application in the precomputed slider server

Like the regular slider server, we use the *bond connections graph*, which tells us which bound variables are co-dependent. This allows us to **tame the 'combinatorical explosion'** that you would get when considering all possible combinations of all bound variables! If two variables are 'disconnected', then we don't need to consider possible *combinations* between them.

In our example notebook, there are `10 (x) * 5 (y)  +  100 (z) = 150` combinations to precompute. Without considering the connections graph, there would be `10 (x) * 5 (y) * 100 (z) = 5000` possible combinations.


# How to use this package

As PlutoSliderServer embeds so much functionality, it may be confusing to figure out how to approach your setting. That's why we're going to see how to approach some different use cases:

## What PlutoSliderServer provides

- A very rich configuration — see the `src/Types.jl` for all available options and see below some sensible options for each use-case
- `run_directory` function - starts from a directory, finds all pluto notebooks and runs them, according to settings
- `github_action` function - (aka `export_directory`) - bundles some presets to be run into a GitHub Action. See MIT course for usage.
- `run_git_directory` function - runs `run_directory` *and* a git-pull loop, also forces watching the directory.

## Usecase: Given a repository, start a PlutoSliderServer to serve static exports with live preview

> _Disclaimer: This is work in progress, there might be holes!_

1. Create a folder with the `Project.toml` and `Manifest.toml` for the `PlutoSliderServer` (NOT the notebooks - the notebooks dependencies should be on each notebook!)
```shell
cd <your-repo>
mkdir pluto-slider-server-environment
julia --project=pluto-slider-server-environment
    ]
    add Pluto
    add PlutoSliderServer#webhook-v1.5
```

> Note: You can find the resulting Project.toml, Manifest.toml in `pluto-slider-server-environment`. It's there for your convenience, copy it to your repository or recreate it as above.

2. Create a configuration file
(See pluto-slider-server-environment/PlutoDeployment.toml for this example, and 📝📝)
```toml
[Export]
enabled = true  # Whether to export or not
output_dir = "."  # Where to start looking for notebooks, usually overriden
exclude = []  # Array of notebooks to ignore from export
ignore_cache = []  # Array of notebooks to ignore from cache
# pluto_cdn_root = ""  # If set, the exported files will request external resources from CDN and not your server.
baked_state = true  # include an encoded version of the intial state in the HTML
baked_notebookfile = true  # include an encoded version of the intial state in the HTML
offer_binder = false  # enable the binder button on to-right
disable_ui = true  # Stop showing Pluto UI and make page look like an article
# cache_dir = "cache-folder-should-depend-on-contents"  # Use cache from previous runs (useful in GitHub Actions)
slider_server_url = "http://localhost:2345/"  # URL where your SliderServer is running and accepting `@bind` update requests 
# binder_url = "a-binder-url-that-works-with-your-notebooks"
create_index = true  # Create a automated Pluto notebook that looks like an index page

[SliderServer]
enabled = true  # Keep running the server?
exclude = []  # Which files should be excluded from running the `@bind` parts
port = 2345 
host = "127.0.0.1"
serve_static_export_folder = true  # If false, provide a pluto_cdn_root
start_dir = "."
watch_dir = true  # Whether to watch the filesystem for updates. Uses dyno under the hood 
repository = ""  # Not used
```

3. Run it 
The snippet below assumes you run julia while 
- you have changed into the project directory and
- you have added a `pluto-slider-server-environment` folder with `Project.toml`, `Manifest.toml` and `PlutoDeployment.toml`.

```shell
julia --project="pluto-slider-server-environment" -e "import PlutoSliderServer; PlutoSliderServer.run_directory(\".\", config_toml_path=\"pluto-slider-server-environment/PlutoDeployment.toml\")"
```

If the project directory is also a git repository (public or keys exist in `~/.ssh`) you can alternatively use `run_git_directory`, to pull changes periodically:
```shell
julia --project="pluto-slider-server-environment" -e "import PlutoSliderServer; PlutoSliderServer.run_git_directory(\".\", config_toml_path=\"pluto-slider-server-environment/PlutoDeployment.toml\")"
```

That also requires the `start_dir` to be a repository in which you can `git pull` without password (which means it's either public, or you have the required keys in `~/.ssh/` and your git's provider security page! 

4. Start PlutoSliderServer on restart
For this step, we'll assume a very specific but also common setup:

    1. Ubuntu-based machine with `apt-get`, `git`, `vim` and internet
    2. root access

    
    1. Install Julia (run as root) ```shell
wget https://julialang-s3.julialang.org/bin/linux/x64/1.6/julia-1.6.1-linux-x86_64.tar.gz
tar zxvf julia-1.6.1-linux-x86_64.tar.gz
rm julia-1.6.1-linux-x86_64.tar.gz
ln -s `pwd`/julia-1.6.1/bin/julia /usr/local/bin/julia
```
    2. get your repository
    ```shell
    git clone https://github.com/<user>/<repo-with-notebooks>
    ```
    3. Create a service
```shell
sudo cat > /etc/systemd/system/pluto-server.service << __EOF__
[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/pluto-slider-server.sh

[Install]
WantedBy=default.target

__EOF__
```
    4. Create the startup script
```shell
sudo cat > /usr/local/bin/pluto-slider-server.sh << __EOF__
cd ~/<your-repo>  # Make sure to change folder to your repository
julia --project="pluto-slider-server-environment" -e "import PlutoSliderServer; PlutoSliderServer.run_git_directory(\".\", config_toml_path=\"pluto-slider-server-environment/PlutoDeployment.toml\")"
__EOF__
```

    5. Permissions stuff
```shell
    sudo chmod 744 /usr/local/bin/pluto-slider-server.sh
    sudo chmod 664 /etc/systemd/system/pluto-server.service
```

    6. Enable
```shell
sudo systemctl daemon-reload
sudo systemctl enable disk-space-check.service
```

    7. Adjust settings
    If/When you change your configurations (host, IP, domain name etc), change the files in the repository and restart the server. It should reload 'automatically.

--- 

TBA: There will be a simple 1.2.3. checklist to get this running on heroku for your own repository. It is designed to be used in a **containerized** environment (such as heroku, docker, digitalocean apps, ...), in a **push to deploy** setting.

# Authentication and security
Since this server is a new and experimental concept, we highly recommend that you run it inside of an isolated environment, such as a docker container. While visitors are not able to change the notebook code, it is possible to manipulate the API to set bound values to arbitrary objects. For example, when your notebook uses `@bind x Slider(1:10)`, the API could be used to set the `x` to `9000`, `[10,20,30]` or `"👻"`. 

In the future, we are planning to implement a hook that allows widgets (such as `Slider`) to validate a value before it is run: [`AbstractPlutoDingetjes.Bonds.validate_value`](https://docs.juliahub.com/AbstractPlutoDingetjes/UHbnu/1.1.0/#AbstractPlutoDingetjes.Bonds.validate_value-Tuple{Any,%20Any}).

Of course, we are not security experts, and this software does not come with any kind of security guarantee. To be completely safe, assume that someone who can visit the server can execute arbitrary code in the notebook, despite our measures to prevent it.

# How to develop this package

If you are not @fonsp and you are interested in developing this, get in touch!

## Step 1 (only once)

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

### Step 4 -- easy version (every time)

If you run the Slider server using the runtestserver.jl, it will also run a static HTTP server for the exported files on the same port. E.g. the export for `test/dir1/a.jl` will be available at `localhost:2345/test/dir1/a.html`.

Go to `localhost:2345/test/dir1/a.html`.

Pluto's assets are also being server over this server, you can edit them and refresh.


### Step 4 -- hard version (every time)

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
