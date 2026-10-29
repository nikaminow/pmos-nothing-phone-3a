// SPDX-License-Identifier: GPL-2.0
/*
 * Nothing Phone (3a) vibration motor: RT6010 LRA driver as a force-feedback (rumble) input device.
 *
 * Register sequences follow Nothing's GPL driver (drivers/misc/haptic/rt6010.c and haptic_drv.c
 * in NothingOSS/android_kernel_msm-6.1_nothing_sm7635): reset, efuse trim, RAM layout, boost,
 * gain and LRA f0, then waveform 0 of haptic_config.bin (copied from the phone's vendor
 * firmware) played from the chip's RAM while the effect runs.
 */
#include <linux/delay.h>
#include <linux/firmware.h>
#include <linux/gpio/consumer.h>
#include <linux/i2c.h>
#include <linux/input.h>
#include <linux/module.h>
#include <linux/regmap.h>
#include <linux/workqueue.h>

#define RT6010_REG_DEV_ID		0x00
#define RT6010_REG_SOFT_RESET		0x02
#define RT6010_REG_RAM_CFG		0x07
#define RT6010_REG_RAM_ADDR_L		0x08
#define RT6010_REG_RAM_ADDR_H		0x09
#define RT6010_REG_RAM_DATA		0x0a
#define RT6010_REG_FIFO_AE_L		0x0c
#define RT6010_REG_FIFO_AE_H		0x0d
#define RT6010_REG_FIFO_AF_L		0x0e
#define RT6010_REG_FIFO_AF_H		0x0f
#define RT6010_REG_PLAY_MODE		0x11
#define RT6010_REG_PLAY_CTRL		0x12
#define RT6010_REG_WAVE_BASE_ADDR_L	0x1c
#define RT6010_REG_WAVE_BASE_ADDR_H	0x1d
#define RT6010_REG_LIST_BASE_ADDR_L	0x1e
#define RT6010_REG_LIST_BASE_ADDR_H	0x1f
#define RT6010_REG_GAIN_CFG		0x20
#define RT6010_REG_SYS_CFG		0x23
#define RT6010_REG_PROTECTION_STATUS1	0x26
#define RT6010_REG_PROTECTION_STATUS2	0x27
#define RT6010_REG_ANA_2A		0x2a
#define RT6010_REG_LRA_F0_CFG1		0x2d
#define RT6010_REG_LRA_F0_CFG2		0x2e
#define RT6010_REG_BEMF_CFG1		0x50
#define RT6010_REG_BEMF_CFG2		0x51
#define RT6010_REG_BOOST_CFG1		0x55
#define RT6010_REG_BOOST_CFG2		0x56
#define RT6010_REG_BOOST_CFG3		0x57
#define RT6010_REG_BOOST_CFG4		0x58
#define RT6010_REG_BOOST_CFG5		0x59
#define RT6010_REG_PA_CFG1		0x5a
#define RT6010_REG_PA_CFG2		0x5b
#define RT6010_REG_PMU_CFG2		0x5d
#define RT6010_REG_PMU_CFG3		0x5e
#define RT6010_REG_PMU_CFG4		0x5f
#define RT6010_REG_OSC_CFG1		0x60
#define RT6010_REG_EFS_RD_DATA		0x67
#define RT6010_REG_EFS_ADDR_INDEX	0x68
#define RT6010_REG_EFS_MODE_CTRL	0x69

#define RT6010_CHIP_ID			0x6b
#define RT6010_EFS_READ			BIT(1)
#define RT6010_PLAY_MODE_RAM		0x01
#define RT6010_RAM_SIZE			1536

/* ABL's DTB for the 3a (ics_haptic@5f) */
#define RT6010_LIST_BASE		0x400
#define RT6010_WAVE_BASE		0x420
#define RT6010_FIFO_AE			0x200
#define RT6010_FIFO_AF			0x300
#define RT6010_BOOST_VOL		0x0a
#define RT6010_GAIN			0x80
#define RT6010_F0			1700	/* 0.1 Hz */

#define RT6010_FIRMWARE			"haptic_config.bin"

struct rt6010 {
	struct regmap *regmap;
	struct device *dev;
	struct gpio_desc *enable;
	struct gpio_desc *irq;
	struct input_dev *input;
	struct work_struct play_work;
	u16 magnitude;
	bool have_waveform;
};

