# Copyright 2018 the rules_m4 authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

load(
    "@rules_m4//m4/internal:versions.bzl",
    _VERSION_URLS = "VERSION_URLS",
    _check_version = "check_version",
)
load(
    "@rules_m4//m4/internal:gnulib/gnulib.bzl",
    _gnulib_overlay = "gnulib_overlay",
)

_M4_BUILD = """
cc_library(
    name = "m4_lib",
    srcs = glob([
        "src/*.c",
        "src/*.h",
    ]),
    copts = ["-DHAVE_CONFIG_H", "-UDEBUG"],
    visibility = ["//bin:__pkg__"],
    deps = [
        "//gnulib:config_h",
        "//gnulib",
    ],
)
"""

_M4_BIN_BUILD = """
cc_binary(
    name = "m4",
    visibility = ["//visibility:public"],
    deps = ["//:m4_lib"],
)
"""

def _m4_repository(ctx):
    version = ctx.attr.version
    _check_version(version)
    source = _VERSION_URLS[version]

    ctx.download_and_extract(
        url = source["urls"],
        sha256 = source["sha256"],
        stripPrefix = "m4-{}".format(version),
    )

    _gnulib_overlay(ctx, m4_version = version)

    ctx.file("WORKSPACE", "workspace(name = {name})\n".format(name = repr(ctx.name)))
    ctx.file("BUILD.bazel", _M4_BUILD)
    ctx.file("bin/BUILD.bazel", _M4_BIN_BUILD)

    # Prevent LF -> CRLF conversion on Windows. This deviates from the OS
    # standard behavior to fit with the generally UNIX-ish assumptions made
    # by M4 clients (notably Bison).
    ctx.template("src/output.c", "src/output.c", substitutions = {
        "output_file = stdout;": "output_file = stdout; SET_BINARY(STDOUT_FILENO);",
    }, executable = False)

m4_repository = repository_rule(
    _m4_repository,
    attrs = {
        "version": attr.string(mandatory = True),
        "_gnulib_build": attr.label(
            default = "@rules_m4//m4/internal:gnulib/gnulib.BUILD",
            allow_single_file = True,
        ),
        "_gnulib_config_darwin_h": attr.label(
            default = "//m4/internal:gnulib/config-darwin.h",
            allow_single_file = True,
        ),
        "_gnulib_config_linux_h": attr.label(
            default = "//m4/internal:gnulib/config-linux.h",
            allow_single_file = True,
        ),
        "_gnulib_config_windows_h": attr.label(
            default = "//m4/internal:gnulib/config-windows.h",
            allow_single_file = True,
        ),
    },
)
