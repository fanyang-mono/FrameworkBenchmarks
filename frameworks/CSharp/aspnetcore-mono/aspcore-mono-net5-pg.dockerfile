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

# Download and install the .NET Core SDK.
WORKDIR /dotnet
RUN curl -OL https://download.visualstudio.microsoft.com/download/pr/7e4b403c-34b3-4b3e-807c-d064a7857fe8/95c738f08e163f27867e38c602a433a1/dotnet-sdk-3.0.100-preview5-011568-linux-x64.tar.gz && \
    tar -xzvf dotnet-sdk-3.0.100-preview5-011568-linux-x64.tar.gz
ENV PATH=${PATH}:/dotnet

# Clone the test repo.
WORKDIR /src
RUN git clone https://github.com/brianrob/benchmarks && \
    cd benchmarks && \
    git checkout a4e0d1ae98e670e01e28d6715aa59fa2bb4f2632

# Build the app.
ENV BenchmarksTargetFramework netcoreapp3.0
ENV MicrosoftAspNetCoreAppPackageVersion 3.0.0-preview5-19227-01
ENV MicrosoftNETCoreAppPackageVersion 3.0.0-preview5-27626-15
WORKDIR /src/benchmarks/src/Benchmarks
RUN dotnet publish -c Release -f netcoreapp3.0 --self-contained -r linux-x64 /p:TargetFramework=netcoreapp3.0

# Restore the mono binaries.
ENV MONO_PKG_VERSION 6.3.0.621
WORKDIR /src
RUN git clone https://github.com/brianrob/tests && \
    cd tests/managed/restore_net5 && \
    dotnet restore && \
    cp ~/.nuget/packages/runtime.linux-x64.microsoft.netcore.runtime.mono/${MONO_PKG_VERSION}/runtimes/linux-x64/native/* \
    /src/benchmarks/src/Benchmarks/bin/Release/netcoreapp3.0/linux-x64/publish

WORKDIR /src/benchmarks/src/Benchmarks/bin/Release/netcoreapp3.0/linux-x64/publish
RUN mv libmonosgen-2.0.so libcoreclr.so

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENV ASPNETCORE_KestrelTransport Sockets
ENV ASPNETCORE_nonInteractive true
ENTRYPOINT ["./Benchmarks", "scenarios=DbFortunesRaw"]
