# SheenBidi

[`SheenBidi`](https://github.com/Tehreer/SheenBidi) packaged for the [Zig](https://ziglang.org/) build system.

## Status

Mostly untested:

* Tests are passing on `aarch64-macos`/`x86_64-macos`
* Compatible with Zig `0.14.0` and `0.15.0-dev.1184+c41ac8f19`

## Usage

```zig
const sheenbidi_dep = b.dependency("SheenBidi", .{
    .target = target,
    .optimize = optimize,
});
exe.linkLibrary(sheenbidi_dep.artifact("SheenBidi"));
```

## Testing

```sh
# builds the test executable and copies upstream `Tools/Unicode` to `bin/UnicodeData`
zig build -Dbuild-tests
# run the tests
./zig-out/bin/sheenbidi_tests ./zig-out/bin/UnicodeData
```

## Dependencies

`SheenBidi` only depends on libc (and libc++ for the generator and tests).
