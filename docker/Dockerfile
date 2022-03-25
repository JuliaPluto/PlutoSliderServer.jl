FROM julia:1.7.2-bullseye

WORKDIR /app
COPY . /app
COPY docker/PlutoDeployment.toml /etc/sliderserver/PlutoDeployment.toml

# julia installation
RUN julia --project -e "import Pkg; Pkg.instantiate(); Pkg.build()"

CMD julia --project docker/docker_entrypoint.jl
