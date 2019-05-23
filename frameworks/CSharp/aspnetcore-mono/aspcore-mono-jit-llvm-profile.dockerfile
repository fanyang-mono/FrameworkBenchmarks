# Build the test.
FROM microsoft/dotnet:2.2-sdk AS build
WORKDIR /app
COPY PlatformBenchmarks .
RUN dotnet publish -c Release -o out

FROM debian:stretch-20181226 AS runtime

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
        gdb \
        autoconf \
        libtool \
        automake \
        cmake \
        gettext \
        python

# Install Mono.
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    echo "deb https://download.mono-project.com/repo/debian nightly-stretch main" | tee /etc/apt/sources.list.d/mono-official-nightly.list && \
    echo "deb https://download.mono-project.com/repo/debian preview-stretch main" | tee /etc/apt/sources.list.d/mono-official-preview.list && \
    apt-get update && \
    apt-cache madison mono-devel && \
    apt-get install -y mono-devel=6.3.0.688-0nightly1+debian9b1 \
        mono-dbg=6.3.0.688-0nightly1+debian9b1 \
        mono-runtime-dbg=6.3.0.688-0nightly1+debian9b1

# Install Perfcollect
WORKDIR /
RUN curl -OL https://aka.ms/perfcollect && \
    chmod +x perfcollect && \
    ./perfcollect install

# Install Wrk
RUN apt-get install -y wrk

# Copy the test into the container.
WORKDIR /app
COPY --from=build /app/out ./
COPY Benchmarks/appsettings.json ./appsettings.json

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENTRYPOINT /bin/bash

# Manually run the app.
#ENTRYPOINT ["mono", "--jitmap", "--server", "--gc=sgen", "--gc-params=mode=throughput", "PlatformBenchmarks.exe"]
#ENTRYPOINT ["mono", "--llvm", "--jitmap", "--server", "--gc=sgen", "--gc-params=mode=throughput", "PlatformBenchmarks.exe"]
