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
    apt-get install -y mono-devel=6.3.0.688-0nightly1+debian9b1

# AOT the framework.
RUN i=/usr/lib/mono/4.5/mscorlib.dll && echo "=====" && echo "Starting AOT: $i" && echo "=====" && mono --aot=fullaot $i && echo ""; done
RUN for i in /usr/lib/mono/gac/*/*/*.dll; do echo "=====" && echo "Starting AOT: $i" && echo "=====" && mono --aot=fullaot $i && echo ""; done

# Copy the test into the container.
WORKDIR /app
COPY --from=build /app/out ./
COPY Benchmarks/appsettings.json ./appsettings.json

# AOT the test.
RUN for i in *.dll; do echo "=====" && echo "Starting AOT: $i" && echo "=====" && mono --aot=fullaot $i && echo ""; done
RUN for i in *.exe; do echo "=====" && echo "Starting AOT: $i" && echo "=====" && mono --aot=fullaot $i && echo ""; done

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENTRYPOINT ["mono", "--full-aot", "--server", "--gc=sgen", "--gc-params=mode=throughput", "PlatformBenchmarks.exe"]
