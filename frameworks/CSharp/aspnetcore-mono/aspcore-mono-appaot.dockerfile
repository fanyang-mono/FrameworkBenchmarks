FROM microsoft/dotnet:2.2-sdk AS build
WORKDIR /app
COPY PlatformBenchmarks .
RUN dotnet publish -c Release -o out

FROM debian:stretch-20181226 AS runtime

RUN apt-get update && \ 
    apt-get install -y apt-transport-https dirmngr && \
    apt-key adv --no-tty --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    echo "deb https://download.mono-project.com/repo/debian stable-stretch main" | tee /etc/apt/sources.list.d/mono-official-stable.list && \
    apt-get update && \
    apt-get install -y mono-devel && \ 
    rm -rf /var/lib/apt/lists/*

ENV ASPNETCORE_URLS http://+:8080
ENV KestrelTransport Libuv
WORKDIR /app
COPY --from=build /app/out ./
COPY Benchmarks/appsettings.json ./appsettings.json

RUN for i in *.dll; do mono --aot $i; done
RUN mono --aot PlatformBenchmarks.exe

ENTRYPOINT ["mono", "--server", "--gc=sgen", "--gc-params=mode=throughput", "PlatformBenchmarks.exe"]
