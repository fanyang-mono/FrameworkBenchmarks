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
RUN curl -OL https://download.visualstudio.microsoft.com/download/pr/c624c5d6-0e9c-4dd9-9506-6b197ef44dc8/ad61b332f3abcc7dec3a49434e4766e1/dotnet-sdk-3.0.100-preview7-012821-linux-x64.tar.gz && \
    tar -xzvf dotnet-sdk-3.0.100-preview7-012821-linux-x64.tar.gz
ENV PATH=${PATH}:/dotnet

# Clone the test repo.
WORKDIR /src
RUN git clone https://github.com/aspnet/aspnetcore && \
    cd aspnetcore && \
    git checkout e9179ba

# Build the app.
ENV BenchmarksTargetFramework netcoreapp3.0
ENV MicrosoftAspNetCoreAppPackageVersion 3.0.0-preview7.19365.7
ENV MicrosoftNETCoreAppPackageVersion 3.0.0-preview7-27912-14
WORKDIR /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks
RUN dotnet publish -c Release -f netcoreapp3.0 --self-contained -r linux-x64

# Restore the mono binaries.
WORKDIR /src
RUN git clone https://github.com/brianrob/tests && \
    cd tests/managed/restore_net5 && \
    dotnet restore 
    

# Build mono from source with llvm support; patch system wide .Net
RUN git clone -j8 https://github.com/mono/mono.git

WORKDIR /src/mono

RUN scripts/update_submodules.sh && \
    ./autogen.sh --with-core=only --enable-llvm && \
    make -j 2 && \
    cd netcore && \
    make runtime && \
    make bcl && \
    make patch-local-dotnet && \
    cp /src/mono/mono/mini/.libs/libmonosgen-2.0.so /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp3.0/linux-x64/publish/libcoreclr.so && \
    cp /src/mono/netcore/System.Private.CoreLib/bin/x64/System.Private.CoreLib.dll  /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp3.0/linux-x64/publish/

RUN for assembly in /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp3.0/linux-x64/publish/*.dll; do \
        echo "=====" && echo "Starting AOT: $assembly" && echo "=====" && \
        PATH="llvm/usr/bin/:${PATH}" \
	MONO_ENV_OPTIONS="--aot=llvm,llvmllc=\"-mcpu=native\"" \
	.dotnet/dotnet $assembly && \
        echo ""; \
    done

WORKDIR /src/aspnetcore/src/Servers/Kestrel/perf/PlatformBenchmarks/bin/Release/netcoreapp3.0//linux-x64/

# Run the test.
ENV ASPNETCORE_URLS http://+:8080
ENV MONO_ENV_OPTIONS --server --gc=sgen --gc-params=mode=throughput
ENTRYPOINT ["./PlatformBenchmarks"]
