# Camera on the Nothing Phone (3a): mainline CAMSS port plan

## Findings (2026-10-29, from Qualcomm's GPL camera-driver vs mainline camss)
- **TFE665 = same IP family as mainline "340" TFE (QCM2290).** Top block = 340 offsets + 0x1800
  (global_reset 0x1814, core_cfg_0 0x1824, reg_update 0x182C, irq_cmd 0x1830, irq_mask 0x1834..,
  irq_clear0 0x1840, irq_status0 0x184C); same IRQ and reg_update bits. Bus / write masters:
  base 0x3000 (340: 0xa00), identical layout inside (client(c) = 0x200 + c*0x100), clients 0-9 same
  order; RDI0-2 in composite groups 5-7, buffer-done mask 0xFFF00.
  Differences: RDI packer PLAIN128 (0x0, 340 uses PLAIN64 0xa; RDI bpl align 8 -> 16), and
  downstream writes rdi_module_config (enable bit 0) at 0x1E60/0x2060/0x2260 on RDI start.
  Downstream TFE offsets are relative to the CSID base (as on QCM2290: vfe = csid + 0x1000), so
  with a vfe reg at csid + 0x1000: top at 0x800, bus at 0x2000. **Verify with the tfe665 reg.**
- **CSID665 = CSID 340 layout** (rst_strobes 0x10/0x1e, IRQs 0x70.., RX_CFG0/1 0x100/0x104,
  RDI0-2 at 0x300/0x400/0x500): reuse csid_ops_340 unchanged.
- **CSIPHY v2.2.1 = v2.2.0 byte for byte**, which mainline already has (lane_regs_sm8650,
  offset 0x1000): add the version to csiphy_is_gen2() and the CAMSS_8650 case in csiphy_init().
- milos.dtsi already has camcc (single GDSC CAM_CC_CAMSS_TOP_GDSC), both CCIs and apps_smmu.
- No ICP / CDM / firmware needed for TFE+CSID RDI capture.
- Risks: SMMU stream IDs (secure / hypervisor-owned banks), CSIPHY rails and clock rates (wrong
  values = silent no-SOT), CAMNOC QoS only at high resolutions, and **sensor drivers**.
- Mainline sensor drivers that might match: s5kjn1 (Samsung JN1 50 MP 1/2.76", telephoto?),
  imx355 (Sony 8 MP, ultrawide?). Real models: read /vendor camera sensor modules on the phone.

## Hardware (ABL DTB)
4 sensors, MCLK 19.2 MHz: idx0 rear (CCI0, CSIPHY0, MCLK0/RESET0), idx1 front (CCI1, CSIPHY1,
rotated 270), idx2 rear (CCI1, CSIPHY3, MCLK3), idx3 rear (CCI0, CSIPHY2, MCLK2).
TFE/CSID x3 (csid0 at 0xac62000, cpas top 0xac13000), CSIPHY v2.2.1 x4, TPG 1031 x4.

## Steps
1. Extract from ABL DTB: tfe/csid/csiphy reg + IRQs, clock-rates, regulators, SMMU SIDs, CPAS BW;
   settle the TFE reg base. (0.5 d)
2. CAMSS_MILOS + CSIPHY cases reusing the sm8650 table. (0.5 d)
3. Parameterize camss-vfe-340.c into vfe_ops_665 (top/bus base, PLAIN128, rdi_module_config,
   comp mask). Reuse csid_ops_340. (1-2 d)
4. camss.c resources (3 csid, 3 vfe, 4 csiphy), ICC, pm_clks, bpl align. (1 d)
5. camss node + sensor endpoints in an overlay (later: binding yaml for upstreaming). (1-2 d)
6. **Milestone 1:** one sensor -> CSIPHY -> CSID0 -> TFE0 RDI0 -> RAW10 capture with yavta. (2-5 d)
7. Other sensors; libcamera simple pipeline + soft ISP for usable pictures.
