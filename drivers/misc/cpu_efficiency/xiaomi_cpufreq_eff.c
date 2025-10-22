// SPDX-License-Identifier: GPL-2.0-only
#include <linux/xiaomi_cpufreq_eff.h>

/* affect_mode, @1: enable, @0: disable. */
static int affect_mode = 1;
module_param(affect_mode, int, 0664);

/*
 * Silver cluster, param@0: affect_freq1, param@1: affect_thres1,
 * param@2: affect_freq2, param@3: affect_thres2, param@4 need mask freq.
 */
static int cluster0_efficiency[MAX_CLUSTER_PARAMETERS] = { 902400, 120000,
	1401600, 180000, 1708800
};

module_param_array(cluster0_efficiency, int, NULL, 0664);

/*
 * Gold cluster, param@0: affect_freq1, param@1: affect_thres1,
 * param@2: affect_freq2, param@3: affect_thres2, param@4 need mask freq.
 */
static int cluster1_efficiency[MAX_CLUSTER_PARAMETERS] = { 844800, 140000,
	1324800, 220000, 1881600
};

module_param_array(cluster1_efficiency, int, NULL, 0664);

/*
 * Gold_plus cluster, param@0: affect_freq1, param@1: affect_thres1,
 * param@2: affect_freq2, param@3: affect_thres2, param@4 need mask freq.
 */
static int cluster2_efficiency[MAX_CLUSTER_PARAMETERS] = { 960000, 180000,
	1555200, 260000, 1900800
};

module_param_array(cluster2_efficiency, int, NULL, 0664);

/* Unified access to cluster efficiency tables */
static int *const cluster_efficiency_table[MAX_CLUSTER] = {
	cluster0_efficiency,
	cluster1_efficiency,
	cluster2_efficiency
};

/* Power Domain for SM8350 */
static const unsigned int sm8350_cluster_pd[MAX_CLUSTER] = { 16, 16, 19 };

static const unsigned int sm8350_pd_sliver[16] = { 0, 0, 0, 0, 0, 1, 1, 2,
	2, 2, 3, 3, 3, 4, 5, 5
};

static const unsigned int sm8350_pd_golden[16] = { 0, 1, 1, 2, 2, 3, 3, 4,
	4, 4, 5, 6, 6, 7, 7, 8
};

static const unsigned int sm8350_pd_goplus[19] = { 0, 1, 1, 1, 2, 2, 3, 3, 4, 4,
	4, 5, 6, 7, 7, 7, 7, 8, 8
};

static unsigned int platform_soc_id;
static unsigned int opp_number[MAX_CLUSTER];

/* Helper: get power domain table by cluster ID */
static const unsigned int *get_cluster_pd(int cluster_id)
{
	if (platform_soc_id != SM8350_SOC_ID)
		return NULL;

	switch (cluster_id) {
	case SLIVER_CLUSTER:
		return sm8350_pd_sliver;
	case GOLDEN_CLUSTER:
		return sm8350_pd_golden;
	case GOPLUS_CLUSTER:
		return sm8350_pd_goplus;
	default:
		return NULL;
	}
}

/* Get cluster number from policy */
static int get_cluster_num(struct cpufreq_policy *policy)
{
	int first_cpu, cluster_num;
	struct device *cpu_dev;

	if (!policy)
		return -1;

	first_cpu = cpumask_first(policy->related_cpus);
	cpu_dev = get_cpu_device(first_cpu);
	if (!cpu_dev) {
		pr_err("failed to get cpu device\n");
		return -1;
	}

	cluster_num = topology_physical_package_id(cpu_dev->id);
	if (cluster_num < 0 || cluster_num >= MAX_CLUSTER) {
		pr_err("invalid cluster id: %d\n", cluster_num);
		return -1;
	}

	if (platform_soc_id == SM8350_SOC_ID) {
		if (opp_number[cluster_num] != sm8350_cluster_pd[cluster_num])
			return -1;
	}

	return cluster_num;
}

/* Check if frequency transition crosses power domain boundary */
static bool was_diff_powerdomain(struct cpufreq_policy *policy,
				 unsigned int freq)
{
	int index, index_pre, cluster_id;
	const unsigned int *pd_table;
	unsigned int pd_size;

	if (!policy || !policy->freq_table)
		return false;

	index =
	    cpufreq_frequency_table_target(policy, freq, CPUFREQ_RELATION_L);
	index_pre =
	    cpufreq_frequency_table_target(policy, freq - 1,
					   CPUFREQ_RELATION_H);

	if (index < 0 || index_pre < 0 || index == index_pre)
		return false;

	cluster_id = get_cluster_num(policy);
	if (cluster_id < 0)
		return false;

	pd_table = get_cluster_pd(cluster_id);
	if (!pd_table)
		return false;

	pd_size = sm8350_cluster_pd[cluster_id];
	if ((unsigned int)index >= pd_size
	    || (unsigned int)index_pre >= pd_size)
		return false;

	return (pd_table[index] != pd_table[index_pre]);
}

