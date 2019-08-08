FROM debian:stretch-20181226

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
        python \
        libunwind8 \
        icu-devtools
# Install perfcollect
WORKDIR /tools
RUN curl -OL https://aka.ms/perfcollect && \
    chmod +x perfcollect && \
    ./perfcollect install

# Download and install the .NET Core SDK.
WORKDIR /dotnet
RUN curl -OL https://download.visualstudio.microsoft.com/download/pr/c624c5d6-0e9c-4dd9-9506-6b197ef44dc8/ad61b332f3abcc7dec3a49434e4766e1/dotnet-sdk-3.0.100-preview7-012821-linux-x64.tar.gz && \
    tar -xzvf dotnet-sdk-3.0.100-preview7-012821-linux-x64.tar.gz
ENV PATH=${PATH}:/dotnet

# Clone the test repo.
WORKDIR /src
RUN git clone https://github.com/aspnet/aspnetcore

# Build the app.
ENV BenchmarksTargetFramework netcoreapp3.0
ENV MicrosoftAspNetCoreAppPackageVersion 3.0.0-preview7.19365.7
ENV MicrosoftNETCoreAppPackageVersion 3.0.0-preview7-27912-14
WORKDIR /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks
RUN dotnet publish -c Release -f netcoreapp3.0 --self-contained -r linux-x64

# Restore the mono binaries.
ENV MONO_PKG_VERSION 6.3.0.621
WORKDIR /src
RUN git clone https://github.com/brianrob/tests && \
    cd tests/managed/restore_net5 && \
    dotnet restore && \
    cp ~/.nuget/packages/runtime.linux-x64.microsoft.netcore.runtime.mono/${MONO_PKG_VERSION}/runtimes/linux-x64/native/* \
    /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp3.0/linux-x64/publish

WORKDIR /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp3.0/linux-x64/publish
RUN mv libmonosgen-2.0.so libcoreclr.so

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENV MONO_ENV_OPTIONS --server --gc=sgen --gc-params=mode=throughput --jitmap
ENTRYPOINT ["./PlatformBenchmarks"]
