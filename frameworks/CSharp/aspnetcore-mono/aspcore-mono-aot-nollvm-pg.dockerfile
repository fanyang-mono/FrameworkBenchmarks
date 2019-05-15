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
    apt-get install -y mono-devel=6.3.0.620-0nightly1+debian9b1

# AOT the framework.
RUN for i in /usr/lib/mono/gac/*/*/*.dll; do echo "=====" && echo "Starting AOT: $i" && echo "=====" && mono --aot=llvm $i && echo ""; done

# Copy the test into the container.
WORKDIR /app
COPY --from=build /app/out ./
COPY Benchmarks/appsettings.postgresql.json ./appsettings.json

# Remove desktop assemblies blocked by mono.  These will be pulled from the previously AOT'd mono implementation.
RUN rm System.Globalization.Extensions.dll System.IO.Compression.dll System.Net.Http.dll System.Threading.Overlapped.dll

# AOT the test.
RUN for i in *.dll; do echo "=====" && echo "Starting AOT: $i" && echo "=====" && mono --aot=llvm $i && echo ""; done
RUN for i in *.exe; do echo "=====" && echo "Starting AOT: $i" && echo "=====" && mono --aot=llvm $i && echo ""; done

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENTRYPOINT ["mono", "--server", "--gc=sgen", "--gc-params=mode=throughput", "PlatformBenchmarks.exe"]
