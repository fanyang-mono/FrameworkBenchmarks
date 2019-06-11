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
    git checkout c2c56dfd720b7b45fecabc302deff1cbe4fd1f15

# Build the app.
ENV BenchmarksTargetFramework netcoreapp3.0
ENV MicrosoftAspNetCoreAppPackageVersion 3.0.0-preview5-19227-01
ENV MicrosoftNETCoreAppPackageVersion 3.0.0-preview5-27626-15
WORKDIR /src/benchmarks/src/Benchmarks
RUN dotnet publish -c Release -f netcoreapp3.0 --self-contained -r linux-x64 /p:TargetFramework=netcoreapp3.0

# Run the test.
WORKDIR /src/benchmarks/src/Benchmarks/bin/Release/netcoreapp3.0/linux-x64/publish
ENV ASPNETCORE_URLS http://+:8080
ENV ASPNETCORE_KestrelTransport Sockets
ENV ASPNETCORE_nonInteractive true
ENV MONO_ENV_OPTIONS --server --gc=sgen --gc-params=mode=throughput
ENTRYPOINT ["./Benchmarks", "scenarios=DbFortunesRaw"]
