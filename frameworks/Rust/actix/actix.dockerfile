FROM rust:1.36 AS build

ADD ./ /actix
WORKDIR /actix

RUN cargo clean
RUN RUSTFLAGS="-C target-cpu=native" cargo build --release


FROM debian:stretch AS runtime

COPY --from=0 /actix/target/release/actix /actix


CMD /actix
