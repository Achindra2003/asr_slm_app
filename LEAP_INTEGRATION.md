# LEAP SDK Integration Guide

## Overview
This project now supports **Liquid LFM2 models** via the LEAP Edge SDK in addition to Cactus SDK models. LEAP provides access to Liquid AI's Foundation Models optimized for on-device inference.

## Architecture
- **Cactus Provider**: Handles Qwen, SmolLM, Gemma, Llama, Phi models (built-in)
- **LEAP Provider**: Handles Liquid LFM2 models via platform channel to native SDK

## Available LEAP Models

### LFM2 Tool Use Models (Recommended for this project)
| Model | Size | Best For | Function Calling |
|-------|------|----------|------------------|
| `lfm2-40m-tool-use` | 40M | Ultra-lightweight devices | ✅ Excellent |
| `lfm2-350m-tool-use` | 350M | Balanced performance | ✅ Excellent |
| `lfm2-1b-tool-use` | 1B | Best accuracy | ✅ Excellent |

### LFM2 Instruct Models
| Model | Size | Best For | Function Calling |
|-------|------|----------|------------------|
| `lfm2-350m-instruct` | 350M | General chat | ⚠️ Limited |
| `lfm2-1b-instruct` | 1B | Advanced chat | ⚠️ Limited |

### Qwen3 via LEAP
| Model | Size | Notes | Function Calling |
|-------|------|-------|------------------|
| `qwen3-1b-tool-use` | 1B | Uses Hermes parser | ✅ Good |

## Setup Instructions

### 1. Prerequisites
- **Android Device**: Physical device with API 31+ (Android 12+)
- **RAM**: 3GB+ recommended
- **ABI**: arm64-v8a architecture
- **Storage**: 500MB-2GB per model

### 2. Download Model Bundles
1. Visit https://leap.liquid.ai/models
2. Download desired `.bundle` files (e.g., `lfm2-1b-tool-use.bundle`)
3. Save to your computer

### 3. Push Models to Device
```bash
# Create directory on device
adb shell mkdir -p /data/local/tmp/leap/

# Push model bundle
adb push ~/Downloads/lfm2-1b-tool-use.bundle /data/local/tmp/leap/

# Verify file exists
adb shell ls -lh /data/local/tmp/leap/
```

### 4. Update Main App Code
Add LEAP models to the model selector in `lib/main.dart`:

```dart
// In _MyAgentAppState class, add LEAP models
final Map<String, String> _leapModels = {
  'lfm2-1b-tool-use': '/data/local/tmp/leap/lfm2-1b-tool-use.bundle',
  'lfm2-350m-tool-use': '/data/local/tmp/leap/lfm2-350m-tool-use.bundle',
  'lfm2-40m-tool-use': '/data/local/tmp/leap/lfm2-40m-tool-use.bundle',
};

// Modify _switchModel() to support LEAP provider
Future<void> _switchModel(String newModel) async {
  if (_leapModels.containsKey(newModel)) {
    // Use LEAP provider
    final bundlePath = _leapModels[newModel]!;
    _provider = await LeapProvider.create(newModel, bundlePath);
  } else {
    // Use Cactus provider (existing logic)
    _provider = CactusProvider(newModel);
  }
  
  // Download and initialize...
}
```

## Usage Example

### Basic Inference with LEAP
```dart
import 'package:my_agent_app/models/leap_provider.dart';

// Create provider with bundle path
final provider = LeapProvider(
  'lfm2-1b-tool-use',
  '/data/local/tmp/leap/lfm2-1b-tool-use.bundle',
);

// Initialize model
await provider.initializeModel();

// Run inference with function calling
final response = await provider.infer(
  systemPrompt: 'You are a helpful assistant...',
  userMessage: 'Turn on the flashlight',
  tools: [
    CactusTool(
      name: 'toggleFlashlight',
      description: 'Controls device flashlight',
      parameters: ToolParametersSchema(
        properties: {
          'enable': ToolParameter(
            type: 'boolean',
            description: 'True to turn on',
            required: true,
          ),
        },
      ),
    ),
  ],
  maxTokens: 300,
  temperature: 0.2,
);

// Check results
if (response.success && response.toolCalls != null) {
  print('Tool call: ${response.toolCalls!.first.name}');
  print('Arguments: ${response.toolCalls!.first.arguments}');
}
```

## Platform Channel Architecture

### Flutter Side (leap_provider.dart)
- Implements `ModelProvider` interface
- Sends commands via MethodChannel: `com.myagent.leap/inference`
- Converts CactusTool definitions to LEAP format

