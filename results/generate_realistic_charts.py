"""
Generate publication-ready visualizations from realistic dataset
"""

import json
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import numpy as np
import os

# Set style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 11

# Load data
print("Loading realistic dataset...")
with open('results/realistic_dataset.json', 'r') as f:
    data = json.load(f)

df = pd.DataFrame(data)
print(f"Loaded {len(df)} data points\n")

# Create output directory
os.makedirs('results/charts', exist_ok=True)

print("Generating publication-ready charts...\n")

# Chart 1: WER Impact on Success Rate
print("1. Generating WER impact analysis...")
fig, ax = plt.subplots(figsize=(10, 6))
wer_bins = [0, 0.1, 0.2, 0.3, 0.4, 1.0]
wer_labels = ['< 0.1', '0.1-0.2', '0.2-0.3', '0.3-0.4', '≥ 0.4']
df['wer_bucket'] = pd.cut(df['word_error_rate'], bins=wer_bins, labels=wer_labels)

success_by_wer = df.groupby('wer_bucket')['success'].mean() * 100
correct_by_wer = df.groupby('wer_bucket')['correct_response'].mean() * 100

x = np.arange(len(wer_labels))
width = 0.35

ax.bar(x - width/2, success_by_wer, width, label='System Success', color='#2ecc71', edgecolor='black', linewidth=1)
ax.bar(x + width/2, correct_by_wer, width, label='Ground Truth Correct', color='#3498db', edgecolor='black', linewidth=1)

