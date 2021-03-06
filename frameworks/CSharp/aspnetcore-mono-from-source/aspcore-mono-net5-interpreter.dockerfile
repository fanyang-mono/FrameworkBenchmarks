FROM ubuntu:18.04

ARG MONO_DOCKER_GIT_HASH="HEAD"
ARG BENCHMARK_DOCKER_GIT_HASH="HEAD"
ARG DOTNET_SDK_VER="5.0.100-preview.5.20228.3"

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
        clang-9 \
        llvm-9 \
        autoconf \
        libtool \
        automake \
        cmake \
        build-essential \
        curl \
        gettext \
        python \
        libunwind8 \
        libunwind8-dev \
        icu-devtools \
        libicu-dev \
        liblttng-ust-dev \
        libssl-dev \
        libkrb5-dev \
        locales \
	libxml2-dev \
	apt-transport-https \
	ca-certificates \
	gnupg \
	software-properties-common \
	wget

# Install cmake (at least 3.15.5)
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add - && \
    apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main' && \
    apt-get update && \
    apt-get install -y cmake

# Change locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /dotnet
RUN curl -OL https://dotnetcli.azureedge.net/dotnet/Sdk/$DOTNET_SDK_VER/dotnet-sdk-$DOTNET_SDK_VER-linux-x64.tar.gz && \
    tar -xzvf dotnet-sdk-$DOTNET_SDK_VER-linux-x64.tar.gz
ENV PATH=${PATH}:/dotnet

# Build mono from source; patch local dotnet
# We have specified a commit hash here
WORKDIR /src
RUN mkdir mono_runtime && \
    cd mono_runtime && \
    git clone -j8 https://github.com/dotnet/runtime.git && \
    cd runtime && \
    git checkout $MONO_DOCKER_GIT_HASH

WORKDIR /src/mono_runtime/runtime
RUN ./build.sh -c Release

# Clone the test repo.
WORKDIR /src
RUN git clone https://github.com/aspnet/Benchmarks.git && \
    cd Benchmarks && \
    git checkout $BENCHMARK_DOCKER_GIT_HASH

# Build the app and copy over Mono runtime
WORKDIR /src/mono_runtime/runtime
ENV BenchmarksTargetFramework netcoreapp5.0
RUN export MicrosoftAspNetCoreAppPackageVersion=$(.dotnet/dotnet --list-runtimes | grep -i "Microsoft.AspNetCore.App" | awk '{split($0,a," ");print a[2]}')
RUN export MicrosoftNETCoreAppPackageVersion=$(.dotnet/dotnet --list-runtimes | grep -i "Microsoft.NETCore.App" | awk '{split($0,a," ");print a[2]}')
RUN dotnet publish -c Release -f netcoreapp5.0 --self-contained -r linux-x64 /src/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks && \
     cp artifacts/obj/mono/Linux.x64.Release/mono/mini/.libs/libmonosgen-2.0.so /src/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks/bin/Release/netcoreapp5.0/linux-x64/publish/libcoreclr.so && \
     cp artifacts/bin/mono/Linux.x64.Release/System.Private.CoreLib.dll /src/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks/bin/Release/netcoreapp5.0/linux-x64/publish/

WORKDIR /src/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks/bin/Release/netcoreapp5.0/linux-x64/publish

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENV MONO_ENV_OPTIONS --interpreter --server --gc=sgen --gc-params=mode=throughput
ENTRYPOINT ["./PlatformBenchmarks"]
