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
  `dpkg-deb`, `curl`, `tar`, `gzip` and the compiler runtime libraries
  required by the selected Sailfish SDK toolchain

Install `libxkbcommon-dev` on Ubuntu or Debian when the matching development
headers are not installed in the SDK target. Some Sailfish cross compilers
also require a 32-bit `libmpc.so.3`. When `--toolchain-dir` points into the
standard Sailfish SDK tooling tree, the preparation script automatically uses
the matching runtime libraries from that tree. For other toolchain layouts,
install `libmpc3` on the host or pass `--toolchain-lib-dir`.

The environment check compiles a minimal C and C++ source file so missing
compiler runtimes or target binutils are reported before the full build begins.

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
- stages the xkbcommon headers from the SDK target or host development package;
- detects the matching runtime-library directory for a standard Sailfish SDK
  toolchain;
- exposes the SDK's target assembler and linker to the cross compiler;
- creates an `environment.sh` file containing the selected target settings.

No files from `build/dependencies/` are committed or included in source
archives.

If the SDK toolchain binaries are not already in `PATH`, also pass their
directory. The compiler prefix is detected from standard Sailfish SDK
toolchains; pass it explicitly only when that detection is not suitable:

```sh
scripts/prepare-build-environment.sh \
    --arch armv7hl \
    --sysroot /path/to/SailfishOS-armv7hl \
    --toolchain-dir /path/to/toolchain/bin \
    --tool-prefix armv7hl-meego-linux-gnueabi
```

For example, a standard Sailfish OS 5.1 aarch64 installation can be prepared
without temporary compiler wrappers:

```sh
scripts/prepare-build-environment.sh \
    --arch aarch64 \
    --sysroot /srv/sailfishos/targets/SailfishOS-5.1-aarch64 \
    --toolchain-dir /srv/sailfishos/toolings/SailfishOS-5.1/opt/cross/bin
```

Use `--xkb-include-root` or `--toolchain-lib-dir` only for a nonstandard SDK
layout. The generated `environment.sh` records both paths, so no manual
`LD_LIBRARY_PATH`, compiler wrapper, or `/tmp` staging is needed.

## Build

Build the bundled Android autofill companion once before packaging any CPU
architecture. It needs JDK 17, Gradle 8.7 and Android SDK platform 35 with
Android Gradle Plugin 8.6.1. The APK itself is architecture independent.

On Windows, pass the installed tool directory without recording local paths
in the source tree:

```powershell
scripts/build-android-autofill.ps1 -ToolRoot /path/to/android-tools
```

The script writes `build/android/FutoAutofill.apk`. Its release signing key
and password are kept outside the repository under the user's local application
data, with restricted permissions. Back up both signing files: replacing the
key prevents in-place updates of an already installed companion.

On another build host, provide `FUTO_ANDROID_RELEASE_KEYSTORE` and
`FUTO_ANDROID_RELEASE_PASSWORD`, set `ANDROID_HOME`, run Gradle's
`:app:assembleRelease` task in `android-companion/`, and copy the signed APK
to `build/android/FutoAutofill.apk`. Never commit signing files or include
Android build caches in a source archive.

The native build also produces `futo-keyboard-device-auth`. The RPM installs it
as root-owned, set-group-ID `privileged` (mode 2755). It accepts only the packaged
helper as its parent, clears user-controlled Qt import paths, and requests the
system's security-code/fingerprint authentication with the normal device-unlock
component in a system overlay (no app card). It also reuses the optional installed
Pattern Lock component. Only trusted runtime paths and session endpoints are used.
Do not replace this authentication with a simple permission confirmation.

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
