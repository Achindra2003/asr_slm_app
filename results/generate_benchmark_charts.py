"""
Generate multi-model comparison charts from benchmark results
Creates publication-ready visualizations comparing 5 LLM models
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import os

# Set publication-ready style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (14, 8)
plt.rcParams['font.size'] = 11
plt.rcParams['font.family'] = 'sans-serif'

# Model colors for consistent visualization
MODEL_COLORS = {
    'qwen3-0.6': '#3498db',      # Blue
    'smollm-1.7b': '#2ecc71',    # Green
    'gemma-2-2b': '#9b59b6',     # Purple
    'llama-3.2-3b': '#e74c3c',   # Red
    'phi-3.5-mini': '#f39c12',   # Orange
}

MODEL_LABELS = {
    'qwen3-0.6': 'Qwen 3 (0.6B)',
    'smollm-1.7b': 'SmolLM (1.7B)',
    'gemma-2-2b': 'Gemma 2 (2B)',
    'llama-3.2-3b': 'Llama 3.2 (3B)',
    'phi-3.5-mini': 'Phi 3.5 Mini (3.8B)',
}

print("="*80)
print("MULTI-MODEL BENCHMARK VISUALIZATION")
print("="*80)

# Load benchmark results
print("\nLoading benchmark results...")
try:
    df = pd.read_csv('results/benchmark_results.csv')
    print(f"✓ Loaded {len(df)} test results")
    print(f"  Models: {df['model'].nunique()}")
    print(f"  Commands: {df['command'].nunique()}")
except FileNotFoundError:
    print("❌ Error: benchmark_results.csv not found!")
    print("   Run the automated benchmark first from the app.")
    exit(1)

# Create output directory
os.makedirs('results/charts', exist_ok=True)

print("\nGenerating comparison charts...\n")

# Chart 1: Model Comparison - Success Rates
print("1. Model success rate comparison...")
fig, ax = plt.subplots(figsize=(12, 7))

model_stats = df.groupby('model').agg({
    'success': 'mean',
    'correct_function': 'mean',
    'correct_params': 'mean',
}).reset_index()

x = np.arange(len(model_stats))
width = 0.25

bars1 = ax.bar(x - width, model_stats['success'] * 100, width, 
              label='Overall Success', color='#2ecc71', edgecolor='black', linewidth=1.5)
bars2 = ax.bar(x, model_stats['correct_function'] * 100, width, 
              label='Correct Function', color='#3498db', edgecolor='black', linewidth=1.5)
bars3 = ax.bar(x + width, model_stats['correct_params'] * 100, width, 
              label='Correct Parameters', color='#9b59b6', edgecolor='black', linewidth=1.5)

# Add value labels
for bars in [bars1, bars2, bars3]:
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height + 1,
                f'{height:.1f}%', ha='center', va='bottom', fontsize=9, fontweight='bold')

ax.set_xlabel('Model', fontweight='bold', fontsize=13)
ax.set_ylabel('Success Rate (%)', fontweight='bold', fontsize=13)
ax.set_title('Model Comparison: Function Calling Accuracy\n(120 commands, Pure LLM evaluation)',
            fontsize=15, fontweight='bold', pad=20)
ax.set_xticks(x)
ax.set_xticklabels([MODEL_LABELS.get(m, m) for m in model_stats['model']], rotation=15, ha='right')
ax.legend(fontsize=11, loc='lower right')
ax.grid(axis='y', alpha=0.3)
ax.set_ylim(0, 105)

plt.tight_layout()
plt.savefig('results/charts/model_comparison.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/model_comparison.png")

# Chart 2: Latency Comparison
print("2. Latency comparison across models...")
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))

# Box plot
model_order = sorted(df['model'].unique())
bp = ax1.boxplot([df[df['model'] == m]['latency_ms'] for m in model_order],
                  labels=[MODEL_LABELS.get(m, m) for m in model_order],
                  patch_artist=True, showmeans=True)

for patch, model in zip(bp['boxes'], model_order):
    patch.set_facecolor(MODEL_COLORS.get(model, '#95a5a6'))
    patch.set_alpha(0.7)

ax1.set_xlabel('Model', fontweight='bold', fontsize=12)
ax1.set_ylabel('Latency (ms)', fontweight='bold', fontsize=12)
ax1.set_title('Latency Distribution by Model', fontsize=14, fontweight='bold')
ax1.grid(axis='y', alpha=0.3)
plt.setp(ax1.xaxis.get_majorticklabels(), rotation=15, ha='right')

# Average latency bar chart
avg_latency = df.groupby('model')['latency_ms'].mean().reset_index()
colors_ordered = [MODEL_COLORS.get(m, '#95a5a6') for m in avg_latency['model']]
bars = ax2.bar(range(len(avg_latency)), avg_latency['latency_ms'], 
              color=colors_ordered, edgecolor='black', linewidth=1.5)

for bar in bars:
    height = bar.get_height()
    ax2.text(bar.get_x() + bar.get_width()/2., height + 20,
            f'{height:.0f}ms', ha='center', va='bottom', fontsize=10, fontweight='bold')

ax2.set_xlabel('Model', fontweight='bold', fontsize=12)
ax2.set_ylabel('Average Latency (ms)', fontweight='bold', fontsize=12)
ax2.set_title('Average Inference Time', fontsize=14, fontweight='bold')
ax2.set_xticks(range(len(avg_latency)))
ax2.set_xticklabels([MODEL_LABELS.get(m, m) for m in avg_latency['model']], rotation=15, ha='right')
ax2.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('results/charts/latency_comparison.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/latency_comparison.png")

# Chart 3: Category-wise Performance Heatmap
print("3. Category performance heatmap...")
fig, ax = plt.subplots(figsize=(14, 8))

category_model = df.groupby(['category', 'model'])['success'].mean().unstack() * 100
category_model = category_model[[m for m in model_order if m in category_model.columns]]
category_model.columns = [MODEL_LABELS.get(m, m) for m in category_model.columns]

sns.heatmap(category_model, annot=True, fmt='.1f', cmap='RdYlGn', center=70,
           linewidths=1, linecolor='black', cbar_kws={'label': 'Success Rate (%)'}, 
           ax=ax, vmin=0, vmax=100)

ax.set_xlabel('Model', fontweight='bold', fontsize=13)
ax.set_ylabel('Command Category', fontweight='bold', fontsize=13)
ax.set_title('Success Rate by Category and Model\n(Higher values indicate better performance)',
            fontsize=15, fontweight='bold', pad=20)
ax.set_yticklabels(ax.get_yticklabels(), rotation=0)

plt.tight_layout()
plt.savefig('results/charts/category_heatmap.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/category_heatmap.png")

# Chart 4: Model Size vs Performance Trade-off
print("4. Model size vs performance analysis...")
fig, ax = plt.subplots(figsize=(10, 7))

model_sizes = {
    'qwen3-0.6': 0.6,
    'smollm-1.7b': 1.7,
    'gemma-2-2b': 2.0,
    'llama-3.2-3b': 3.0,
    'phi-3.5-mini': 3.8,
}

perf_data = df.groupby('model').agg({
    'success': 'mean',
    'latency_ms': 'mean'
}).reset_index()

perf_data['size'] = perf_data['model'].map(model_sizes)
perf_data['label'] = perf_data['model'].map(MODEL_LABELS)

scatter = ax.scatter(perf_data['size'], perf_data['success'] * 100, 
                    s=perf_data['latency_ms'], c=range(len(perf_data)),
                    cmap='viridis', alpha=0.6, edgecolors='black', linewidth=2)

for _, row in perf_data.iterrows():
    ax.annotate(row['label'], 
               (row['size'], row['success'] * 100),
               xytext=(10, 10), textcoords='offset points',
               fontsize=10, fontweight='bold',
               bbox=dict(boxstyle='round,pad=0.5', facecolor='white', alpha=0.7))

ax.set_xlabel('Model Size (Billions of Parameters)', fontweight='bold', fontsize=13)
ax.set_ylabel('Success Rate (%)', fontweight='bold', fontsize=13)
ax.set_title('Model Size vs Performance Trade-off\n(Bubble size represents average latency)',
            fontsize=15, fontweight='bold', pad=20)
ax.grid(True, alpha=0.3)
ax.set_ylim(0, 105)

# Add colorbar legend for latency
cbar = plt.colorbar(scatter, ax=ax, label='Model Rank')
cbar.set_label('Latency (bubble size)', fontsize=11, fontweight='bold')

plt.tight_layout()
plt.savefig('results/charts/size_vs_performance.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/size_vs_performance.png")

# Chart 5: Error Analysis
print("5. Error analysis by model...")
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))

# Error types
error_counts = df[df['success'] == False].groupby('model').size().reset_index(name='errors')
error_counts['label'] = error_counts['model'].map(MODEL_LABELS)
colors_err = [MODEL_COLORS.get(m, '#95a5a6') for m in error_counts['model']]

ax1.barh(range(len(error_counts)), error_counts['errors'], 
        color=colors_err, edgecolor='black', linewidth=1.5)
ax1.set_yticks(range(len(error_counts)))
ax1.set_yticklabels(error_counts['label'])
ax1.set_xlabel('Number of Failed Commands', fontweight='bold', fontsize=12)
ax1.set_title('Total Failures by Model', fontsize=14, fontweight='bold')
ax1.grid(axis='x', alpha=0.3)

for i, v in enumerate(error_counts['errors']):
    ax1.text(v + 1, i, str(v), va='center', fontweight='bold')

# Success rate by WER
wer_bins = [0, 0.1, 0.2, 0.3, 0.5, 1.0]
wer_labels = ['<0.1', '0.1-0.2', '0.2-0.3', '0.3-0.5', '≥0.5']
df['wer_bucket'] = pd.cut(df['word_error_rate'], bins=wer_bins, labels=wer_labels)

wer_model = df.groupby(['wer_bucket', 'model'])['success'].mean().unstack() * 100

for model in model_order:
    if model in wer_model.columns:
        ax2.plot(range(len(wer_labels)), wer_model[model], 
                marker='o', linewidth=2, markersize=8,
                label=MODEL_LABELS.get(model, model),
                color=MODEL_COLORS.get(model, '#95a5a6'))

ax2.set_xlabel('Word Error Rate Bucket', fontweight='bold', fontsize=12)
ax2.set_ylabel('Success Rate (%)', fontweight='bold', fontsize=12)
ax2.set_title('ASR Error Resilience by Model', fontsize=14, fontweight='bold')
ax2.set_xticks(range(len(wer_labels)))
ax2.set_xticklabels(wer_labels)
ax2.legend(fontsize=9, loc='lower left')
ax2.grid(True, alpha=0.3)
ax2.set_ylim(0, 105)

plt.tight_layout()
plt.savefig('results/graphs/error_analysis.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/graphs/error_analysis.png")

# Chart 6: Comprehensive Multi-Model Dashboard
# Chart 6: Comprehensive Multi-Model Dashboard
print("6. Comprehensive dashboard...")
fig = plt.figure(figsize=(18, 12))
gs = fig.add_gridspec(3, 3, hspace=0.35, wspace=0.35)

# Top row: Summary statistics
ax1 = fig.add_subplot(gs[0, :])
ax1.axis('off')

# Create summary text
summary_text = f"""
BENCHMARK SUMMARY (120 Commands × 5 Models = 600 Tests)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Best Accuracy: {model_stats.loc[model_stats['success'].idxmax(), 'model']} ({model_stats['success'].max()*100:.1f}%)
Fastest Model: {avg_latency.loc[avg_latency['latency_ms'].idxmin(), 'model']} ({avg_latency['latency_ms'].min():.0f}ms)
Overall Success Rate: {df['success'].mean()*100:.1f}%
Average Latency: {df['latency_ms'].mean():.0f}ms
"""

ax1.text(0.5, 0.5, summary_text, ha='center', va='center', 
         fontsize=12, fontweight='bold', family='monospace',
         bbox=dict(boxstyle='round,pad=1', facecolor='lightgray', alpha=0.3))

# Middle left: Success rates
ax2 = fig.add_subplot(gs[1, :2])
x_pos = np.arange(len(model_stats))
bars = ax2.bar(x_pos, model_stats['success'] * 100,
              color=[MODEL_COLORS.get(m, '#95a5a6') for m in model_stats['model']],
              edgecolor='black', linewidth=1.5)
for bar in bars:
    height = bar.get_height()
    ax2.text(bar.get_x() + bar.get_width()/2., height + 1,
            f'{height:.1f}%', ha='center', va='bottom', fontsize=10, fontweight='bold')
ax2.set_xticks(x_pos)
ax2.set_xticklabels([MODEL_LABELS.get(m, m) for m in model_stats['model']], 
                     rotation=15, ha='right', fontsize=10)
ax2.set_ylabel('Success Rate (%)', fontweight='bold')
ax2.set_title('Overall Success Rate by Model', fontweight='bold', fontsize=12)
ax2.grid(axis='y', alpha=0.3)
ax2.set_ylim(0, 105)

# Middle right: Latency
ax3 = fig.add_subplot(gs[1, 2])
avg_lat = df.groupby('model')['latency_ms'].mean().sort_values()
colors_lat = [MODEL_COLORS.get(m, '#95a5a6') for m in avg_lat.index]
bars_lat = ax3.barh(range(len(avg_lat)), avg_lat.values, color=colors_lat, 
                    edgecolor='black', linewidth=1.5)
for i, bar in enumerate(bars_lat):
    width = bar.get_width()
    ax3.text(width + 20, bar.get_y() + bar.get_height()/2., 
            f'{width:.0f}ms', va='center', fontsize=9, fontweight='bold')
ax3.set_yticks(range(len(avg_lat)))
ax3.set_yticklabels([MODEL_LABELS.get(m, m)[:15] for m in avg_lat.index], fontsize=9)
ax3.set_xlabel('Avg Latency (ms)', fontweight='bold', fontsize=10)
ax3.set_title('Inference Speed', fontweight='bold', fontsize=12)
ax3.grid(axis='x', alpha=0.3)

# Bottom: Category mini-heatmap
ax4 = fig.add_subplot(gs[2, :])
category_mini = df.groupby(['category', 'model'])['success'].mean().unstack() * 100
category_mini = category_mini[[m for m in model_order if m in category_mini.columns]]
sns.heatmap(category_mini, 
           annot=True, fmt='.0f', cmap='RdYlGn', center=70,
           linewidths=0.5, cbar_kws={'label': 'Success %'}, ax=ax4, vmin=0, vmax=100)
ax4.set_xlabel('Model', fontweight='bold', fontsize=11)
ax4.set_ylabel('Category', fontweight='bold', fontsize=11)
ax4.set_title('Category Performance Matrix', fontweight='bold', fontsize=12)
ax4.set_xticklabels([MODEL_LABELS.get(m, m)[:12] for m in category_mini.columns], 
                     rotation=15, ha='right', fontsize=9)
ax4.set_yticklabels(ax4.get_yticklabels(), rotation=0, fontsize=9)

fig.suptitle('Multi-Model Benchmark Dashboard\nPure LLM Evaluation',
            fontsize=18, fontweight='bold', y=0.98)

plt.savefig('results/charts/multi_model_dashboard.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/multi_model_dashboard.png")

print("\n" + "="*80)
print("✅ ALL MULTI-MODEL CHARTS GENERATED SUCCESSFULLY")
print("="*80)
print("\nGenerated 6 publication-ready visualizations:")
print("  1. model_comparison.png - Success rate comparison")
print("  2. latency_comparison.png - Inference time analysis")
print("  3. category_heatmap.png - Category-wise performance")
print("  4. size_vs_performance.png - Trade-off analysis")
print("  5. error_analysis.png - Failure patterns & ASR resilience")
print("  6. multi_model_dashboard.png - Comprehensive overview")
print("\nAll charts are 300 DPI, publication-ready!")
print("Ready for research paper inclusion.")
