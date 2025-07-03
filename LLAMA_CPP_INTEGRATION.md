# llama.cpp Integration Guide for MCPiPhone

## Overview

This guide explains how to complete the llama.cpp integration for local LLM support in MCPiPhone.

## Current Status

✅ **Completed:**
- Swift package structure for LlamaCppSwift
- Objective-C bridge header (LlamaCppBridge)
- Swift wrapper implementation
- LocalLLMProvider updated with integration points
- Model management system ready

⏳ **Pending:**
- Actual llama.cpp source code integration
- Build configuration for iOS
- Metal shader compilation
- Testing and optimization

## Integration Steps

### 1. Add llama.cpp Source Code

1. Clone llama.cpp repository:
```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
```

2. Copy required source files to the project:
```bash
# Copy core files
cp ggml*.c ggml*.h /path/to/MCPiPhone/MCPiPhone/LLM/LlamaCpp/Sources/LlamaCppBridge/
cp llama.cpp llama.h /path/to/MCPiPhone/MCPiPhone/LLM/LlamaCpp/Sources/LlamaCppBridge/
cp common/common.cpp common/common.h /path/to/MCPiPhone/MCPiPhone/LLM/LlamaCpp/Sources/LlamaCppBridge/
```

3. Copy Metal shaders:
```bash
cp ggml-metal.metal /path/to/MCPiPhone/MCPiPhone/LLM/LlamaCpp/Sources/LlamaCppBridge/
```

### 2. Update Build Configuration

Add to `Package.swift` target settings:
```swift
.target(
    name: "LlamaCppBridge",
    dependencies: [],
    path: "Sources/LlamaCppBridge",
    exclude: ["README.md"],
    sources: [
        "LlamaCppBridge.mm",
        "llama.cpp",
        "ggml.c",
        "ggml-alloc.c",
        "ggml-backend.c",
        "ggml-quants.c",
        "ggml-metal.m",
        "common.cpp"
    ],
    resources: [
        .process("ggml-metal.metal")
    ],
    publicHeadersPath: "include",
    cSettings: [
        .headerSearchPath("include"),
        .define("GGML_USE_METAL", to: "1"),
        .define("GGML_USE_ACCELERATE", to: "1"),
        .define("GGML_METAL_NDEBUG", to: "1"),
        .unsafeFlags(["-O3", "-DNDEBUG", "-ffast-math"])
    ]
)
```

### 3. Implement LlamaCppBridge.mm

Replace the placeholder implementation with actual llama.cpp calls:

```objc
#import "LlamaCppBridge.h"
#include "llama.h"
#include "common.h"
#include "ggml.h"

@implementation LLMContext

- (nullable instancetype)initWithModelPath:(NSString *)path
                               contextSize:(NSInteger)contextSize
                                  nThreads:(NSInteger)nThreads {
    self = [super init];
    if (self) {
        // Initialize backend
        llama_backend_init();
        
        // Load model
        auto lparams = llama_model_default_params();
        lparams.n_gpu_layers = 999; // Use GPU for all layers
        
        _model = llama_load_model_from_file(path.UTF8String, lparams);
        if (!_model) {
            return nil;
        }
        
        // Create context
        auto cparams = llama_context_default_params();
        cparams.n_ctx = (int)contextSize;
        cparams.n_threads = (int)nThreads;
        cparams.n_threads_batch = (int)nThreads;
        
        _ctx = llama_new_context_with_model(_model, cparams);
        if (!_ctx) {
            llama_free_model(_model);
            return nil;
        }
    }
    return self;
}

// ... implement other methods ...

@end
```

### 4. Update Info.plist

Add Metal usage description:
```xml
<key>NSMetalUsageDescription</key>
<string>Metal is used to accelerate local AI model inference</string>
```

### 5. Testing

Create a test to verify the integration:

```swift
import XCTest
import LlamaCppSwift

class LlamaCppTests: XCTestCase {
    func testModelLoading() async throws {
        let modelPath = Bundle.main.path(forResource: "jan-nano-1", ofType: "gguf")!
        let config = LlamaCpp.Configuration(modelPath: modelPath)
        
        let llamaCpp = try LlamaCpp(configuration: config)
        let result = try await llamaCpp.generate(
            prompt: "Hello, world!",
            params: .init(maxTokens: 50)
        )
        
        XCTAssertFalse(result.isEmpty)
    }
}
```

## Performance Optimization

1. **Metal Performance Shaders**: Already configured in build settings
2. **Quantization**: Use Q4_K_M or Q5_K_M models for best size/performance balance
3. **Context Size**: Default to 2048 tokens, allow user configuration
4. **Batch Processing**: Enable for better throughput

## Memory Management

1. Model files are memory-mapped for efficiency
2. Context is cleared between conversations to save memory
3. Implement memory pressure handling:

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleMemoryWarning),
    name: UIApplication.didReceiveMemoryWarningNotification,
    object: nil
)
```

## Error Handling

Handle common errors gracefully:
- Model file not found
- Insufficient memory
- Metal not available (fallback to CPU)
- Context overflow

## Next Steps

1. Complete llama.cpp source integration
2. Test with various GGUF models
3. Benchmark performance on different iOS devices
4. Implement model download progress UI
5. Add support for conversation context
6. Implement token streaming for better UX

## Resources

- [llama.cpp repository](https://github.com/ggerganov/llama.cpp)
- [GGUF format specification](https://github.com/ggerganov/ggml/blob/master/docs/gguf.md)
- [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
- [iOS Memory Management](https://developer.apple.com/documentation/uikit/app_and_environment/managing_your_app_s_memory)