# Building FUTO Keyboard for Sailfish OS

The repository contains the keyboard, prediction engine, helper services,
dictionary sources and voice-input sources. Native components must be linked
against a matching Sailfish OS SDK target; target libraries are not copied
into Git.

## Requirements

- A Linux build environment or the Sailfish SDK build shell
- A Sailfish SDK target matching the device release and architecture
- The matching cross compiler for `aarch64`, `armv7hl` or `i486`
- GCC/G++, Go, Node.js, Python 3, Perl, Make, RPM tools, `patchelf`,
  `dpkg-deb`, `curl`, `tar` and `gzip`

The SDK target needs the Qt 5 base/Wayland development files and Sailfish
Secrets development files. In particular, it must contain Qt's `qconfig.h`,
`qfeatures.h` and the runtime libraries checked by the preparation script.

## Prepare the local dependencies

From a fresh checkout, point the preparation script at the matching Sailfish
SDK target root:

```sh
scripts/prepare-build-environment.sh \
    --arch aarch64 \
    --sysroot /path/to/the/Sailfish-SDK-target
```

The script:

- downloads and checksum-verifies the pinned Qt 5.6.3 and Sailfish Secrets
  0.2.44 sources;
- copies the required target libraries and Qt configuration headers into the
  ignored `build/dependencies/` directory;
- creates an `environment.sh` file containing the selected target settings.

No files from `build/dependencies/` are committed or included in source
archives.

If the SDK toolchain binaries are not already in `PATH`, also pass their
directory and, when necessary, the compiler prefix:

```sh
scripts/prepare-build-environment.sh \
    --arch armv7hl \
    --sysroot /path/to/SailfishOS-armv7hl \
    --toolchain-dir /path/to/toolchain/bin \
    --tool-prefix armv7hl-meego-linux-gnueabi
```

## Build

Load the generated environment, verify it, and build:

```sh
source build/dependencies/aarch64/environment.sh
scripts/check-build-environment.sh
scripts/build-rpm.sh
```

Repeat the preparation step with a matching SDK target for each architecture.
The RPM, source archive, content packs and checksums are written below
`build/`.

The build scripts also accept direct overrides such as `FUTO_CXX`, `FUTO_CC`,
`FUTO_STRIP`, `FUTO_READELF`, `FUTO_TARGET_SYSROOT`, `FUTO_TARGET_LIB_ROOT`,
`FUTO_QT_SOURCE` and `FUTO_SECRETS_SOURCE` for unusual SDK layouts.

## Adding another prediction engine

An additional engine such as libgooglepinyin should be built with the same
architecture-specific toolchain and installed by the RPM into the appropriate
Sailfish library or helper location. Keep its source revision, license and any
generated data documented in `UPSTREAM.md` and `LICENSES/`.
