# Build the test.
FROM microsoft/dotnet:2.2-sdk AS build
WORKDIR /app
COPY PlatformBenchmarks .
RUN dotnet publish -c Release -o out

FROM debian:stretch-20181226 AS runtime

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

# AOT the framework.
#RUN i=/usr/lib/mono/4.5/mscorlib.dll && echo "=====" && echo "Starting AOT: $i" && echo "=====" && /mono/mono/mini/mono --aot=fullaot $i && echo ""; done
RUN export MONO_PATH=/mono/mcs/class/lib/net_4_x-linux && \
    for i in /mono/mcs/class/*/*/*.dll; do echo "=====" && echo "Starting AOT: $i" && echo "=====" && /mono/mono/mini/mono --aot=fullaot $i && echo ""; done

# Copy the test into the container.
WORKDIR /app
COPY --from=build /app/out ./
COPY Benchmarks/appsettings.json ./appsettings.json

# AOT the test.
RUN export MONO_PATH=/mono/mcs/class/lib/net_4_x-linux && \
    for i in *.dll; do echo "=====" && echo "Starting AOT: $i" && echo "=====" && /mono/mono/mini/mono --aot=fullaot $i && echo ""; done && \
    for i in *.exe; do echo "=====" && echo "Starting AOT: $i" && echo "=====" && /mono/mono/mini/mono --aot=fullaot $i && echo ""; done

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENV MONO_PATH /mono/mcs/class/lib/net_4_x-linux
ENV MONO_CONFIG /mono/runtime/etc/mono/config
ENTRYPOINT ["/mono/mono/mini/mono", "--full-aot", "--server", "--gc=sgen", "--gc-params=mode=throughput", "PlatformBenchmarks.exe"]
