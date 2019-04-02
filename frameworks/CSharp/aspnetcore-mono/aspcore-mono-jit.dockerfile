FROM microsoft/dotnet:2.2-sdk AS build
WORKDIR /app
COPY PlatformBenchmarks .
RUN dotnet publish -c Release -o out

FROM debian:stretch-20181226 AS runtime

RUN apt-get update && \
    apt-get install -y \
        make \
        git \
        gcc \
        g++ \
        autoconf \
        libtool \
        automake \
        cmake \
        gettext \
        python && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y gpg wget apt-transport-https dirmngr && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --no-tty --dearmor > microsoft.asc.gpg && \
    mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/ && \
    wget -q https://packages.microsoft.com/config/debian/9/prod.list && \
    mv prod.list /etc/apt/sources.list.d/microsoft-prod.list && \
    chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg && \
    chown root:root /etc/apt/sources.list.d/microsoft-prod.list && \
    apt-get update && \
    apt-get -y install \
        dotnet-sdk-2.2 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/mono/mono -b 2019-02

WORKDIR /src/mono
#RUN ./autogen.sh --disable-boehm --enable-llvm=yes && \
RUN CFLAGS="-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security" CPPFLAGS="-D_FORTIFY_SOURCE=2" LDFLAGS="-Wl,-Bsymbolic-functions -Wl,-z,relro" PATH="/usr/lib/mono/llvm/bin:/usr/sbin:/usr/bin:/sbin:/bin"  ./autogen.sh --build x86_64-linux-gnu --with-sgen=yes --enable-llvm=yes --prefix=/usr/local --mandir=\${prefix}/share/man --infodir=\${prefix}/share/info --sysconfdir=/etc --with-ikvm-native=no --disable-quiet-build --disable-system-aot && \
    make -j8 && \
    make install
ENV PATH="/src/mono/llvm/usr/bin:${PATH}"
RUN mono --aot=llvm /usr/local/lib/mono/4.5/mscorlib.dll

ENV ASPNETCORE_URLS http://+:8080
WORKDIR /app
COPY --from=build /app/out ./
COPY Benchmarks/appsettings.json ./appsettings.json

ENTRYPOINT ["mono", "--server", "--gc=sgen", "--gc-params=mode=throughput", "PlatformBenchmarks.exe"]
