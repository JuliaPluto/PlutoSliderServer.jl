FROM julia:latest

WORKDIR /app
COPY . /app
COPY docker/PlutoDeployment.toml /etc/sliderserver/PlutoDeployment.toml

# julia installation
RUN julia --project=. -e "import Pkg; Pkg.instantiate()"

CMD julia --project=. docker/docker_entrypoint.jl

