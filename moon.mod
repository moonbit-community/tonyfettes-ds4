name = "tonyfettes/ds4"

version = "0.1.0"

import {
  "moonbitlang/async@0.19.0",
}

readme = "README.md"

license = "MIT"

keywords = [ "ds4", "ffi", "native" ]

description = "MoonBit native bindings for the local DwarfStar 4 engine"

preferred_target = "native"

options(
  "--moonbit-unstable-prebuild": "build.js",
)