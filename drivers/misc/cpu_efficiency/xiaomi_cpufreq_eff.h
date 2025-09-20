/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _XIAOMI_CPUFREQ_EFF_H
#define _XIAOMI_CPUFREQ_EFF_H

#include <linux/kernel.h>
#include <linux/kernel_stat.h>
#include <linux/cpufreq.h>
#include <linux/sched.h>
#include <linux/cpu.h>
#include <linux/types.h>
#include <linux/sysfs.h>
#include <linux/string.h>
#include <linux/topology.h>
#include <linux/slab.h>
#include <linux/cpumask.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/pm_opp.h>
#include <linux/platform_device.h>

#ifdef pr_fmt
#undef pr_fmt
#endif
#define pr_fmt(fmt) "xiaomi_cpufreq_eff: " fmt

// Keep SOC ID definitions from original file
#define ABSENT_SOC_ID 0
#define SM8350_SOC_ID 415
#define PLATFORM_SM8350 "lahaina"

// define the cluster information
#define MAX_CLUSTER 3
#define SLIVER_CLUSTER 0
#define GOLDEN_CLUSTER 1
#define GOPLUS_CLUSTER 2

// define the parameter size
#define MAX_CLUSTER_PARAMETERS 5
#define AFFECT_FREQ_VALUE1 0
#define AFFECT_THRES_SIZE1 1
#define AFFECT_FREQ_VALUE2 2
#define AFFECT_THRES_SIZE2 3
#define MASK_FREQ_VALUE 4

#ifdef CONFIG_XIAOMI_CPUFREQ_EFF
unsigned int xiaomi_update_power_eff_lock(struct cpufreq_policy *policy,
					  unsigned int freq,
					  unsigned int loadadj_freq);
#else
static inline unsigned int
xiaomi_update_power_eff_lock(struct cpufreq_policy *policy, unsigned int freq,
			     unsigned int loadadj_freq)
{
	return freq;
}
#endif // CONFIG_XIAOMI_CPUFREQ_EFF

#endif // _XIAOMI_CPUFREQ_EFF_H