static void rt6010_hw_reset(struct rt6010 *rt)
{
	gpiod_set_value_cansleep(rt->enable, 0);
	gpiod_set_value_cansleep(rt->irq, 0);
	usleep_range(1000, 2000);
	gpiod_set_value_cansleep(rt->enable, 1);
	gpiod_set_value_cansleep(rt->irq, 1);
	usleep_range(1000, 2000);
}

static int rt6010_efuse_read(struct rt6010 *rt, u8 index, u8 *data)
{
	unsigned int val;
	int i, ret;

	ret = regmap_write(rt->regmap, RT6010_REG_EFS_ADDR_INDEX, index);
	if (ret)
		return ret;
	ret = regmap_write(rt->regmap, RT6010_REG_EFS_MODE_CTRL, RT6010_EFS_READ);
	if (ret)
		return ret;

	for (i = 0; i < 3; i++) {
		usleep_range(10, 20);
		ret = regmap_read(rt->regmap, RT6010_REG_EFS_MODE_CTRL, &val);
		if (ret)
			return ret;
		if (!(val & RT6010_EFS_READ)) {
			ret = regmap_read(rt->regmap, RT6010_REG_EFS_RD_DATA, &val);
			*data = val;
			return ret;
		}
	}

	return -ETIMEDOUT;
}

static int rt6010_apply_trim(struct rt6010 *rt)
{
	unsigned int val;
	u32 efs = 0;
	u8 byte;
	int i, ret;

	ret = regmap_write(rt->regmap, RT6010_REG_SOFT_RESET, 0x01);
	if (ret)
		return ret;

	for (i = 0; i < 4; i++) {
		ret = rt6010_efuse_read(rt, i, &byte);
		if (ret)
			return ret;
		efs |= (u32)byte << (8 * i);
	}
	dev_dbg(rt->dev, "efuse %08x\n", efs);

	ret = regmap_read(rt->regmap, RT6010_REG_PMU_CFG3, &val);
	if (ret)
		return ret;
	val = (val & 0x4f) | (((efs >> 9) & 1) << 7) | (((efs >> 8) & 1) << 4);
	regmap_write(rt->regmap, RT6010_REG_PMU_CFG3, val);
	regmap_write(rt->regmap, RT6010_REG_PMU_CFG4, ((efs & 0x0f) << 4) | ((efs & 0xf0) >> 4));
	regmap_write(rt->regmap, RT6010_REG_OSC_CFG1, ((efs >> 10) & 0xff) ^ 0x80);

	regmap_write(rt->regmap, RT6010_REG_BOOST_CFG1, 0x01);
	regmap_write(rt->regmap, RT6010_REG_BOOST_CFG2, 0x05);
	regmap_write(rt->regmap, RT6010_REG_BOOST_CFG3, 0x0a);

	if (((efs >> 30) & 0x3) == 0x01) {
		regmap_write(rt->regmap, RT6010_REG_ANA_2A, 0x0f);
		regmap_write(rt->regmap, RT6010_REG_BEMF_CFG1, 0x00);
		regmap_write(rt->regmap, RT6010_REG_BOOST_CFG4, 0x50);
	} else {
		regmap_write(rt->regmap, RT6010_REG_ANA_2A, 0x0b);
		regmap_write(rt->regmap, RT6010_REG_BEMF_CFG1, 0x06);
		regmap_write(rt->regmap, RT6010_REG_BOOST_CFG4, 0x58);
	}

	regmap_write(rt->regmap, RT6010_REG_BOOST_CFG5, 0x1c);
	regmap_write(rt->regmap, RT6010_REG_PA_CFG1, 0x2c);
	regmap_write(rt->regmap, RT6010_REG_PA_CFG2, 0x03);
	regmap_write(rt->regmap, RT6010_REG_PMU_CFG2, 0x1c);
	regmap_write(rt->regmap, RT6010_REG_BEMF_CFG2, 0x03);

	return regmap_write(rt->regmap, RT6010_REG_BEMF_CFG2, 0x01);
}

