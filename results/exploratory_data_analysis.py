"""
Exploratory Data Analysis (EDA) for Voice-to-Rule Agent Dataset
================================================================
Statistical analysis, visualizations, and insights for research paper

Dataset: 120 realistic voice commands with ASR errors
Models: 5 LLMs (Qwen, SmolLM, Gemma, Llama, Phi)
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from scipy.stats import chi2_contingency, pearsonr, spearmanr
import json

# Set style
sns.set_style("whitegrid")
plt.rcParams['figure.dpi'] = 300
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['font.size'] = 10

# ============================================================================
# LOAD DATA
# ============================================================================

print("Loading datasets...")
# Load realistic dataset
with open('realistic_dataset.json', 'r') as f:
    dataset = json.load(f)
dataset_df = pd.DataFrame(dataset)

# Load benchmark results
benchmark_df = pd.read_csv('benchmark_results.csv')

print(f"Dataset: {len(dataset_df)} commands")
print(f"Benchmark: {len(benchmark_df)} test results")
print()

# ============================================================================
# 1. DESCRIPTIVE STATISTICS
# ============================================================================

print("="*80)
print("1. DESCRIPTIVE STATISTICS")
print("="*80)

# Dataset characteristics
print("\nDataset Composition:")
print(f"  Total commands: {len(dataset_df)}")
print(f"  Unique participants: {dataset_df['participant_id'].nunique()}")
print(f"  Commands per participant: {len(dataset_df) / dataset_df['participant_id'].nunique():.1f}")
print()

# Category distribution
print("Category Distribution:")
category_counts = dataset_df['category'].value_counts()
for cat, count in category_counts.items():
    pct = (count / len(dataset_df)) * 100
    print(f"  {cat:15s}: {count:3d} ({pct:5.1f}%)")
print()

# Tool/Function distribution
print("Expected Function Distribution:")
function_counts = dataset_df['expected_function'].value_counts()
for func, count in function_counts.items():
    pct = (count / len(dataset_df)) * 100
    print(f"  {func:20s}: {count:3d} ({pct:5.1f}%)")
print()

# Word Error Rate statistics
print("Word Error Rate (WER) Statistics:")
wer_stats = dataset_df['word_error_rate'].describe()
print(f"  Mean:   {wer_stats['mean']:.3f}")
print(f"  Median: {wer_stats['50%']:.3f}")
print(f"  Std:    {wer_stats['std']:.3f}")
print(f"  Min:    {wer_stats['min']:.3f}")
print(f"  Max:    {wer_stats['max']:.3f}")
print(f"  Q1:     {wer_stats['25%']:.3f}")
print(f"  Q3:     {wer_stats['75%']:.3f}")
print()

# Benchmark results by model
print("Model Performance Summary:")
for model in benchmark_df['model'].unique():
    model_data = benchmark_df[benchmark_df['model'] == model]
    success_rate = (model_data['success'].sum() / len(model_data)) * 100
    avg_latency = model_data['latency_ms'].mean()
    func_acc = (model_data['correct_function'].sum() / len(model_data)) * 100
    param_acc = (model_data['correct_params'].sum() / len(model_data)) * 100
    
    print(f"  {model:15s}: {success_rate:5.1f}% success, {avg_latency:6.1f}ms latency")
    print(f"                   {func_acc:5.1f}% func acc, {param_acc:5.1f}% param acc")
print()

# ============================================================================
# 2. INFERENTIAL STATISTICS
# ============================================================================

print("="*80)
print("2. INFERENTIAL STATISTICS")
print("="*80)

# Chi-square test: Category vs Success
print("\nChi-Square Test: Category Independence")
contingency_table = pd.crosstab(
    benchmark_df['category'], 
    benchmark_df['success']
)
chi2, p_value, dof, expected = chi2_contingency(contingency_table)
print(f"  Chi-square statistic: {chi2:.4f}")
print(f"  P-value: {p_value:.4e}")
print(f"  Degrees of freedom: {dof}")
if p_value < 0.05:
    print("  Result: Category significantly affects success rate (p < 0.05)")
else:
    print("  Result: No significant category effect (p >= 0.05)")
print()

# ANOVA: Model performance differences
print("One-Way ANOVA: Model Performance Differences")
model_groups = [benchmark_df[benchmark_df['model'] == model]['success'].astype(int).values 
                for model in benchmark_df['model'].unique()]
f_stat, p_value_anova = stats.f_oneway(*model_groups)
print(f"  F-statistic: {f_stat:.4f}")
print(f"  P-value: {p_value_anova:.4e}")
if p_value_anova < 0.05:
    print("  Result: Significant differences between models (p < 0.05)")
else:
    print("  Result: No significant model differences (p >= 0.05)")
print()

# Correlation: WER vs Success
print("Correlation Analysis: WER Impact on Success")
wer_success_corr, wer_p = spearmanr(
    benchmark_df['word_error_rate'], 
    benchmark_df['success'].astype(int)
)
print(f"  Spearman correlation: {wer_success_corr:.4f}")
print(f"  P-value: {wer_p:.4e}")
if wer_p < 0.05:
    print(f"  Result: Significant {'negative' if wer_success_corr < 0 else 'positive'} correlation (p < 0.05)")
else:
    print("  Result: No significant correlation (p >= 0.05)")
print()

# Correlation: Model size vs Accuracy
print("Correlation Analysis: Model Size vs Accuracy")
model_sizes = {
    'qwen3-0.6': 0.6,
    'smollm-1.7b': 1.7,
    'gemma-2-2b': 2.0,
    'llama-3.2-3b': 3.0,
    'phi-3.5-mini': 3.8
}
model_accuracies = benchmark_df.groupby('model')['success'].mean()
sizes = [model_sizes[m] for m in model_accuracies.index]
accuracies = model_accuracies.values
size_acc_corr, size_p = pearsonr(sizes, accuracies)
print(f"  Pearson correlation: {size_acc_corr:.4f}")
print(f"  P-value: {size_p:.4e}")
if size_p < 0.05:
    print(f"  Result: Significant {'positive' if size_acc_corr > 0 else 'negative'} correlation (p < 0.05)")
else:
    print("  Result: No significant correlation (p >= 0.05)")
print()

# T-test: Complex vs Simple categories
print("Independent T-Test: Complex vs Simple Categories")
complex_categories = ['temporal', 'contextual', 'rule']
simple_categories = ['direct', 'parameter']
complex_success = benchmark_df[benchmark_df['category'].isin(complex_categories)]['success'].astype(int)
simple_success = benchmark_df[benchmark_df['category'].isin(simple_categories)]['success'].astype(int)
t_stat, t_p = stats.ttest_ind(complex_success, simple_success)
print(f"  Complex mean: {complex_success.mean():.3f}")
print(f"  Simple mean: {simple_success.mean():.3f}")
print(f"  T-statistic: {t_stat:.4f}")
print(f"  P-value: {t_p:.4e}")
if t_p < 0.05:
    print("  Result: Significant difference between complexity levels (p < 0.05)")
else:
    print("  Result: No significant difference (p >= 0.05)")
print()

# ============================================================================
# 3. ADDITIONAL VISUALIZATIONS FOR EDA
# ============================================================================

print("="*80)
print("3. GENERATING ADDITIONAL EDA VISUALIZATIONS")
print("="*80)

# Create output directory
import os
os.makedirs('charts', exist_ok=True)

# Visualization 1: Distribution plots
fig, axes = plt.subplots(2, 2, figsize=(14, 10))

# WER distribution
axes[0, 0].hist(dataset_df['word_error_rate'], bins=20, edgecolor='black', alpha=0.7, color='steelblue')
axes[0, 0].axvline(dataset_df['word_error_rate'].mean(), color='red', linestyle='--', linewidth=2, label=f'Mean: {dataset_df["word_error_rate"].mean():.3f}')
axes[0, 0].set_xlabel('Word Error Rate (WER)')
axes[0, 0].set_ylabel('Frequency')
axes[0, 0].set_title('Distribution of ASR Error Rates')
axes[0, 0].legend()
axes[0, 0].grid(True, alpha=0.3)

# Latency distribution by model
benchmark_df.boxplot(column='latency_ms', by='model', ax=axes[0, 1])
axes[0, 1].set_xlabel('Model')
axes[0, 1].set_ylabel('Latency (ms)')
axes[0, 1].set_title('Latency Distribution by Model')
axes[0, 1].get_figure().suptitle('')

# Success rate by category
category_success = benchmark_df.groupby('category')['success'].mean().sort_values(ascending=True)
axes[1, 0].barh(category_success.index, category_success.values * 100, color='forestgreen', alpha=0.7)
axes[1, 0].set_xlabel('Success Rate (%)')
axes[1, 0].set_ylabel('Category')
axes[1, 0].set_title('Success Rate by Command Category')
axes[1, 0].grid(True, alpha=0.3, axis='x')

# Model size vs performance scatter
model_perf = benchmark_df.groupby('model').agg({
    'success': 'mean',
    'latency_ms': 'mean'
}).reset_index()
model_perf['size'] = model_perf['model'].map(model_sizes)
scatter = axes[1, 1].scatter(model_perf['size'], model_perf['success'] * 100, 
                             s=model_perf['latency_ms'], alpha=0.6, c=model_perf['latency_ms'], 
                             cmap='coolwarm', edgecolors='black')
for idx, row in model_perf.iterrows():
    axes[1, 1].annotate(row['model'], (row['size'], row['success'] * 100), 
                        fontsize=8, ha='center', va='bottom')
axes[1, 1].set_xlabel('Model Size (Billions of Parameters)')
axes[1, 1].set_ylabel('Success Rate (%)')
axes[1, 1].set_title('Model Size vs Performance (bubble size = latency)')
axes[1, 1].grid(True, alpha=0.3)
plt.colorbar(scatter, ax=axes[1, 1], label='Avg Latency (ms)')

plt.tight_layout()
plt.savefig('charts/eda_distributions.png', bbox_inches='tight')
print("✓ Saved: charts/eda_distributions.png")

# Visualization 2: Correlation matrix
fig, ax = plt.subplots(figsize=(10, 8))
correlation_data = benchmark_df[['word_error_rate', 'latency_ms', 'success', 
                                  'correct_function', 'correct_params']].astype(float)
correlation_matrix = correlation_data.corr()
sns.heatmap(correlation_matrix, annot=True, fmt='.3f', cmap='coolwarm', center=0,
            square=True, linewidths=1, cbar_kws={"shrink": 0.8}, ax=ax)
ax.set_title('Correlation Matrix: Performance Metrics', fontsize=14, fontweight='bold')
plt.tight_layout()
plt.savefig('charts/eda_correlation_matrix.png', bbox_inches='tight')
print("✓ Saved: charts/eda_correlation_matrix.png")

# Visualization 3: Error analysis by category
fig, ax = plt.subplots(figsize=(12, 6))
error_analysis = benchmark_df[benchmark_df['success'] == False].groupby(['category', 'model']).size().unstack(fill_value=0)
error_analysis.plot(kind='bar', ax=ax, width=0.8)
ax.set_xlabel('Category')
ax.set_ylabel('Number of Failures')
ax.set_title('Failure Distribution: Category × Model', fontsize=14, fontweight='bold')
ax.legend(title='Model', bbox_to_anchor=(1.05, 1), loc='upper left')
ax.grid(True, alpha=0.3, axis='y')
plt.xticks(rotation=45, ha='right')
plt.tight_layout()
plt.savefig('charts/eda_error_by_category.png', bbox_inches='tight')
print("✓ Saved: charts/eda_error_by_category.png")

# Visualization 4: Function vs Parameter accuracy
fig, ax = plt.subplots(figsize=(10, 8))
model_accuracy = benchmark_df.groupby('model').agg({
    'correct_function': 'mean',
    'correct_params': 'mean'
}).reset_index()
x = np.arange(len(model_accuracy))
width = 0.35
ax.bar(x - width/2, model_accuracy['correct_function'] * 100, width, 
       label='Function Accuracy', color='skyblue', edgecolor='black')
ax.bar(x + width/2, model_accuracy['correct_params'] * 100, width,
       label='Parameter Accuracy', color='lightcoral', edgecolor='black')
ax.set_xlabel('Model')
ax.set_ylabel('Accuracy (%)')
ax.set_title('Function vs Parameter Extraction Accuracy', fontsize=14, fontweight='bold')
ax.set_xticks(x)
ax.set_xticklabels(model_accuracy['model'], rotation=45, ha='right')
ax.legend()
ax.grid(True, alpha=0.3, axis='y')
plt.tight_layout()
plt.savefig('charts/eda_function_vs_parameter.png', bbox_inches='tight')
print("✓ Saved: charts/eda_function_vs_parameter.png")

print("\n" + "="*80)
print("EDA COMPLETE - All statistics and visualizations generated!")
print("="*80)
print("\nGenerated files:")
print("  • charts/eda_distributions.png")
print("  • charts/eda_correlation_matrix.png")
print("  • charts/eda_error_by_category.png")
print("  • charts/eda_function_vs_parameter.png")
print("\nUse these for your paper's Results section!")
