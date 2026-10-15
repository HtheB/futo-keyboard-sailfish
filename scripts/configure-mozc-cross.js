#!/usr/bin/env node
"use strict";

// Generate a local target toolchain using Bazel's own Unix configuration.
// All host-specific paths live in the ignored dependency checkout, not here.
const fs = require("fs"), path = require("path"), cp = require("child_process");
const [source, bazelConfig, prefix, sysroot, architecture] = process.argv.slice(2);
if (!source || !bazelConfig || !prefix || !sysroot || !["aarch64", "armv7hl", "i486"].includes(architecture))
    throw new Error("Usage: configure-mozc-cross.js MOZC_SOURCE BAZEL_CC_CONFIG TOOL_PREFIX SYSROOT ARCH");
const target = path.join(source, "futo_cross");
fs.mkdirSync(target, {recursive: true});
const shim = path.join(target, "bin");
fs.mkdirSync(shim, {recursive: true});
for (const name of ["as", "ld", "ar", "nm", "strip", "objcopy", "ranlib"]) {
    const link = path.join(shim, name);
    let previous;
    try { previous = fs.lstatSync(link); } catch (error) { if (error.code !== "ENOENT") throw error; }
    if (previous && (!previous.isSymbolicLink() || fs.readlinkSync(link) !== prefix + name)) {
        if (!previous.isSymbolicLink()) throw new Error("Unexpected non-symlink tool in generated toolchain");
        fs.unlinkSync(link);
        previous = null;
    }
    if (!previous) fs.symlinkSync(prefix + name, link);
}
fs.copyFileSync(bazelConfig, path.join(target, "cc_toolchain_config.bzl"));
const compiler = prefix + "gcc";
const probe = cp.spawnSync(compiler, ["--sysroot=" + sysroot, "-E", "-x", "c++", "-", "-v"],
    {input: "", encoding: "utf8"});
if (probe.status !== 0) throw new Error("Target compiler probe failed");
const includes = probe.stderr.split("#include <...> search starts here:")[1]
    .split("End of search list.")[0].trim().split("\n").map(line => path.resolve(line.trim()));
const q = JSON.stringify;
// The SDK tooling may require its host runtime to execute the compiler.
// Capture only that build environment, never any credential or user data.
const wrapper = path.join(target, "compiler.sh");
fs.writeFileSync(wrapper, "#!/bin/bash\nexport LD_LIBRARY_PATH=" +
    q(process.env.LD_LIBRARY_PATH || "") + "\nexec " + q(compiler) + " \"$@\"\n", {mode: 0o755});
fs.chmodSync(wrapper, 0o755);
const tools = {gcc: wrapper};
for (const name of ["ar", "ld", "cpp", "gcov", "nm", "objcopy", "objdump", "strip"])
    tools[name] = prefix + name;
tools.dwp = "/usr/bin/dwp";
const cpu = {aarch64: "aarch64", armv7hl: "armv7", i486: "x86_32"}[architecture];
const extra = architecture === "armv7hl" ? ["-mfp16-format=ieee"] : [];
const compileFlags = ["-O2", "-DNDEBUG", "-fPIC", "-funsigned-char", "-pthread",
    "-B" + shim + "/",
    "-ffile-prefix-map=" + source + "=mozc", "-fmacro-prefix-map=" + source + "=mozc"].concat(extra);
const text = `load(":cc_toolchain_config.bzl", "cc_toolchain_config")
load("@rules_cc//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")
package(default_visibility = ["//visibility:public"])
filegroup(name = "empty", srcs = [])
cc_toolchain_config(
    name = "config", cpu = ${q(architecture)}, compiler = "gcc",
    toolchain_identifier = "futo-sailfish", host_system_name = "linux",
    target_system_name = "linux", target_libc = "glibc",
    abi_version = "gcc", abi_libc_version = "glibc",
    builtin_sysroot = ${q(sysroot)}, cxx_builtin_include_directories = ${q(includes)},
    tool_paths = ${q(tools)}, compile_flags = ${q(compileFlags)},
    cxx_flags = ["-std=c++20"],
    link_flags = [${q("-B" + shim + "/")}, "-pthread", "-static-libgcc", "-Wl,--gc-sections"],
    link_libs = ["-Wl,-Bstatic", "-lstdc++", "-Wl,-Bdynamic", "-lm", "-ldl"],
    supports_start_end_lib = False,
)
cc_toolchain(
    name = "compiler", toolchain_identifier = "futo-sailfish",
    toolchain_config = ":config", all_files = ":empty", ar_files = ":empty",
    as_files = ":empty", compiler_files = ":empty", dwp_files = ":empty",
    linker_files = ":empty", objcopy_files = ":empty", strip_files = ":empty",
    supports_param_files = 1,
)
platform(name = "platform", constraint_values = ["@platforms//os:linux", "@platforms//cpu:${cpu}"])
toolchain(
    name = "registered", toolchain = ":compiler",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    exec_compatible_with = ["@platforms//os:linux", "@platforms//cpu:x86_64"],
    target_compatible_with = ["@platforms//os:linux", "@platforms//cpu:${cpu}"],
)
`;
fs.writeFileSync(path.join(target, "BUILD.bazel"), text);
console.log("Generated local Sailfish Mozc toolchain: " + architecture);
