# PlutoSliderServer Docker Tools

## Building

The most straightforward way of building the slider server docker image is by first cloning this repository, then using the `Dockerfile` included in this subdirectory. Below is an example build command, assuming your PWD is the repository root.

```bash
docker build -f docker/Dockerfile -t sliderserver .
```

## Running

There are two recommended bind mounts, one of which is required to run the docker image built in the previous section. The image expects a folder containing notebooks to be served to be mounted to `/etc/sliderserver/notebooks` in the image. Optionally, a `PlutoDeployment.toml` configuration file can be mounted to `/etc/sliderserver/PlutoDeployment.toml` to override the default deployment configuration packaged with the image. Below is an example of a run command, although this will differ greatly depending on deployment use case.

```bash
docker run -it --rm -v /path/to/notebooks:/etc/sliderserver/notebooks -p 2345:2345 sliderserver
```

