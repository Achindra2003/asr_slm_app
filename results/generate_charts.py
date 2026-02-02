"""
Chart Generation Script for Research Experiment Results
Generates distribution graphs, success rate comparisons, and latency analysis
Run after: flutter test test/research_experiment.dart
"""

import json
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

# Configure matplotlib for better-looking charts
plt.style.use('seaborn-v0_8-darkgrid')
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 11

def load_results():
    """Load raw experiment results from JSON file"""
    with open('results/raw_data.json', 'r') as f:
        return json.load(f)

def generate_tier_distribution_chart(results):
    """Generate pie chart showing LLM vs Fallback tier usage"""
    tiers = [r['tier'] for r in results]
    tier_counts = {
        'LLM': tiers.count('llm'),
        'Fallback': tiers.count('fallback')
    }
    
    colors = ['#2ecc71', '#e67e22']
    explode = (0.05, 0)
    
    fig, ax = plt.subplots()
    wedges, texts, autotexts = ax.pie(
        tier_counts.values(),
        labels=tier_counts.keys(),
        autopct='%1.1f%%',
        colors=colors,
        explode=explode,
        shadow=True,
        startangle=90
    )
    
    # Enhance text
    for text in texts:
        text.set_fontsize(14)
        text.set_weight('bold')
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontsize(12)
        autotext.set_weight('bold')
    
    ax.set_title('Tier Distribution: LLM-First Architecture', fontsize=16, weight='bold', pad=20)
    plt.tight_layout()
    plt.savefig('results/charts/tier_distribution.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Generated tier_distribution.png')

def generate_success_rate_comparison(results):
    """Generate bar chart comparing success rates by tier"""
    llm_results = [r for r in results if r['tier'] == 'llm']
    fallback_results = [r for r in results if r['tier'] == 'fallback']
    
    llm_success = sum(1 for r in llm_results if r['success']) / len(llm_results) * 100
    fallback_success = sum(1 for r in fallback_results if r['success']) / len(fallback_results) * 100
    overall_success = sum(1 for r in results if r['success']) / len(results) * 100
    
    tiers = ['LLM Tier', 'Fallback Tier', 'Overall\n(Hybrid)']
    success_rates = [llm_success, fallback_success, overall_success]
    colors_list = ['#3498db', '#e67e22', '#2ecc71']
    
    fig, ax = plt.subplots()
    bars = ax.bar(tiers, success_rates, color=colors_list, edgecolor='black', linewidth=1.5)
    
    # Add value labels on bars
    for bar, rate in zip(bars, success_rates):
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{rate:.1f}%',
                ha='center', va='bottom', fontsize=12, weight='bold')
    
    ax.set_ylabel('Success Rate (%)', fontsize=13, weight='bold')
    ax.set_title('Success Rate Comparison by Tier', fontsize=16, weight='bold', pad=20)
    ax.set_ylim(0, 110)
    ax.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('results/charts/success_rate_comparison.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Generated success_rate_comparison.png')

