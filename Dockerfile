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

FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        binutils \
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

# DISCORD_SDK=0 avoids shipping discord_game_sdk.so.
# DEBUG_INFO_LEVEL=0 shrinks the binary (headless does not need -g).
# Headless mode is selected at runtime via --headless.
# On aarch64 the binary is named sm64coopdx.arm — normalize for the runtime stage.
RUN make -j"$(nproc)" DISCORD_SDK=0 DEBUG_INFO_LEVEL=0 \
    && if [ -e build/us_pc/sm64coopdx.arm ] && [ ! -e build/us_pc/sm64coopdx ]; then \
         cp -a build/us_pc/sm64coopdx.arm build/us_pc/sm64coopdx; \
       fi \
    && strip --strip-unneeded build/us_pc/sm64coopdx \
    && test -x build/us_pc/sm64coopdx

FROM debian:bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Binary still links libGL/libSDL2 even with --headless (dummy backends).
# Install the shared libs, then drop Mesa DRI + LLVM (~150MB) — never used headless.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        libcurl4 \
        libgl1 \
        libsdl2-2.0-0 \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
        /usr/lib/*/dri \
        /usr/lib/*/libLLVM* \
        /usr/share/doc \
        /usr/share/man

WORKDIR /opt/sm64coopdx

# Binary + tiny runtime data. Built-in mods (~30MB, mostly arena) are omitted;
# enable mods from the /data volume (NFS) instead.
COPY --from=build /src/build/us_pc/sm64coopdx ./
COPY --from=build /src/build/us_pc/dynos ./dynos
COPY --from=build /src/build/us_pc/lang ./lang
COPY --from=build /src/build/us_pc/palettes ./palettes
RUN mkdir -p mods

# Persist config/saves/mods and provide baserom.us.z64 via this mount.
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
