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

RUN mono --aot=llvm /usr/lib/mono/4.5/mscorlib.dll
RUN for i in /usr/lib/mono/gac/*/*/*.dll; do mono --aot=llvm $i; done

ENV ASPNETCORE_URLS http://+:8080
ENV KestrelTransport Libuv
WORKDIR /app
COPY --from=build /app/out ./
COPY Benchmarks/appsettings.json ./appsettings.json

ENTRYPOINT ["mono", "--server", "--gc=sgen", "--gc-params=mode=throughput", "PlatformBenchmarks.exe"]
