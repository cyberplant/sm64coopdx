# Headless dedicated server image (no ROM in the image).
#
# Build (no baserom required — assets load from ROM at runtime):
#   docker build -t sm64coopdx:headless .
#
# Run (mount a directory that contains a vanilla US baserom.us.z64):
#   docker run --rm -p 7777:7777/udp \
#     -v /path/to/data:/data \
#     sm64coopdx:headless
#
# Optional: use the build stage as a toolchain (bind-mount source like before):
#   docker build --target build -t sm64coopdx:build .
#   docker run --rm -v "$(pwd)":/src -w /src sm64coopdx:build make -j$(nproc)

# syntax=docker/dockerfile:1

FROM ubuntu:22.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        bsdmainutils \
        build-essential \
        ca-certificates \
        git \
        libcurl4-openssl-dev \
        libglew-dev \
        libsdl2-dev \
        libz-dev \
        pkg-config \
        python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# DISCORD_SDK=0 avoids shipping discord_game_sdk.so in the server image.
# Headless mode is selected at runtime via --headless (no HEADLESS make flag).
# On aarch64 the binary is named sm64coopdx.arm — normalize for the runtime stage.
RUN make -j"$(nproc)" DISCORD_SDK=0 \
    && if [ -e build/us_pc/sm64coopdx.arm ] && [ ! -e build/us_pc/sm64coopdx ]; then \
         cp -a build/us_pc/sm64coopdx.arm build/us_pc/sm64coopdx; \
       fi \
    && test -x build/us_pc/sm64coopdx

FROM ubuntu:22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Linked at build time even when --headless keeps the dummy gfx/audio backends.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        libcurl4 \
        libglew2.2 \
        libgl1 \
        libsdl2-2.0-0 \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/sm64coopdx

COPY --from=build /src/build/us_pc/sm64coopdx ./
COPY --from=build /src/build/us_pc/dynos ./dynos
COPY --from=build /src/build/us_pc/lang ./lang
COPY --from=build /src/build/us_pc/mods ./mods
COPY --from=build /src/build/us_pc/palettes ./palettes

# Persist config/saves and provide baserom.us.z64 via this mount.
VOLUME ["/data"]

EXPOSE 7777/udp

ENTRYPOINT ["./sm64coopdx"]
CMD [ \
    "--headless", \
    "--server", "7777", \
    "--savepath", "/data", \
    "--hide-loading-screen", \
    "--skip-update-check", \
    "--no-discord" \
]
