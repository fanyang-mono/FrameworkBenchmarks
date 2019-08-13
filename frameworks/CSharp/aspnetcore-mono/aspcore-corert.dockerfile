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

# Install dependencies for CoreRT compiler.
RUN apt-get install -y clang-3.9

# Clone the test repo.
WORKDIR /src
RUN git clone https://github.com/brianrob/FrameworkBenchmarks

# Build the app.
WORKDIR /src/FrameworkBenchmarks/frameworks/CSharp/aspnetcore-corert/PlatformBenchmarks
RUN dotnet publish -c Release -f netcoreapp2.2 --self-contained -r linux-x64

# Run the test.
WORKDIR /src/FrameworkBenchmarks/frameworks/CSharp/aspnetcore-corert/PlatformBenchmarks/bin/Release/netcoreapp2.2/linux-x64/publish
ENV ASPNETCORE_URLS http://+:8080
ENTRYPOINT ["./PlatformBenchmarks"]
