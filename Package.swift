// swift-tools-version:5.9
import PackageDescription

// Compile defines shared across all whisper.cpp / ggml targets.
let sharedDefines: [CSetting] = [
    .define("GGML_USE_ACCELERATE"),
    .define("ACCELERATE_NEW_LAPACK"),
    .define("ACCELERATE_LAPACK_ILP64"),
    .define("GGML_USE_CPU"),
    .define("GGML_USE_METAL"),
    .define("WHISPER_USE_COREML"),
    .define("WHISPER_COREML_ALLOW_FALLBACK"),
]

let sharedCxxDefines: [CXXSetting] = [
    .define("GGML_USE_ACCELERATE"),
    .define("ACCELERATE_NEW_LAPACK"),
    .define("ACCELERATE_LAPACK_ILP64"),
    .define("GGML_USE_CPU"),
    .define("GGML_USE_METAL"),
    .define("WHISPER_USE_COREML"),
    .define("WHISPER_COREML_ALLOW_FALLBACK"),
]

let package = Package(
    name: "whisper.spm",
    platforms: [
        .macOS(.v12), .iOS(.v14),
    ],
    products: [
        .library(
            name: "whisper",
            targets: ["whisper"]),
    ],
    targets: [
        // ggml-metal.m uses manual retain/release. It must be compiled with -fno-objc-arc,
        // which is incompatible with the auto-generated CoreML .m files that #error out
        // without ARC. Isolate it in its own target.
        .target(
            name: "ggml-metal",
            path: "Sources/whisper/ggml-metal",
            // AC-41: ggml-metal.metal is NOT shipped as a runtime resource. SwiftPM
            // resource bundles for sub-targets aren't reachable from iOS apps that
            // consume the parent product, so we embed the shader source as a byte
            // array via ggml-metal-embed.c (mirrors upstream GGML_METAL_EMBED_LIBRARY).
            exclude: ["CMakeLists.txt", "ggml-metal.metal"],
            sources: ["ggml-metal.m", "ggml-metal-embed.c"],
            publicHeadersPath: ".",
            cSettings: sharedDefines + [
                .headerSearchPath("../"),
                .headerSearchPath("../include"),
                .define("GGML_METAL_EMBED_LIBRARY", to: "1"),
                .unsafeFlags(["-fno-objc-arc", "-Os"]),
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("MetalPerformanceShaders"),
            ]
        ),
        .target(
            name: "whisper",
            dependencies: ["ggml-metal"],
            path: "Sources/whisper",
            exclude: [
                "ggml-cpu/CMakeLists.txt",
                "ggml-cpu/cmake",
                "ggml-cpu/llamafile",
                "ggml-cpu/amx",
                "ggml-cpu/cpu-feats-x86.cpp",
                "ggml-metal",
            ],
            sources: [
                "whisper.cpp",
                "ggml.c",
                "ggml-alloc.c",
                "ggml-backend.cpp",
                "ggml-backend-reg.cpp",
                "ggml-opt.cpp",
                "ggml-threading.cpp",
                "ggml-quants.c",
                "ggml-cpu/ggml-cpu.c",
                "ggml-cpu/ggml-cpu.cpp",
                "ggml-cpu/ggml-cpu-aarch64.cpp",
                "ggml-cpu/ggml-cpu-hbm.cpp",
                "ggml-cpu/ggml-cpu-quants.c",
                "ggml-cpu/ggml-cpu-traits.cpp",
                "coreml/whisper-encoder.mm",
                "coreml/whisper-encoder-impl.m",
                "coreml/whisper-decoder-impl.m",
            ],
            publicHeadersPath: "include",
            cSettings: sharedDefines + [
                .headerSearchPath("."),
                .headerSearchPath("ggml-cpu"),
                .unsafeFlags(["-Os"]),
            ],
            cxxSettings: sharedCxxDefines + [
                .headerSearchPath("."),
                .headerSearchPath("ggml-cpu"),
                .unsafeFlags(["-Os"]),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("Foundation"),
                .linkedFramework("CoreML"),
            ]
        ),
    ],
    cxxLanguageStandard: CXXLanguageStandard.cxx17
)
