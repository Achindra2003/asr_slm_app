# On-Device Voice Agent Research Platform

**Status:** Production-Ready  
**Models:** 12 SLMs (0.6B - 3.8B parameters)  
**Backend:** Cactus SDK (llama.cpp + Whisper)  
**Target:** MediaTek Dimensity 7050  

## Models Integrated
- 🤖 **Generalists:** Qwen 3 (0.6B, 1.7B), Gemma 3 (2B), SmolLM (1.7B), Llama 3.2 (3B), Phi 3.5 Mini (3.8B)
- 🎯 **Specialists:** Function-Gemma (270M, 270M-pro)
- ⏱️ **Temporal:** Liquid LFM-2 (350M, 700M, 1.2B, 1.2B-tool)

## Architecture
```
Voice → Whisper-Tiny (10s, 39M) → Text
Text → Adaptive Prompt (specialist/liquid/generalist) → SLM
SLM → Function Call JSON → Android APIs
```

## Quick Start

```bash
flutter run --release

# In app:
1. Select model (e.g., "Function-Gemma Pro")
2. Initialize Models (wait ~30s)
3. Request DND Permission
4. Test: "I need silence for 2 hours"
5. Run Full Benchmark (120 cmds × 12 models)
```

## Research Features
- ✅ 120-command benchmark suite
- ✅ 12-model comparison
- ✅ Adaptive 3-tier prompting
- ✅ Real-time metrics tracking
- ✅ CSV/JSON export

## Project Structure
```
lib/
├─ main.dart (1,529 lines - UI + LLM logic)
├─ services/
│  └─ benchmark_service.dart (460 lines - automated testing)
└─ tools/
   └─ device_controls.dart (213 lines - Android APIs)
```

## License
MIT - See LICENSE file