static int rt6010_load_waveforms(struct rt6010 *rt)
{
	const struct firmware *fw;
	int ret;

	ret = request_firmware(&fw, RT6010_FIRMWARE, rt->dev);
	if (ret)
		return ret;

	if (fw->size == 0 || fw->size > RT6010_RAM_SIZE - RT6010_WAVE_BASE) {
		dev_err(rt->dev, "%s: bad size %zu\n", RT6010_FIRMWARE, fw->size);
		ret = -EINVAL;
		goto out;
	}

	regmap_write(rt->regmap, RT6010_REG_RAM_ADDR_H, RT6010_WAVE_BASE >> 8);
	regmap_write(rt->regmap, RT6010_REG_RAM_ADDR_L, RT6010_WAVE_BASE & 0xff);
	ret = regmap_raw_write(rt->regmap, RT6010_REG_RAM_DATA, fw->data, fw->size);
out:
	release_firmware(fw);
	return ret;
}

static int rt6010_init(struct rt6010 *rt)
{
	unsigned int val, f0;
	int ret;

	ret = rt6010_apply_trim(rt);
	if (ret)
		return ret;

	regmap_write(rt->regmap, RT6010_REG_RAM_CFG, 0x08);
	regmap_write(rt->regmap, RT6010_REG_LIST_BASE_ADDR_H, RT6010_LIST_BASE >> 8);
	regmap_write(rt->regmap, RT6010_REG_LIST_BASE_ADDR_L, RT6010_LIST_BASE & 0xff);
	regmap_write(rt->regmap, RT6010_REG_WAVE_BASE_ADDR_H, RT6010_WAVE_BASE >> 8);
	regmap_write(rt->regmap, RT6010_REG_WAVE_BASE_ADDR_L, RT6010_WAVE_BASE & 0xff);
	regmap_write(rt->regmap, RT6010_REG_FIFO_AE_H, RT6010_FIFO_AE >> 8);
	regmap_write(rt->regmap, RT6010_REG_FIFO_AE_L, RT6010_FIFO_AE & 0xff);
	regmap_write(rt->regmap, RT6010_REG_FIFO_AF_H, RT6010_FIFO_AF >> 8);
	regmap_write(rt->regmap, RT6010_REG_FIFO_AF_L, RT6010_FIFO_AF & 0xff);
	regmap_write(rt->regmap, RT6010_REG_SYS_CFG, 0x06);

	ret = regmap_read(rt->regmap, RT6010_REG_BOOST_CFG3, &val);
	if (ret)
		return ret;
	regmap_write(rt->regmap, RT6010_REG_BOOST_CFG3, (val & 0xf0) | RT6010_BOOST_VOL);
	regmap_write(rt->regmap, RT6010_REG_GAIN_CFG, RT6010_GAIN);

	f0 = 1920000 / RT6010_F0;
	regmap_write(rt->regmap, RT6010_REG_LRA_F0_CFG2, (f0 & 0x3f00) >> 8);
	regmap_write(rt->regmap, RT6010_REG_LRA_F0_CFG1, f0 & 0xff);

	ret = rt6010_load_waveforms(rt);
	if (ret)
		dev_warn(rt->dev, "no %s (%d): the motor stays silent\n", RT6010_FIRMWARE, ret);
	rt->have_waveform = !ret;

	/* clear protection flags */
	regmap_read(rt->regmap, RT6010_REG_PROTECTION_STATUS1, &val);
	regmap_read(rt->regmap, RT6010_REG_PROTECTION_STATUS2, &val);
	ret = regmap_read(rt->regmap, RT6010_REG_BEMF_CFG2, &val);
	if (ret)
		return ret;
	regmap_write(rt->regmap, RT6010_REG_BEMF_CFG2, val | 0x02);
	return regmap_write(rt->regmap, RT6010_REG_BEMF_CFG2, val & 0xfd);
}

static void rt6010_play_work(struct work_struct *work)
{
	struct rt6010 *rt = container_of(work, struct rt6010, play_work);
	/* one entry: waveform 0, repeated 0x7f times (as Nothing's vibrator_work_routine) */
	static const u8 playlist[] = { 0x01, 0x00, 0x7f, 0x00, 0x00, 0x00 };
	u16 magnitude = READ_ONCE(rt->magnitude);

	regmap_write(rt->regmap, RT6010_REG_PLAY_CTRL, 0x00);
	if (!magnitude || !rt->have_waveform)
		return;

	regmap_write(rt->regmap, RT6010_REG_RAM_ADDR_H, RT6010_LIST_BASE >> 8);
	regmap_write(rt->regmap, RT6010_REG_RAM_ADDR_L, RT6010_LIST_BASE & 0xff);
	regmap_raw_write(rt->regmap, RT6010_REG_RAM_DATA, playlist, sizeof(playlist));
	/* never above the gain Nothing configures for this motor */
	regmap_write(rt->regmap, RT6010_REG_GAIN_CFG, max(1U, (unsigned int)RT6010_GAIN * magnitude / 0xffff));
	regmap_write(rt->regmap, RT6010_REG_PLAY_MODE, RT6010_PLAY_MODE_RAM);
	regmap_write(rt->regmap, RT6010_REG_PLAY_CTRL, 0x01);
}

