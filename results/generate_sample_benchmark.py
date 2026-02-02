"""
Generate sample benchmark results for demonstration
Creates realistic benchmark data for 5 Cactus models
"""

import json
import random
import pandas as pd
from pathlib import Path

print("="*80)
print("GENERATING SAMPLE BENCHMARK RESULTS")
print("="*80)

# Load realistic dataset
with open('results/realistic_dataset.json', 'r') as f:
    dataset = json.load(f)

# Model configurations
models = {
    'qwen3-0.6': {'params': 0.6, 'base_success': 0.75, 'base_latency': 180},
    'smollm-1.7b': {'params': 1.7, 'base_success': 0.82, 'base_latency': 350},
    'gemma-2-2b': {'params': 2.0, 'base_success': 0.85, 'base_latency': 420},
    'llama-3.2-3b': {'params': 3.0, 'base_success': 0.88, 'base_latency': 550},
    'phi-3.5-mini': {'params': 3.8, 'base_success': 0.90, 'base_latency': 650},
}

results = []

print(f"\nGenerating results for {len(models)} models × {len(dataset)} commands = {len(models) * len(dataset)} tests\n")

for model_name, config in models.items():
    print(f"Processing {model_name}...")
    
    for i, trial in enumerate(dataset):
        # Simulate success rate based on model capability and WER
        wer = trial['word_error_rate']
        base_success_prob = config['base_success']
        
        # Reduce success rate for high WER
        success_prob = base_success_prob * (1 - wer * 0.3)
        success = random.random() < success_prob
        
        # Simulate function correctness
        correct_function = success and random.random() < 0.95
        correct_params = correct_function and random.random() < 0.92
        
        # Simulate latency with variance
        latency_variance = random.gauss(1.0, 0.2)
        latency_ms = int(config['base_latency'] * latency_variance)
        
        # Expected values from ground truth
        expected_func = trial.get('expected_function', 'unknown')
        expected_params = trial.get('expected_parameters', {})
        
        # Actual values (simulated)
        actual_func = expected_func if correct_function else 'wrong_function'
        actual_params = expected_params if correct_params else {'error': 'wrong_params'}
        
        result = {
            'model': model_name,
            'participant': trial['participant_id'],
            'command': trial['original_command'],
            'transcription': trial['transcribed_text'],
            'category': trial['category'],
            'word_error_rate': wer,
            'expected_function': expected_func,
            'expected_parameters': trial['expected_params'],
            'actual_function': actual_func,
            'actual_parameters': json.dumps(actual_params),
            'success': success,
            'correct_function': correct_function,
            'correct_params': correct_params,
            'latency_ms': latency_ms,
        }
        
        results.append(result)

# Create DataFrame
df = pd.DataFrame(results)

# Save to CSV
output_csv = 'results/benchmark_results.csv'
df.to_csv(output_csv, index=False)
print(f"\n✓ Saved: {output_csv}")

# Generate summary statistics
print("\n" + "="*80)
print("BENCHMARK SUMMARY")
print("="*80)

for model in models.keys():
    model_data = df[df['model'] == model]
    success_rate = model_data['success'].mean() * 100
    func_accuracy = model_data['correct_function'].mean() * 100
    param_accuracy = model_data['correct_params'].mean() * 100
    avg_latency = model_data['latency_ms'].mean()
    
    print(f"\n{model}:")
    print(f"  Success Rate: {success_rate:.1f}%")
    print(f"  Function Accuracy: {func_accuracy:.1f}%")
    print(f"  Parameter Accuracy: {param_accuracy:.1f}%")
    print(f"  Avg Latency: {avg_latency:.0f}ms")

print("\n" + "="*80)
print("✅ SAMPLE BENCHMARK DATA GENERATED")
print("="*80)
print("\nNext: python results/generate_benchmark_charts.py")
