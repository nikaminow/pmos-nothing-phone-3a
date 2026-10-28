// SPDX-License-Identifier: GPL-2.0
/*
 * Nothing Phone (3a): keep the WCN6755 RF powered for Wi-Fi.
 * ath11k_ahb (WCN6750 family) never asks the WCN PMU for power, so the RF was only up while
 * Bluetooth held the PMU; with Bluetooth off the WPSS could scan but not transmit.
 * This driver is the PMU's "wlan" consumer and keeps that target on while bound.
 */
#include <linux/mod_devicetable.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/pwrseq/consumer.h>

static int wlan_pwr_probe(struct platform_device *pdev)
{
	struct pwrseq_desc *pwrseq;

	/* matched to the PMU through this node's vddaon-supply */
	pwrseq = devm_pwrseq_get(&pdev->dev, "wlan");
	if (IS_ERR(pwrseq))
		return dev_err_probe(&pdev->dev, PTR_ERR(pwrseq), "no WCN power sequencer\n");

	platform_set_drvdata(pdev, pwrseq);
	return pwrseq_power_on(pwrseq);
}

static void wlan_pwr_remove(struct platform_device *pdev)
{
	pwrseq_power_off(platform_get_drvdata(pdev));
}

static const struct of_device_id wlan_pwr_of_match[] = {
	{ .compatible = "nothing,asteroids-wlan-pwr" },
	{ }
};
MODULE_DEVICE_TABLE(of, wlan_pwr_of_match);

static struct platform_driver wlan_pwr_driver = {
	.probe = wlan_pwr_probe,
	.remove = wlan_pwr_remove,
	.driver = {
		.name = "3a-wlan-pwr",
		.of_match_table = wlan_pwr_of_match,
	},
};
module_platform_driver(wlan_pwr_driver);

MODULE_DESCRIPTION("Nothing Phone (3a) WCN6755 RF power for Wi-Fi");
MODULE_LICENSE("GPL");
