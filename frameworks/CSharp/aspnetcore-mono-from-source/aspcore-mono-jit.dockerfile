# Build the test.
FROM microsoft/dotnet:2.2-sdk AS build
WORKDIR /app
COPY PlatformBenchmarks .
RUN dotnet publish -c Release -o out

FROM debian:stretch-20181226 AS runtimea


ARG MONO_DOCKER_GIT_HASH="HEAD"
ARG MONO_DOCKER_MAKE_JOBS="4"

# Install tools and dependencies.
RUN apt-get update && \
    apt-get install -y \
        apt-transport-https \
        dirmngr \
        gnupg \
        ca-certificates \
        make \
        git \
        gcc \
        g++ \
        autoconf \
        libtool \
        automake \
        cmake \
        gettext \
        python

# Build mono
WORKDIR /
RUN git clone --recurse-submodules -j8 https://github.com/mono/mono.git && \
    cd mono && \
    git checkout $MONO_DOCKER_GIT_HASH

WORKDIR /mono
RUN ./autogen.sh && \
    make get-monolite-latest && \
    make -j  $MONO_DOCKER_MAKE_JOBS 

# Copy the test into the container.
WORKDIR /app
COPY --from=build /app/out ./
COPY Benchmarks/appsettings.json ./appsettings.json


# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENV MONO_PATH /mono/mcs/class/lib/net_4_x
ENV MONO_CONFIG /mono/runtime/etc/mono/config
ENTRYPOINT ["/mono/mono/mini/mono", "--server", "--gc=sgen", "--gc-params=mode=throughput", "PlatformBenchmarks.exe"]
