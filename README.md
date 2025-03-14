# PlutoSliderServer.jl

> _**not just sliders!**_

Web server to run just the @bind parts of a [Pluto.jl](https://github.com/fonsp/Pluto.jl) notebook.

See it in action at [computationalthinking.mit.edu](https://computationalthinking.mit.edu/)! Sliders, buttons and camera inputs work _instantly_, without having to wait for a Julia process. Plutoplutopluto

[![](https://data.jsdelivr.com/v1/package/gh/fonsp/Pluto.jl/badge)](https://www.jsdelivr.com/package/gh/fonsp/Pluto.jl)

# Try it out

```julia
using PlutoSliderServer
path_to_notebook = download("https://raw.githubusercontent.com/fonsp/Pluto.jl/v0.17.2/sample/Interactivity.jl") # fill in your own notebook path here!

PlutoSliderServer.run_notebook(path_to_notebook)
```

Now open a browser, and go to the address printed in your terminal!

Later when you are using PlutoSliderServer on a public website, `PlutoSliderServer.run_notebook` is a good way to test your notebook locally before putting it online.

# What can it do?

## 1. HTML export
PlutoSliderServer can **run a notebook** and generate the **export HTML** file. This will give you the same file as the export button inside Pluto (top right), but automatically, without opening a browser.

One use case is to automatically create a **GitHub Pages site from a repository with notebooks**. For this, take a look at [our template repository](https://github.com/JuliaPluto/static-export-template) that used GitHub Actions and PlutoSliderServer to generate a website on every commit.

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
```

## 3. _(WIP): Precomputed slider server_
Many input elements only have a finite number of possible values, for example, `PlutoUI.Slider(5:15)` can only have 11 values. For finite inputs like the slider, PlutoSliderServer can run the slider server **in advance**, and precompute the results to all possible inputs (in other words: precompute the response to all possible requests).

This will generate a directory of subdirectories and files, each corresponding to a possible request. You can host this directory along with the generated HTML file (e.g. on GitHub pages), and Pluto will be able to use these pregenerated files as if they are a slider server! **You can get the interactivity of a slider server, without running a Julia server!**

#### Combinatorial explosion
We use the *bond connections graph* to understand which bound variables are co-dependent, and which are disconnected. For all groups of co-dependent variables, we precompute all possible combinations of their values. This allows us to **tame the 'combinatorial explosion'** that you would get when considering all possible combinations of all bound variables! If two variables are 'disconnected', then we don't need to consider possible *combinations* between them.

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
PlutoSliderServer is **not just Pluto with editing disabled** – it works quite differently. This section explains why it has to be different, how it works, and what the advantages and disadvantages are.

> [PlutoCon 2020 presentation about how PlutoSliderServer works](https://www.youtube.com/watch?v=QZ3xlKm92tk)

## Different from Pluto
When I created this package for computationalthinking.mit.edu, the goal was to serve notebook HTMLs publicly online, with working interactivity, for a large number of visitors. 

The simplest approach is to just run Pluto on a public server and disable editing. (Try it: open a notebook in Pluto, copy the URL, and open it in multiple windows next to each other. Add `&disable_ui=true` to the URL to simulate disabled editing.) The problem with this is that all sessions are synchronised: moving a slider in one window moves it everywhere. And updates to other cells (values and plots) show in all windows. You could simply disable this synchronisation between windows, but then you would still "feel" effects from other users. You might not see other sliders moving, but they are still changing values in your shared session, influencing results.

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

We have three **bound variables**: `x`, `y` and `z`. When analyzed by Pluto, we find the dependecies between cells: `1 -> 3`, `2 -> 3`, `4 -> 5`. This means that, as a graph, the last two cells are completely disconnected from the rest of the graph. Our *bond connections graph* will capture this idea.

### Procedure
For each bound variable, we use Pluto's reactivity graph to know:
1. Which cells depend on the bound variable?
2. Which bound variables are (indirect) dependencies of any cell from (1)? These are called the co-dependencies of the bound variable.


In our example, `x` influences the result of `x + y`, which depends on `y`. So `x` and `y` are the co-dependencies of `x`. Variable `z` influences `"Hello $(z)!"`, which is does not have `x` or `y` as dependencies. So `z` is *not* codependent with `x` or with `y`.

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

As PlutoSliderServer embeds so much functionality, it may be confusing to figure out how to approach your setting. Here is an overview of our most important functions:

- `export_directory` will find all notebooks in a directory, run them, and generate HTML files. *(`export_notebook` for a single file.)* One example use case is https://github.com/JuliaPluto/static-export-template
- `run_directory` does the same as `export_directory`, but it **keeps the notebooks running** and runs the slider server! It will also watch the given directory for changes to notebook files, and automatically update the slider server. *(`run_notebook` for a single file.)*
- `run_git_directory` does the same as `run_directory`, but it will keep running `git pull` in the given directory. Any changes will get picked up by our directory watching!

## Configuration

PlutoSliderServer is very configurable, and we use [Configurations.jl](https://github.com/Roger-luo/Configurations.jl) to configure the server. We try our best to be smart about the default settings, and we hope that most users do not need to configure anything.

There are two ways to change configurations: using keywords arguments, and using a `PlutoDeployment.toml` file.

### 1. Keyword arguments

Our functions can take keyword arguments, for example:

```julia
run_directory("my_notebooks";
    SliderServer_port=8080,
    SliderServer_host="0.0.0.0",
    Export_baked_notebookfile=false,
)
```

> 🌟 For the full list of options, see the documentation for the function you are using. For example, in the Julia REPL, run `?run_directory`.

### 2. `PlutoDeployment.toml`

If you are using a package environment for your slider server (if you are deploying it on a server, you probably should), then you can also use a TOML file to configure PlutoSliderServer.

In the same folder where you have your `Project.toml` and `Manifest.toml` files, create a third file, called `PlutoDeployment.toml`. Its contents should look something like:
```toml
[Export]
baked_notebookfile = true

[SliderServer]
port = 8080
host = "0.0.0.0"

# You can also set Pluto's configuration here:
[Pluto]
[Pluto.compiler]
threads = 2
# See documentation for `Pluto.Configuration` for the full list of options. You need specify the categories within `Pluto.Configuration.Options` (`compiler`, `evaluation`, etc).
```

> 🌟 For the full list of options, run `PlutoSliderServer.show_sample_config_toml_file()`.

Our functions will look for the existance of a file called `PlutoDeployment.toml` in the active package environment, and use it automatically.

You can also combine the two configuration methods: keyword options and toml options will be merged, the former taking precedence.

# Sample setup: Given a repository, start a PlutoSliderServer to serve static exports with live preview

These instructions set up a slider server on a dedicated server, which automatically synchronises with a git repository, containing the notebook files. Make sure to create one before we start.

> _Disclaimer: This is work in progress, there might be holes!_

## Part 1: setup and running locally

### 1. Initialize
Create a folder called `pluto-slider-server-environment` with the `Project.toml` and `Manifest.toml` for the `PlutoSliderServer`: (Not the notebooks - the notebooks should contain their own package environment.)
```shell
$ cd <your-repository-with-notebooks>
$ mkdir pluto-slider-server-environment
$ julia --project=pluto-slider-server-environment
julia> ]
pkg> add Pluto PlutoSliderServer
```

### 2. Configuration file
Create a configuration file in the `pluto-slider-server-environment` directory, which also contains a `Project.toml` file, see the section about `PlutoDeployment.toml` above.
```shell
TEMPFILE=$(mktemp)
cat > $TEMPFILE << __EOF__
[SliderServer]
port = 8080
host = "0.0.0.0"

# more configuration can go here!
__EOF__

sudo mv $TEMPFILE pluto-slider-server-environment/PlutoDeployment.toml
```

This configuration sets the port to `8080` (not `80`, this requires sudo), and the host to `"0.0.0.0"` (which allows traffic from outside the computer, unlike the default `"127.0.0.1"`).

### 3. Run it
Let's try running it locally before setting up our server:
```shell
julia --project="pluto-slider-server-environment" -e "import PlutoSliderServer; PlutoSliderServer.run_git_directory(\".\")"
```

`run_git_directory` will periodically call `git pull`, which requires the `start_dir` to be a repository in which you can `git pull` without password (which means it's either public, or you have the required keys in `~/.ssh/` and your git's provider security page!)

>**Note**
>Julia by default uses `libgit2` for git operations, [which can be problematic](https://github.com/JuliaLang/Pkg.jl/issues/2679). It is also known to cause issues  in cloud environments like AWS's CodeCommit
>where re-authentication is required at regular intervals. 
> 
> A simple workaround is to set the `JULIA_PKG_USE_CLI_GIT` environment variable to `true`, which will fallback to the system git (the one on the shell).
> Make sure that this is installed! (`sudo apt-get install git` does the trick in Ubuntu).

Also note that `git pull` may fail on the server if you force push the branch from your laptop, so handle history-rewriting commands, like `git push -f`, `git rebase` etc with care!

## Part 2: setting up the web server
For this step, we'll assume a very specific but also common setup:

- Ubuntu-based server with `apt-get`, `git`, `vim` and internet
- access through SSH
- root access
- port 80 and 8080 are open to the web

The easiest way to get this is to **rent a server** from digitalocean, AWS, Google Cloud, hetzner, etc. This setup was tested with digitalocean.com, which has an easy interface for beginners.

> ### Required memory, disk space, CPU power
> When renting a server, you need to decide which "droplet size" you want. The bottleneck is memory – CPU power and disk space will always be sufficient. As minimum, you need `500MB + 300MB * length(notebooks)`. But if you use large packages, like Plots or DifferentialEquations, a notebook might need 1000MB memory. 
> 
> There is no minimum requirement on CPU power, but it does have a big impact on *launch time* and *responsiveness*. We found that DigitalOcean "dedicated CPU" is noticably faster (more than 2x) in both areas than "shared CPU".
> 
> It is really important to make sure that you will be able to **resize your server later**, adding/removing memory as needed, to minimize your costs. For DigitalOcean, we have a specific tip: *always **start** with the smallest possible droplet (512MB or 1000MB), and then resize memory/CPU to fit your needs, without resizing the disk*. When resizing, DigitalOcean does not allow *shrinking* the disk size.

### 0. Update packages
```shell
sudo apt-get update
sudo apt-get upgrade
```

You should run `systemd --version` to verify that we have version 230 or higher.

### 1. Install Julia (run as root)
Follow the official instructions to install Julia at using **juliaup**. Probably:

```shell
curl -fsSL https://install.julialang.org | sh
```

Now, the `julia` command should be available. Log out and log in, and type `julia --version` in the terminal, and you should see something!

Afterwards, you need to make the `julia` command available **to all users**. Run this command to do so:

```shell
sudo ln -s /home/`whoami`/.juliaup/bin/julia /usr/local/bin/julia
```

### 2. get your repository
```shell
cd ~
git clone https://github.com/<user>/<repo-with-notebooks>
cd <repo-with-notebooks>
git pull
```

### 3. Create a service
```shell
TEMPFILE=$(mktemp)
cat > $TEMPFILE << __EOF__
[Unit]
After=network.service

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
ExecStart=/usr/local/bin/pluto-slider-server.sh
Restart=always
RestartSec=5
User=$(whoami)
Group=$(id -gn)

[Install]
WantedBy=default.target
__EOF__

sudo mv $TEMPFILE /etc/systemd/system/pluto-server.service
```

This script uses `whoami` and `id -gn` to automatically insert your username an group name into the configuration file. We want to run the PlutoSliderServer as your user, not as root.

### 4. Create the startup script
```shell
TEMPFILE=$(mktemp)
cat > $TEMPFILE << __EOF__
#!/bin/bash

# this env var allows us to side step various issues with the Julia-bundled git
export JULIA_PKG_USE_CLI_GIT=true

cd /home/<your-username>/<your-repo>  # ⛔️⚠️ Make sure to change to the absolute path to your repository. Don't use ~.
julia --project="pluto-slider-server-environment" -e "import Pkg; Pkg.instantiate(); import PlutoSliderServer; PlutoSliderServer.run_git_directory(\".\")"
__EOF__

sudo mv $TEMPFILE /usr/local/bin/pluto-slider-server.sh
```

> [!TIP]
> If you want to use **GLMakie**, it might be necessary to set a display. In the script above, replace `julia` with
> ```
> DISPLAY=:0 xvfb-run -a -n 100 -s '-screen 0 1024x768x24' julia
> ```

### 5. Permissions stuff
```shell
sudo chmod 744 /usr/local/bin/pluto-slider-server.sh
sudo chmod 664 /etc/systemd/system/pluto-server.service
```

### 6. Start & enable
```shell
sudo systemctl daemon-reload
sudo systemctl start pluto-server
sudo systemctl enable pluto-server
```

> [!TIP]
> If you need to change the service file or the startup script later, re-run this step to update the daemon.

Your server should be running now!! The next steps will explain how to monitor your server, and where to see the notebooks in action.

### 7. View logs
```shell
# To see quick status (running/failed and memory):
systemctl -l status pluto-server

# To browse past logs:
sudo journalctl --pager-end -u pluto-server

# To see logs coming in live:
sudo journalctl --follow -u pluto-server
```

> [!IMPORTANT]
> These three commands are important! Write them down somewhere.

### 8. Server available

Once you see this message in your logs, you know that the server is running:

```
Feb 14 13:13:15 surfje pluto-slider-server.sh[14810]: ┌ Info:
Feb 14 13:13:15 surfje pluto-slider-server.sh[14810]: │ Starting server...
Feb 14 13:13:15 surfje pluto-slider-server.sh[14810]: │ ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡
Feb 14 13:13:15 surfje pluto-slider-server.sh[14810]: └   address = "http://0.0.0.0:8080/"
Feb 14 13:13:15 surfje pluto-slider-server.sh[14810]: [ Info: Listening on: 0.0.0.0:8080, thread id: 1
Feb 14 13:13:15 surfje pluto-slider-server.sh[14810]: ┌ Info:
Feb 14 13:13:15 surfje pluto-slider-server.sh[14810]: │ Server started
Feb 14 13:13:15 surfje pluto-slider-server.sh[14810]: └ ≡≡≡≡≡≡≡≡≡≡≡≡≡≡
```

You can open a web browser to test it out! Check out "🌟 Conclusion" below.

### 9. Live updates
When you change the notebooks in the git repository, your server will automatically update (PlutoSliderServer keeps calling `git pull` every couple of seconds)! 

When a notebook file changes, PlutoSliderServer will shut down the old version of that notebook, and start the new one. When notebook files are added or removed, they are added or removed from the server. If you have a lot of notebooks, this is a big speedup compared to always having to restart the entire server when a notebook file changes.

When the configuration file (`PlutoDeployment.toml`) changes, PlutoSliderServer will detect a change in configuration and shut down. Because we set up our service using `systemctl`, the server will automatically restart. (With the new settings)

### 10. 🌟 Conclusion
Yay! If everything went well, we now set up a web server with PlutoSliderServer. To see the result, you open a browser and go to the URL of your server. This looks like:

```
http://12.34.56.78:8080/
```

where `12.34.56.78` is the IP address of your server. You should see an index of your notebooks, and clicking on a notebook should give an interactive page! The first visit can take a long time to load (because of JIT).

> [!NOTE]
> **Not seeing anything?** If you cannot visit the index web page, if you get "Connection refused", "Connection timeout", etc., then check the server logs. If the logs seem fine, then you have a networking issue, like a firewall. Is the IP address correct? The port 8080 might be blocked. It's possible that port 80 is available, see `nginx` instructions below. Ask your network administrator.

## Part 3: port, domain name, https *(optional)*
The default settings will serve Pluto on `http://12.34.56.78:8080/`: with `http` (not `https`), at the IP address (not a domain like `example.com`), on port 8080 (not 80 or 443). 

This Part 3 explains how to get https, domain and port 80. **But you don't always need this!** If `http://12.34.56.78:8080/` works for your application, then you are done, and the proud owner of a new PlutoSliderServer! Following Part 3 might add unnecessary complexity.

The main reason why these steps can be useful is to get **https**. This is necessary when:
- Using camera, microphone or GPS inputs in your notebook (e.g. `PlutoUI.WebcamInput`).
- You have an advanced setup: a static PlutoSliderServer that deploys to Netlify/GHPages, combined with a dynamic PlutoSliderServer that only does the bonds, and they are linked together. Your static site is only allowed to make requests to the dynamic server if both are on `https` (this is CORS).

The easiest way to get `https` is with cloudflare, and you can only get cloudflare if you have a domain, and a server on port 80.

> [!NOTE]
> If you use a server managed by your university/company, ask your system administrator how to achieve these steps. You can probably get a domain like `https://myproject.mit.edu/`.

### 1. Domain name

You need to buy a domain name (like `mycoolwebsite.org`). The easiest place to buy a domain name is [njal.la](njal.la), but most registrars will work (namecheap.com works). 

On the website of your registrar (where you bought the domain), go to the DNS settings. Set an "A record" that points from `my-pluto-subdomain` to your IP address. 

You can now access your PlutoSliderServer at `http://my-pluto-subdomain.mydomain.org:8080/`. Nice!

> [!TIP]
> In step 3 we set up https with cloudflare. If this is what you want, then you could set this up directly. That means that you don't set the A record on your registrar site, but you tell your registrar to use Cloudflare DNS, and you set the A record in cloudflare.


### 2. Port 80

We don't want everyone to add `:8080` to the URL! The default port for http is 80, so we want our website to be available at port 80.

The tricky thing is: we don't want to run PlutoSliderServer directly on port 80, because this requires `sudo` privileges for running `julia`. We want to avoid this because we don't want `julia` to read/write files as `root` (this would mess up your git directory). 

The solution is to run PlutoSliderServer on port 8080, and use a separate server (running as root) to redirect traffic from port 80 to port 8080. We use `nginx` for that!

```shell
sudo apt install nginx
```
nginx is now installed and it is configured to run at startup.

Let's configure nginx as a redirect from port 80 to port 8080.

```shell
TEMPFILE=$(mktemp)
cat > $TEMPFILE << __EOF__
server {
	listen 80 default_server;
	listen [::]:80 default_server;

	location / {
		proxy_pass http://localhost:8080;
	}
}
__EOF__

sudo mv $TEMPFILE /etc/nginx/sites-available/default
```

After changing configuration, restart nginx:

```shell
sudo systemctl restart nginx
```

### 3. HTTPS

The easiest way to get https is to use cloudflare. Register an account, set up your domain to use their DNS (check the cloudflare docs), make sure the A record is there, and enable the "Always HTTPS" service. (Cloudflare is also very useful for caching! This will make your PlutoSliderServer faster.)

Alternatively, you can set up HTTPS yourself with `nginx` and Let's Encrypt, but this is beyond the scope of this tutorial. 💛

Now, your service should be available at `https://my-pluto-subdomain.yourdomain.org/`. Nice!

# Similar/alternative packages


## Generating HTML exports
There are many packages that *evaluate literate Julia documents to generate HTML or PDF output*!

The most similar project is [PlutoStaticHTML.jl](https://github.com/rikhuijzer/PlutoStaticHTML.jl). This package generates **static** HTML files from Pluto notebooks, meaning that they do not require JavaScript to load: cell inputs and outputs are stored directly as HTML. (PlutoSliderServer.jl uses the same technique as the "Export to HTML" button inside Pluto: an HTML file is generated with no contents, but with an embedded data stream containing the *editor state*. This HTML file loads Pluto's JS assets and displays this state just like the editor would.)

This means that the output of PlutoSliderServer.jl will look exactly the same as what you see while writing the notebook. Output from PlutoStaticHTML.jl is more minimal, which means that it loads faster, it can be styled with CSS, and it can more easily be embedded within other web pages (like Documenter.jl sections).

Other Julia packages which export to HTML/PDF, but not necessarily with Pluto notebook files as input, include:
- Documenter.jl
- Franklin.jl
- Books.jl
- Weave.jl

## Slider server
PlutoSliderServer is the only package that lets you run a *slider server* for Pluto notebooks (an interactive site to interact with a Pluto notebook through `@bind`).

There are alternatives for running a Julia-backed interactive site if your code is *not* a Pluto notebook, including [JSServe.jl](https://github.com/SimonDanisch/JSServe.jl), [Stipple.jl](https://github.com/GenieFramework/Stipple.jl) and [Dash.jl](https://github.com/plotly/Dash.jl), each with their own philosophy and ideal use case. *(Feel free to suggest others!)*

## Precomputer slider server
[PlutoStaticHTML.jl](https://github.com/rikhuijzer/PlutoStaticHTML.jl) should also have this feature in the future, after it is added to PlutoSliderServer (it is still [being worked on](https://github.com/JuliaPluto/PlutoSliderServer.jl/pull/29)).

If you code is *not* a Pluto notebook, then [JSServe.jl](https://github.com/SimonDanisch/JSServe.jl) also has precomputing abilities, with a different approach and philosophy.

# Authentication and security
Since this server is a new and experimental concept, we highly recommend that you run it inside an isolated environment. While visitors are not able to change the notebook code, it is possible to manipulate the API to set bound values to arbitrary objects. For example, when your notebook uses `@bind x Slider(1:10)`, the API could be used to set the `x` to `9000`, `[10,20,30]` or `"👻"`.

In the future, we are planning to implement a hook that allows widgets (such as `Slider`) to validate a value before it is run: [`AbstractPlutoDingetjes.Bonds.validate_value`](https://docs.juliahub.com/AbstractPlutoDingetjes/UHbnu/1.1.1/#AbstractPlutoDingetjes.Bonds.validate_value-Tuple{Any,%20Any}).

Of course, we are not security experts, and this software does not come with any kind of security guarantee. To be completely safe, assume that someone who can visit the server can execute arbitrary code in the notebook, despite our measures to prevent it. Run PlutoSliderServer in a containerized environment.
