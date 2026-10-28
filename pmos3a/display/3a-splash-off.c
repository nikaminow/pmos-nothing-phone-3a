// SPDX-License-Identifier: GPL-2.0
/*
 * Nothing Phone (3a): stop ABL's splash scanout before msm binds.
 * ABL leaves DPU INTF_1 (DSI) running from its framebuffer; when msm attaches the MDP to the
 * SMMU the fetches fault, mdp_clk_src gets stuck and the panel's DSI commands time out, so the
 * first bind always failed and needed an unbind/rebind (which trips use-after-free bugs in msm).
 * Load before msm; the module does its work at init and then stays inert.
 */
#include <linux/delay.h>
#include <linux/io.h>
#include <linux/module.h>

#define DPU_INTF1		0x0ae36000	/* mdp 0x0ae01000 + catalog intf_1 0x35000 */
#define INTF_TIMING_ENGINE_EN	0x6c

static bool stopped;
module_param(stopped, bool, 0444);
MODULE_PARM_DESC(stopped, "the splash timing engine was running and is now off");

static int __init splash_off_init(void)
{
	void __iomem *intf = ioremap(DPU_INTF1, 0x300);
	u32 en;

	if (!intf)
		return -ENOMEM;

	en = readl(intf + INTF_TIMING_ENGINE_EN);
	if (en & 1) {
		writel(0, intf + INTF_TIMING_ENGINE_EN);
		msleep(20);	/* let the last frame finish */
		stopped = !(readl(intf + INTF_TIMING_ENGINE_EN) & 1);
	}
	pr_info("3a-splash-off: INTF_1 timing engine was %#x, %s\n", en,
		stopped ? "stopped" : "left alone");

	iounmap(intf);
	return 0;
}
module_init(splash_off_init);

MODULE_DESCRIPTION("Nothing Phone (3a): stop the bootloader splash before msm");
MODULE_LICENSE("GPL");