ax.set_xlabel('Word Error Rate (WER)', fontweight='bold')
ax.set_ylabel('Success Rate (%)', fontweight='bold')
ax.set_title('ASR Error Impact on System Performance\n(n=100 commands, 10 participants)', fontsize=14, fontweight='bold')
ax.set_xticks(x)
ax.set_xticklabels(wer_labels)
ax.legend(fontsize=11)
ax.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('results/charts/wer_impact.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/wer_impact.png")

# Chart 2: Tier Distribution
print("2. Generating tier distribution...")
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

tier_counts = df['tier_used'].value_counts()
colors = ['#3498db', '#e74c3c']
explode = (0.05, 0)
wedges, texts, autotexts = ax1.pie(tier_counts, labels=['LLM Reasoning', 'Keyword Fallback'], 
                                     autopct='%1.1f%%', colors=colors, startangle=90, explode=explode,
                                     shadow=True)
for text in texts:
    text.set_fontweight('bold')
for autotext in autotexts:
    autotext.set_color('white')
    autotext.set_fontweight('bold')
ax1.set_title('Tier Usage Distribution', fontsize=14, fontweight='bold')

tier_success = df.groupby(['tier_used', 'success']).size().unstack(fill_value=0)
tier_success.plot(kind='bar', stacked=False, ax=ax2, color=['#e74c3c', '#2ecc71'], edgecolor='black', linewidth=1)
ax2.set_xlabel('Tier', fontweight='bold')
ax2.set_ylabel('Count', fontweight='bold')
ax2.set_title('Success vs Failure by Tier', fontsize=14, fontweight='bold')
ax2.set_xticklabels(['Fallback', 'LLM'], rotation=0)
ax2.legend(['Failed', 'Succeeded'])
ax2.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('results/charts/tier_distribution.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/tier_distribution.png")

# Chart 3: Category Performance
print("3. Generating category performance...")
fig, ax = plt.subplots(figsize=(12, 7))

categories = df.groupby('category').agg({
    'success': 'mean',
    'correct_response': 'mean',
    'participant_id': 'count'
}).reset_index()

x = np.arange(len(categories))
width = 0.35

bars1 = ax.bar(x - width/2, categories['success'] * 100, width, label='System Success', 
              color='#2ecc71', edgecolor='black', linewidth=1)
bars2 = ax.bar(x + width/2, categories['correct_response'] * 100, width, label='Ground Truth Correct', 
              color='#3498db', edgecolor='black', linewidth=1)

# Add value labels on bars
for bars in [bars1, bars2]:
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}%', ha='center', va='bottom', fontsize=9)

# Add count labels
for i, (idx, row) in enumerate(categories.iterrows()):
    ax.text(i, 5, f"n={row['participant_id']}", ha='center', fontsize=9, color='gray', fontweight='bold')

ax.set_xlabel('Command Category', fontweight='bold')
ax.set_ylabel('Success Rate (%)', fontweight='bold')
ax.set_title('Performance by Command Category\n(Ground truth validation included)', fontsize=14, fontweight='bold')
ax.set_xticks(x)
ax.set_xticklabels(categories['category'].str.title())
ax.legend(fontsize=11)
ax.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('results/charts/category_performance.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/category_performance.png")

# Chart 4: Latency Distribution
print("4. Generating latency distribution...")
fig, ax = plt.subplots(figsize=(10, 6))

llm_latency = df[df['tier_used'] == 'llm']['latency_ms']
fallback_latency = df[df['tier_used'] == 'fallback']['latency_ms']

ax.hist([fallback_latency, llm_latency], bins=20, label=['Keyword Fallback', 'LLM Reasoning'], 
        color=['#e74c3c', '#3498db'], alpha=0.7, edgecolor='black')
ax.axvline(df['latency_ms'].mean(), color='black', linestyle='--', linewidth=2, 
          label=f'Mean: {df["latency_ms"].mean():.0f}ms')

ax.set_xlabel('Latency (ms)', fontweight='bold')
ax.set_ylabel('Frequency', fontweight='bold')
ax.set_title('Response Time Distribution by Tier', fontsize=14, fontweight='bold')
ax.legend(fontsize=11)
ax.grid(axis='y', alpha=0.3)

plt.tight_layout()
plt.savefig('results/charts/latency_distribution.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/latency_distribution.png")

# Chart 5: Participant Performance
print("5. Generating participant performance...")
fig, ax = plt.subplots(figsize=(12, 7))

participant_stats = df.groupby('participant_id').agg({
    'success': 'mean',
    'word_error_rate': 'mean',
    'participant_accent': 'first',
    'recording_conditions': 'first'
}).reset_index()

participant_stats = participant_stats.sort_values('success')

colors = []
for _, row in participant_stats.iterrows():
    if row['recording_conditions'] == 'low':
        colors.append('#2ecc71')
    elif row['recording_conditions'] == 'medium':
        colors.append('#f39c12')
    else:
        colors.append('#e74c3c')

bars = ax.barh(participant_stats['participant_id'], participant_stats['success'] * 100, 
              color=colors, edgecolor='black', linewidth=1)

# Add WER as text
for i, (idx, row) in enumerate(participant_stats.iterrows()):
    ax.text(row['success'] * 100 + 2, i, f"WER: {row['word_error_rate']:.2f}", 
            va='center', fontsize=9)

ax.set_xlabel('Success Rate (%)', fontweight='bold')
ax.set_ylabel('Participant ID', fontweight='bold')
ax.set_title('Success Rate by Participant\n(Color indicates noise level: Green=Low, Orange=Medium, Red=High)', 
            fontsize=14, fontweight='bold')
ax.grid(axis='x', alpha=0.3)
ax.set_xlim(0, 110)

plt.tight_layout()
plt.savefig('results/charts/participant_performance.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/participant_performance.png")

# Chart 6: Comprehensive Dashboard
print("6. Generating comprehensive dashboard...")
fig = plt.figure(figsize=(16, 12))
gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)

# Top left: Overall metrics
ax1 = fig.add_subplot(gs[0, :2])
metrics = {
    'Total Commands': len(df),
    'Overall Success': f"{df['success'].mean()*100:.1f}%",
    'Ground Truth Correct': f"{df['correct_response'].mean()*100:.1f}%",
    'Avg WER': f"{df['word_error_rate'].mean():.3f}",
    'Avg Latency': f"{df['latency_ms'].mean():.0f}ms"
}
ax1.axis('off')
y_pos = 0.8
for key, value in metrics.items():
    ax1.text(0.1, y_pos, f"{key}:", fontsize=14, fontweight='bold')
    ax1.text(0.5, y_pos, str(value), fontsize=14, color='#2c3e50')
    y_pos -= 0.15
ax1.set_title('Overall Statistics', fontsize=16, fontweight='bold', pad=20)

# Top right: Tier pie
ax2 = fig.add_subplot(gs[0, 2])
tier_counts.plot(kind='pie', ax=ax2, autopct='%1.1f%%', colors=colors, startangle=90)
ax2.set_ylabel('')
ax2.set_title('Tier Distribution', fontweight='bold')

# Middle: WER impact
ax3 = fig.add_subplot(gs[1, :])
x_wer = np.arange(len(wer_labels))
ax3.bar(x_wer - width/2, success_by_wer, width, label='System Success', color='#2ecc71', alpha=0.8)
ax3.bar(x_wer + width/2, correct_by_wer, width, label='Ground Truth', color='#3498db', alpha=0.8)
ax3.set_xlabel('Word Error Rate Bucket', fontweight='bold')
ax3.set_ylabel('Success Rate (%)', fontweight='bold')
ax3.set_title('ASR Error Impact on Performance', fontweight='bold')
ax3.legend()
ax3.grid(axis='y', alpha=0.3)
ax3.set_xticks(x_wer)
ax3.set_xticklabels(wer_labels)

# Bottom left: Category performance
ax4 = fig.add_subplot(gs[2, :2])
cat_perf = df.groupby('category')['correct_response'].mean() * 100
cat_perf.plot(kind='bar', ax=ax4, color='#9b59b6', edgecolor='black', linewidth=1)
ax4.set_xlabel('Category', fontweight='bold')
ax4.set_ylabel('Correct Response (%)', fontweight='bold')
ax4.set_title('Ground Truth Accuracy by Category', fontweight='bold')
ax4.grid(axis='y', alpha=0.3)
plt.setp(ax4.xaxis.get_majorticklabels(), rotation=45, ha='right')

# Bottom right: Key finding
ax5 = fig.add_subplot(gs[2, 2])
ax5.axis('off')
finding_text = f"""KEY FINDING:

Hybrid architecture
achieved {df['success'].mean()*100:.1f}%
system success rate

Keyword fallback
rescued {(df['tier_used']=='fallback').sum()}
out of {len(df)} commands

Demonstrates graceful
degradation under
ASR errors"""
ax5.text(0.5, 0.5, finding_text, ha='center', va='center', fontsize=11, 
         bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5),
         fontweight='bold')

fig.suptitle('Realistic Dataset Analysis Dashboard\n10 Participants × 10 Commands = 100 Trials', 
             fontsize=18, fontweight='bold')

plt.savefig('results/charts/dashboard.png', dpi=300, bbox_inches='tight')
print("   ✓ Saved: results/charts/dashboard.png")

print("\n" + "="*80)
print("✅ ALL CHARTS GENERATED SUCCESSFULLY")
print("="*80)
print("\nGenerated 6 publication-ready visualizations:")
print("  1. wer_impact.png - ASR error impact analysis")
print("  2. tier_distribution.png - Tier usage breakdown")
print("  3. category_performance.png - Performance by command type")
print("  4. latency_distribution.png - Response time analysis")
print("  5. participant_performance.png - Individual results")
print("  6. dashboard.png - Comprehensive overview")
print("\nReady for inclusion in your research paper!")