/* Check if freq is the masked frequency for this cluster */
static bool was_mask_freq(struct cpufreq_policy *policy, unsigned int freq)
{
	int cluster_id;
	int *eff_table;

	cluster_id = get_cluster_num(policy);
	if (cluster_id < 0 || cluster_id >= MAX_CLUSTER)
		return false;

	eff_table = cluster_efficiency_table[cluster_id];
	return (freq == READ_ONCE(eff_table[4]));	/* index 4 = mask_freq */
}

/* Select more efficient frequency based on load threshold */
static unsigned int select_efficiency_freq(struct cpufreq_policy *policy,
					   unsigned int freq,
					   unsigned int loadadj_freq)
{
	int index_temp, cluster_id;
	unsigned int freq_temp, affect_thres;
	int *eff_table;

	if (!policy || !policy->freq_table)
		return freq;

	index_temp = cpufreq_frequency_table_target(policy, freq - 1,
						    CPUFREQ_RELATION_H);
	if (index_temp < 0)
		return freq;

	freq_temp = policy->freq_table[index_temp].frequency;
	if (loadadj_freq > freq || loadadj_freq < freq_temp)
		return freq;

	cluster_id = get_cluster_num(policy);
	if (cluster_id < 0 || cluster_id >= MAX_CLUSTER)
		return freq;

	eff_table = cluster_efficiency_table[cluster_id];

	/* Determine threshold based on frequency level */
	if (READ_ONCE(eff_table[2]) > 0 && freq >= READ_ONCE(eff_table[2])) {
		affect_thres = READ_ONCE(eff_table[3]);	/* level 2 */
	} else if (READ_ONCE(eff_table[0]) > 0
		   && freq >= READ_ONCE(eff_table[0])) {
		affect_thres = READ_ONCE(eff_table[1]);	/* level 1 */
	} else {
		affect_thres = 0;
	}

	if (affect_thres > 0 &&
	    abs((long)loadadj_freq - (long)freq_temp) < (long)affect_thres)
		return freq_temp;

	return freq;
}

/* Adjust target frequency for power efficiency */
unsigned int xiaomi_update_power_eff_lock(struct cpufreq_policy *policy,
					  unsigned int freq,
					  unsigned int loadadj_freq)
{
	if (!affect_mode || freq == 0 || !policy)
		return freq;

	/* Case 1: mask this frequency */
	if (was_mask_freq(policy, freq)) {
		int temp_index =
		    cpufreq_frequency_table_target(policy, freq - 1,
						   CPUFREQ_RELATION_H);
		if (temp_index >= 0 && policy->freq_table)
			return policy->freq_table[temp_index].frequency;
		return freq;
	}

	/* Case 2: crossing power domain boundary */
	if (was_diff_powerdomain(policy, freq)) {
		return select_efficiency_freq(policy, freq, loadadj_freq);
	}

	return freq;
}

EXPORT_SYMBOL(xiaomi_update_power_eff_lock);

/* Detect SoC platform */
static int cpufreq_pd_init(void)
{
	const char *prop_str;
	struct device_node *of_root;

	of_root = of_find_node_by_path("/");
	if (!of_root) {
		pr_info("of_root is null!\n");
		return -1;
	}

	prop_str = of_get_property(of_root, "compatible", NULL);
	if (!prop_str) {
		pr_info("of_root's compatible is null!\n");
		of_node_put(of_root);
		return -1;
	}

	if (strstr(prop_str, PLATFORM_SM8350))
		platform_soc_id = SM8350_SOC_ID;
	else
		platform_soc_id = ABSENT_SOC_ID;

	of_node_put(of_root);
	return 0;
}

/* Initialize OPP count per cluster */
static int frequency_opp_init(struct cpufreq_policy *policy)
{
	int first_cpu, cluster_id, opp_num;
	struct device *cpu_dev;

	if (!policy)
		return -1;

	first_cpu = cpumask_first(policy->related_cpus);
	cpu_dev = get_cpu_device(first_cpu);
	if (!cpu_dev) {
		pr_err("failed to get cpu device\n");
		return -1;
	}

	cluster_id = topology_physical_package_id(cpu_dev->id);
	if (cluster_id < 0 || cluster_id >= MAX_CLUSTER) {
		pr_err("invalid cluster id: %d\n", cluster_id);
		return -1;
	}

	opp_num = dev_pm_opp_get_opp_count(cpu_dev);
	if (opp_num > 0)
		opp_number[cluster_id] = opp_num;

	return 0;
}

/* Module init */
static int __init xiaomi_cpufreq_eff_init(void)
{
	struct cpufreq_policy *policy;
	int cpu;

	for_each_possible_cpu(cpu) {
		policy = cpufreq_cpu_get(cpu);
		if (!policy) {
			pr_err("cpu %d, policy is null\n", cpu);
			continue;
		}
		frequency_opp_init(policy);
		cpufreq_cpu_put(policy);
	}

	cpufreq_pd_init();
	pr_info("xiaomi_cpufreq_eff_init finished.\n");
	return 0;
}

module_init(xiaomi_cpufreq_eff_init);

MODULE_DESCRIPTION("Xiaomi CPUFreq Efficiency (Lock-Free)");
MODULE_VERSION("1.1");
MODULE_LICENSE("GPL v2");