def generate_category_performance(results):
    """Generate bar chart showing success rate by command category"""
    categories = {}
    for r in results:
        cat = r['category']
        if cat not in categories:
            categories[cat] = {'total': 0, 'success': 0}
        categories[cat]['total'] += 1
        if r['success']:
            categories[cat]['success'] += 1
    
    cat_names = list(categories.keys())
    success_rates = [categories[cat]['success'] / categories[cat]['total'] * 100 
                     for cat in cat_names]
    
    # Sort by success rate
    sorted_pairs = sorted(zip(cat_names, success_rates), key=lambda x: x[1], reverse=True)
    cat_names, success_rates = zip(*sorted_pairs)
    
    colors_gradient = plt.cm.viridis(np.linspace(0.3, 0.9, len(cat_names)))
    
    fig, ax = plt.subplots(figsize=(12, 6))
    bars = ax.barh(cat_names, success_rates, color=colors_gradient, edgecolor='black', linewidth=1)
    
    # Add value labels
    for bar, rate in zip(bars, success_rates):
        width = bar.get_width()
        ax.text(width + 1, bar.get_y() + bar.get_height()/2.,
                f'{rate:.1f}%',
                ha='left', va='center', fontsize=11, weight='bold')
    
    ax.set_xlabel('Success Rate (%)', fontsize=13, weight='bold')
    ax.set_title('Performance by Command Category', fontsize=16, weight='bold', pad=20)
    ax.set_xlim(0, 110)
    ax.grid(axis='x', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('results/charts/category_performance.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Generated category_performance.png')

def generate_latency_distribution(results):
    """Generate histogram showing latency distribution"""
    latencies = [r['latency_ms'] for r in results]
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    n, bins, patches = ax.hist(latencies, bins=30, color='#3498db', 
                                edgecolor='black', linewidth=1, alpha=0.7)
    
    # Color bars by latency (gradient)
    cm = plt.cm.RdYlGn_r
    bin_centers = 0.5 * (bins[:-1] + bins[1:])
    col = bin_centers - min(bin_centers)
    col /= max(col)
    for c, p in zip(col, patches):
        plt.setp(p, 'facecolor', cm(c))
    
    # Add mean line
    mean_latency = np.mean(latencies)
    ax.axvline(mean_latency, color='red', linestyle='--', linewidth=2, 
               label=f'Mean: {mean_latency:.0f}ms')
    
    # Add median line
    median_latency = np.median(latencies)
    ax.axvline(median_latency, color='orange', linestyle='--', linewidth=2,
               label=f'Median: {median_latency:.0f}ms')
    
    ax.set_xlabel('Latency (ms)', fontsize=13, weight='bold')
    ax.set_ylabel('Frequency', fontsize=13, weight='bold')
    ax.set_title('End-to-End Latency Distribution', fontsize=16, weight='bold', pad=20)
    ax.legend(fontsize=12)
    ax.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('results/charts/latency_distribution.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Generated latency_distribution.png')

def generate_latency_by_tier(results):
    """Generate box plot comparing latency by tier"""
    llm_latencies = [r['latency_ms'] for r in results if r['tier'] == 'llm']
    fallback_latencies = [r['latency_ms'] for r in results if r['tier'] == 'fallback']
    
    fig, ax = plt.subplots()
    
    bp = ax.boxplot([llm_latencies, fallback_latencies], 
                     labels=['LLM Tier', 'Fallback Tier'],
                     patch_artist=True,
                     showmeans=True,
                     meanprops=dict(marker='D', markerfacecolor='red', markersize=8))
    
    # Color boxes
    colors = ['#3498db', '#e67e22']
    for patch, color in zip(bp['boxes'], colors):
        patch.set_facecolor(color)
        patch.set_alpha(0.7)
    
    ax.set_ylabel('Latency (ms)', fontsize=13, weight='bold')
    ax.set_title('Latency Comparison by Tier', fontsize=16, weight='bold', pad=20)
    ax.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('results/charts/latency_by_tier.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Generated latency_by_tier.png')

def generate_summary_dashboard(results):
    """Generate comprehensive dashboard with multiple metrics"""
    fig = plt.figure(figsize=(16, 10))
    gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
    
    # 1. Overall metrics text
    ax1 = fig.add_subplot(gs[0, :])
    ax1.axis('off')
    
    total = len(results)
    successes = sum(1 for r in results if r['success'])
    llm_count = sum(1 for r in results if r['tier'] == 'llm')
    fallback_count = sum(1 for r in results if r['tier'] == 'fallback')
    avg_latency = np.mean([r['latency_ms'] for r in results])
    
    metrics_text = f"""
    EXPERIMENT SUMMARY
    
    Total Commands: {total}  |  Success Rate: {successes/total*100:.1f}%  |  Avg Latency: {avg_latency:.0f}ms
    
    LLM Tier: {llm_count} ({llm_count/total*100:.1f}%)  |  Fallback Tier: {fallback_count} ({fallback_count/total*100:.1f}%)
    """
    
    ax1.text(0.5, 0.5, metrics_text, ha='center', va='center', 
             fontsize=14, weight='bold', family='monospace',
             bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.8))
    
    # 2. Tier distribution pie chart
    ax2 = fig.add_subplot(gs[1, 0])
    tiers = [r['tier'] for r in results]
    tier_counts = {'LLM': tiers.count('llm'), 'Fallback': tiers.count('fallback')}
    ax2.pie(tier_counts.values(), labels=tier_counts.keys(), autopct='%1.1f%%',
            colors=['#2ecc71', '#e67e22'], startangle=90)
    ax2.set_title('Tier Distribution', weight='bold')
    
    # 3. Success rates bar chart
    ax3 = fig.add_subplot(gs[1, 1])
    llm_results = [r for r in results if r['tier'] == 'llm']
    fallback_results = [r for r in results if r['tier'] == 'fallback']
    llm_success = sum(1 for r in llm_results if r['success']) / len(llm_results) * 100
    fallback_success = sum(1 for r in fallback_results if r['success']) / len(fallback_results) * 100
    ax3.bar(['LLM', 'Fallback'], [llm_success, fallback_success], 
            color=['#3498db', '#e67e22'])
    ax3.set_ylabel('Success Rate (%)')
    ax3.set_title('Success by Tier', weight='bold')
    ax3.set_ylim(0, 110)
    
    # 4. Category performance
    ax4 = fig.add_subplot(gs[1, 2])
    categories = {}
    for r in results:
        cat = r['category']
        if cat not in categories:
            categories[cat] = {'total': 0, 'success': 0}
        categories[cat]['total'] += 1
        if r['success']:
            categories[cat]['success'] += 1
    cat_names = list(categories.keys())
    success_rates = [categories[cat]['success'] / categories[cat]['total'] * 100 
                     for cat in cat_names]
    ax4.barh(cat_names, success_rates, color=plt.cm.viridis(np.linspace(0.3, 0.9, len(cat_names))))
    ax4.set_xlabel('Success Rate (%)')
    ax4.set_title('Category Performance', weight='bold')
    
    # 5. Latency histogram
    ax5 = fig.add_subplot(gs[2, :2])
    latencies = [r['latency_ms'] for r in results]
    ax5.hist(latencies, bins=30, color='#3498db', edgecolor='black', alpha=0.7)
    ax5.axvline(np.mean(latencies), color='red', linestyle='--', 
                label=f'Mean: {np.mean(latencies):.0f}ms')
    ax5.set_xlabel('Latency (ms)')
    ax5.set_ylabel('Frequency')
    ax5.set_title('Latency Distribution', weight='bold')
    ax5.legend()
    
    # 6. Latency by tier box plot
    ax6 = fig.add_subplot(gs[2, 2])
    llm_lat = [r['latency_ms'] for r in results if r['tier'] == 'llm']
    fallback_lat = [r['latency_ms'] for r in results if r['tier'] == 'fallback']
    bp = ax6.boxplot([llm_lat, fallback_lat], labels=['LLM', 'Fallback'], patch_artist=True)
    for patch, color in zip(bp['boxes'], ['#3498db', '#e67e22']):
        patch.set_facecolor(color)
        patch.set_alpha(0.7)
    ax6.set_ylabel('Latency (ms)')
    ax6.set_title('Latency by Tier', weight='bold')
    
    fig.suptitle('ASR-SLM Integration Study: Comprehensive Dashboard', 
                 fontsize=18, weight='bold')
    
    plt.savefig('results/charts/dashboard.png', dpi=300, bbox_inches='tight')
    plt.close()
    print('✓ Generated dashboard.png')

def main():
    print('Loading experiment results...')
    results = load_results()
    print(f'Loaded {len(results)} test results\n')
    
    print('Generating charts...')
    generate_tier_distribution_chart(results)
    generate_success_rate_comparison(results)
    generate_category_performance(results)
    generate_latency_distribution(results)
    generate_latency_by_tier(results)
    generate_summary_dashboard(results)
    
    print('\n✅ All charts generated successfully!')
    print('📁 Location: results/charts/')
    print('📊 Charts:')
    print('   - tier_distribution.png')
    print('   - success_rate_comparison.png')
    print('   - category_performance.png')
    print('   - latency_distribution.png')
    print('   - latency_by_tier.png')
    print('   - dashboard.png')

if __name__ == '__main__':
    main()