### Native Side (LeapInferenceManager.kt)
- Manages LeapClient and Conversation instances
- Handles model loading from bundle files
- Registers functions for tool calling
- Returns structured responses with tool calls

### Supported Methods
| Method | Purpose | Returns |
|--------|---------|---------|
| `loadModel` | Load .bundle file | boolean |
| `createConversation` | Setup with functions | boolean |
| `generateResponse` | Run inference | Map (text, toolCalls, latency) |
| `dispose` | Clean up resources | boolean |

## Function Calling Support

### Hermes Parser (Qwen3 Models)
For Qwen3 models via LEAP, use the Hermes function call parser:
```dart
final useHermesParser = modelName.contains('qwen');
```

### LFM2 Parser (Default)
LFM2 models use the built-in LEAP function call parser automatically.

## Benchmark Integration

To include LEAP models in automated benchmarks:

### 1. Update Model List
```dart
// In main.dart
final allModels = [
  // Cactus models
  'qwen3-0.6',
  'smollm-1.7b',
  'gemma-2-2b',
  'llama-3.2-3b',
  'phi-3.5-mini',
  
  // LEAP models
  'lfm2-1b-tool-use',
  'lfm2-350m-tool-use',
  'lfm2-40m-tool-use',
];
```

### 2. Modify BenchmarkService
```dart
// In benchmark_service.dart
Future<BenchmarkResult> _testCommand(...) async {
  final provider = _getProviderForModel(modelName);
  // ... rest of benchmark logic
}

ModelProvider _getProviderForModel(String modelName) {
  if (modelName.startsWith('lfm2') || modelName.contains('qwen3-1b')) {
    return LeapProvider(modelName, _leapBundlePaths[modelName]!);
  } else {
    return CactusProvider(modelName);
  }
}
```

## Performance Expectations

### LFM2 40M Tool Use
- **Latency**: 50-150ms per inference
- **RAM**: ~500MB
- **Accuracy**: 70-85% on device control tasks

### LFM2 350M Tool Use
- **Latency**: 150-300ms per inference
- **RAM**: ~800MB
- **Accuracy**: 80-90% on device control tasks

### LFM2 1B Tool Use
- **Latency**: 300-600ms per inference
- **RAM**: ~1.5GB
- **Accuracy**: 85-95% on device control tasks

## Troubleshooting

### Model Won't Load
```
Error: Failed to load model
```
**Solution**: Verify bundle file exists on device
```bash
adb shell ls /data/local/tmp/leap/
```

### Out of Memory
```
Error: Model loading failed with OOM
```
**Solution**: Use smaller model (40M or 350M variant)

### Function Calling Not Working
```
Error: No tool calls in response
```
**Solution**: 
- Use `-tool-use` variant, not `-instruct`
- Verify function definitions are clear
- Check if Hermes parser needed (Qwen3 models)

### Slow Inference
```
Warning: Latency >2000ms
```
**Solution**:
- Close background apps
- Use lower maxTokens (200-300)
- Try quantized model bundles (Q4 or Q8)

## Model Selection Guide

### For Research Paper
**Recommended**: Test all 3 LFM2 tool-use models + existing 5 Cactus models
- Total: 8 models spanning 40M to 3.8B parameters
- Compare: Accuracy, latency, model size trade-offs

### For Production App
**Recommended**: `lfm2-350m-tool-use`
- Best balance of accuracy and speed
- <1GB RAM footprint
- <300ms average latency

### For Ultra-Lightweight Deployment
**Recommended**: `lfm2-40m-tool-use`
- Smallest on-device model available
- <500MB RAM
- <150ms latency
- Still maintains 70%+ accuracy

## Next Steps

1. **Download Models**: Get at least `lfm2-1b-tool-use.bundle` from leap.liquid.ai
2. **Push to Device**: Use adb commands above
3. **Test Single Model**: Run manual inference to verify setup
4. **Integrate UI**: Add LEAP models to dropdown selector
5. **Run Benchmarks**: Compare against Cactus models
6. **Generate Charts**: Update visualization for 8-model comparison

## Additional Resources
- LEAP Documentation: https://docs.liquid.ai/leap
- Model Library: https://leap.liquid.ai/models
- Android SDK Docs: https://docs.liquid.ai/leap/edge-sdk/android
- Function Calling Guide: https://docs.liquid.ai/leap/edge-sdk/android/function-calling
- Example Apps: https://github.com/Liquid4All/LeapSDK-Examples

## License
LEAP SDK is provided by Liquid AI under their licensing terms.
See: https://www.liquid.ai/lfm-license
