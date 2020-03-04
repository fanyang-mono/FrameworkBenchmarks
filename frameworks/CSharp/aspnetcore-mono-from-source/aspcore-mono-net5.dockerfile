FROM ubuntu:18.04

ARG MONO_DOCKER_GIT_HASH="HEAD"
ARG MONO_DOCKER_MAKE_JOBS="4"
ARG AspNetCoreAppPackageVersion="5.0.0-preview.1.20111.6"
ARG NETCorePackageVersion="5.0.0-alpha.1.20112.1"

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
	locales

# Change locale
RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8  

# Build mono from source; patch local dotnet
# We have specified a commit hash here
WORKDIR /src
RUN mkdir mono_runtime && \
    cd mono_runtime && \
    git clone -j8 https://github.com/dotnet/runtime.git && \
    cd runtime && \
    git checkout $MONO_DOCKER_GIT_HASH

WORKDIR /src/mono_runtime/runtime
RUN ./build.sh --subsetCategory mono -c Release /p:__BuildType=Release

# Clone the test repo.
WORKDIR /src
RUN git clone https://github.com/aspnet/Benchmarks.git

# Build the app and copy over Mono runtime.
ENV BenchmarksTargetFramework netcoreapp5.0
ENV MicrosoftAspNetCoreAppPackageVersion $AspNetCoreAppPackageVersion
ENV MicrosoftNETCoreAppPackageVersion $NETCorePackageVersion
WORKDIR /src/mono_runtime/runtime
RUN .dotnet/dotnet publish -c Release -f netcoreapp5.0 --self-contained -r linux-x64 /src/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks && \
    cp artifacts/obj/mono/Linux.x64.Release/mono/mini/.libs/libmonosgen-2.0.so /src/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks/bin/Release/netcoreapp5.0/linux-x64/publish/libcoreclr.so && \
    cp artifacts/bin/mono/Linux.x64.Release/System.Private.CoreLib.dll /src/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks/bin/Release/netcoreapp5.0/linux-x64/publish/

WORKDIR /src/Benchmarks/src/BenchmarksApps/Kestrel/PlatformBenchmarks/bin/Release/netcoreapp5.0/linux-x64/publish

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENV MONO_ENV_OPTIONS  --server --gc=sgen --gc-params=mode=throughput
ENTRYPOINT ["./PlatformBenchmarks"]

