FROM debian:stretch-20181226

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
        python \
        libunwind8 \
        icu-devtools

# Download and install the .NET Core SDK.
WORKDIR /dotnet
RUN curl -OL https://dotnetcli.azureedge.net/dotnet/Sdk/5.0.100-alpha1-014854/dotnet-sdk-5.0.100-alpha1-014854-linux-x64.tar.gz && \
    tar -xzvf dotnet-sdk-5.0.100-alpha1-014854-linux-x64.tar.gz
ENV PATH=${PATH}:/dotnet

# Clone the test repo.
WORKDIR /src
RUN git clone https://github.com/aspnet/aspnetcore &&\
    cd aspnetcore &&\
    git checkout 88ca28ba2330984ddcf20d91690a5929b40577bc

# Build the app.
ENV BenchmarksTargetFramework netcoreapp5.0
ENV MicrosoftAspNetCoreAppPackageVersion 5.0.0-alpha1.19470.6
ENV MicrosoftNETCoreAppPackageVersion 5.0.0-alpha1.19507.3
WORKDIR /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks
RUN dotnet publish -c Release -f netcoreapp5.0 --self-contained -r linux-x64

# Build mono from source with llvm support; patch system wide .Net
WORKDIR /src
RUN git clone --recurse-submodules -j8 https://github.com/mono/mono.git && \
    cd mono && \
    git checkout $MONO_DOCKER_GIT_HASH

WORKDIR /src/mono
RUN ./autogen.sh --with-core=only --enable-llvm && \
    make -j $MONO_DOCKER_MAKE_JOBS && \
    cd netcore && \
    make runtime && \
    make bcl && \
    make patch-local-dotnet && \
    cp /src/mono/mono/mini/.libs/libmonosgen-2.0.so /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp5.0/linux-x64/publish/libcoreclr.so && \
    cp /src/mono/netcore/System.Private.CoreLib/bin/x64/System.Private.CoreLib.dll  /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp5.0/linux-x64/publish/

RUN for assembly in /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp5.0/linux-x64/publish/*.dll; do \
        echo "=====" && echo "Starting AOT: $assembly" && echo "=====" && \
        PATH="llvm/usr/bin/:${PATH}" \
	MONO_ENV_OPTIONS="--aot=llvm,llvmllc=\"-mcpu=native\"" \
	.dotnet/dotnet $assembly && \
        echo ""; \
    done

WORKDIR /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp5.0//linux-x64/

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENV MONO_ENV_OPTIONS --server --gc=sgen --gc-params=mode=throughput
ENTRYPOINT ["./PlatformBenchmarks"]
