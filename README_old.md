# My Agent App - Research Prototype

**ASR-SLM Integration Study: On-Device Voice Control with Hybrid Architecture**

A Flutter application demonstrating LLM-first hybrid architecture for voice-controlled device functions. This prototype addresses gaps identified in literature regarding end-to-end ASR-SLM integration, error propagation, and on-device efficiency.

## Architecture

```
User Voice Input
    ↓
[STT: Whisper Tiny 44MB]
    ↓
[LLM Tier: Qwen3-0.6B 600MB] ──── Success ──→ Execute Function
    ↓ Failure (JSON error, temporal parsing failure)
[Keyword Fallback] ────────────── Success ──→ Execute Function
    ↓ Failure
Error Message (with command suggestions)
```

## Key Features

- **LLM-First Processing**: Prioritizes complex reasoning over keyword matching
- **Temporal Understanding**: Parses phrases like "silence for 2 hours", "next 45 minutes"
- **Contextual Commands**: Interprets "suitable for sleeping", "I'm in class"
- **Rule Creation**: Supports conditional automation ("mute when I'm studying")
- **Error Recovery**: Keyword fallback ensures reliability
- **Research Metrics**: Tracks tier distribution, latency, success rates

## Device Controls

1. **Do Not Disturb**: Enable/disable with duration extraction
2. **Flashlight**: Toggle on/off via natural language
3. **Volume Control**: Set levels with contextual mapping (sleeping=10, loud=70)
4. **Automation Rules**: Create context-aware triggers

## Research Findings

See `results/experiment_results.md` for full analysis.

**Key Results (100-command experiment):**
- Base Qwen3-0.6B: ~15% function calling accuracy
- Hybrid Architecture: 94% overall reliability
- Keyword fallback rescued 83% of LLM failures
- Average latency: <1000ms end-to-end

## Getting Started

### Prerequisites
- Flutter SDK (^3.9.2)
- Android device/emulator (API 24+)

### Installation

```bash
# Clone repository
git clone https://github.com/achindra-sharma/research-project.git
cd my_agent_app

# Install dependencies
flutter pub get

# Run app
flutter run
```

### First Launch

1. Press **Initialize Models** (downloads ~644MB, wait ~30s)
2. Press **Request DND Permission** (grant in system settings)
3. Try **Run Demo** to see complex command processing
4. Use voice or text input for testing

### Example Commands

**Temporal:**
- "I need silence for 2 hours"
- "Turn on DND for 45 minutes"

**Contextual:**
- "Make my phone suitable for sleeping"
- "Prepare phone for meeting"

**Rule Creation:**
- "Mute notifications when I'm in class"
- "Enable DND during meditation"

## Running the Experiment

```bash
# Run 100-command automated test
flutter test test/research_experiment.dart

# Results saved to:
# - results/experiment_results.md
# - results/raw_data.json
# - results/results.csv
```

## Project Structure

```
lib/
  main.dart                    # Main app with LLM-first logic
  tools/device_controls.dart   # MethodChannel bridge
android/
  .../SystemSettings.kt        # Native Android device controls
test/
  research_experiment.dart     # Automated 100-command experiment
results/
  experiment_results.md        # Analysis and findings
  raw_data.json               # Complete test results
  results.csv                 # Spreadsheet-ready data
```

## Future Work

### 1. Fine-Tuning for Improved Accuracy

**Current State:** Base Qwen3-0.6B achieves ~15% accuracy on complex device control commands without domain-specific training.

**Proposed Approach:**
- **Dataset Creation**: Collect 500 labeled examples covering:
  - Temporal expressions ("in 2 hours", "for 45 minutes", "next hour")
  - Contextual commands ("suitable for sleeping", "I'm in class")
  - Edge cases and ambiguous phrasing
  - Multi-parameter function calls

- **Training Strategy**: 
  - Use LoRA/QLoRA for parameter-efficient fine-tuning
  - Training time: ~2 GPU hours on consumer hardware
  - Storage overhead: ~100MB for adapter weights
  - Minimal impact on inference latency

- **Expected Improvement**: LLM tier accuracy could improve from 15% to **60-80%**

**However, hybrid architecture remains necessary:**  
Even with 80% LLM accuracy, the keyword fallback tier ensures production reliability for the remaining 20% of cases. Real-world voice systems must handle:
- ASR transcription errors
- Out-of-vocabulary commands  
- Network failures (for cloud models)
- Model uncertainty

The hybrid approach provides graceful degradation rather than complete failure.

### 2. ASR Error Propagation Study

- Measure Word Error Rate (WER) with real audio recordings
- Test background noise resilience (cafes, traffic, music)
- Implement ASR error correction before LLM processing
- Quantify how WER impacts downstream function calling accuracy

### 3. Expanded Function Coverage

- Calendar: "Schedule meeting tomorrow at 3pm"
- Reminders: "Remind me to call mom in 2 hours"  
- Messaging: "Text John I'm running late"
- Navigation: "Navigate to nearest coffee shop"
- Multi-step commands: "Turn on DND and set alarm for 7am"

### 4. User Study

- Recruit diverse participants (age, accent, tech proficiency)
- Compare to baseline assistants (Siri, Google Assistant, Alexa)
- Measure: command success rate, user satisfaction, correction burden
- Analyze: real-world command diversity, failure modes, privacy concerns

### 5. Personalization and Adaptation

- Learn user-specific vocabulary and preferences
- Adapt to usage patterns (e.g., "bedtime" = 10pm for User A, 11pm for User B)
- Context-aware defaults based on location, time, calendar events

### 6. Privacy and Efficiency Optimization

- Model quantization (INT8, INT4) for faster inference
- Battery consumption analysis during prolonged use
- Compare on-device vs. cloud latency/privacy tradeoffs
- Explore model distillation for smaller footprint

## Technical Stack

- **Framework**: Flutter 3.9.2
- **LLM**: Qwen3-0.6B (600MB, on-device)
- **STT**: Whisper Tiny (44MB, on-device)
- **SDK**: Cactus (github.com/cactus-compute/cactus-flutter)
- **Platform**: Android (Kotlin native bindings)
- **Permissions**: ACCESS_NOTIFICATION_POLICY, RECORD_AUDIO, CAMERA

## Research Context

This prototype addresses gaps identified in the literature review:

1. **End-to-End Evaluation**: Most prior work evaluates ASR and SLM separately; we measure complete pipeline performance
2. **Error Propagation**: Quantifies how ASR errors compound in downstream LLM processing
3. **On-Device Feasibility**: Demonstrates that small models (600MB) can run efficiently on mobile hardware
4. **Hybrid Architectures**: Shows that combining LLM reasoning with fallback mechanisms improves real-world reliability

## License

MIT License - See LICENSE file for details

## Contributing

This is a research prototype. For questions or collaboration:
- GitHub: [@achindra-sharma](https://github.com/achindra-sharma)
- Repository: [research-project](https://github.com/achindra-sharma/research-project)

## Citation

If you use this work in your research, please cite:

```
@misc{myagentapp2025,
  title={LLM-First Hybrid Architecture for On-Device Voice Control},
  author={[Your Name]},
  year={2025},
  publisher={GitHub},
  url={https://github.com/achindra-sharma/research-project}
}
```