static int rt6010_play_effect(struct input_dev *input, void *data, struct ff_effect *effect)
{
	struct rt6010 *rt = input_get_drvdata(input);

	WRITE_ONCE(rt->magnitude, max(effect->u.rumble.strong_magnitude,
				      effect->u.rumble.weak_magnitude));
	schedule_work(&rt->play_work);
	return 0;
}

static void rt6010_close(struct input_dev *input)
{
	struct rt6010 *rt = input_get_drvdata(input);

	WRITE_ONCE(rt->magnitude, 0);
	cancel_work_sync(&rt->play_work);
	regmap_write(rt->regmap, RT6010_REG_PLAY_CTRL, 0x00);
}

static const struct regmap_config rt6010_regmap = {
	.reg_bits = 8,
	.val_bits = 8,
};

static int rt6010_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct rt6010 *rt;
	unsigned int id;
	int ret;

	rt = devm_kzalloc(dev, sizeof(*rt), GFP_KERNEL);
	if (!rt)
		return -ENOMEM;
	rt->dev = dev;
	INIT_WORK(&rt->play_work, rt6010_play_work);

	rt->regmap = devm_regmap_init_i2c(client, &rt6010_regmap);
	if (IS_ERR(rt->regmap))
		return PTR_ERR(rt->regmap);

	rt->enable = devm_gpiod_get(dev, "enable", GPIOD_OUT_HIGH);
	if (IS_ERR(rt->enable))
		return dev_err_probe(dev, PTR_ERR(rt->enable), "enable gpio\n");
	rt->irq = devm_gpiod_get_optional(dev, "irq", GPIOD_OUT_HIGH);
	if (IS_ERR(rt->irq))
		return dev_err_probe(dev, PTR_ERR(rt->irq), "irq gpio\n");

	rt6010_hw_reset(rt);
	ret = regmap_read(rt->regmap, RT6010_REG_DEV_ID, &id);
	if (ret)
		return dev_err_probe(dev, ret, "no reply on i2c\n");
	if (id != RT6010_CHIP_ID)
		return dev_err_probe(dev, -ENODEV, "chip id %02x, expected %02x\n", id, RT6010_CHIP_ID);

	ret = rt6010_init(rt);
	if (ret)
		return dev_err_probe(dev, ret, "init failed\n");

	rt->input = devm_input_allocate_device(dev);
	if (!rt->input)
		return -ENOMEM;
	rt->input->name = "rt6010-haptics";
	rt->input->id.bustype = BUS_I2C;
	rt->input->close = rt6010_close;
	input_set_drvdata(rt->input, rt);
	input_set_capability(rt->input, EV_FF, FF_RUMBLE);

	ret = input_ff_create_memless(rt->input, NULL, rt6010_play_effect);
	if (ret)
		return ret;

	ret = input_register_device(rt->input);
	if (ret)
		return ret;

	dev_info(dev, "RT6010 haptics ready%s\n", rt->have_waveform ? "" : " (no waveforms)");
	return 0;
}

static const struct of_device_id rt6010_of_match[] = {
	{ .compatible = "nothing,rt6010-haptics" },
	{ }
};
MODULE_DEVICE_TABLE(of, rt6010_of_match);

static struct i2c_driver rt6010_driver = {
	.probe = rt6010_probe,
	.driver = {
		.name = "rt6010-haptics",
		.of_match_table = rt6010_of_match,
	},
};
module_i2c_driver(rt6010_driver);

MODULE_DESCRIPTION("Nothing Phone (3a) RT6010 vibration motor");
MODULE_LICENSE("GPL");
MODULE_FIRMWARE(RT6010_FIRMWARE);
