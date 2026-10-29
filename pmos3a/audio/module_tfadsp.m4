# SPDX-License-Identifier: BSD-3-Clause
include(`util/util.m4') dnl
dnl Goodix/NXP TFA speaker protection, a vendor CAPI module the ADSP loads through AMDB
dnl (libtfadsp_rx.so). Its calibration is sent by the kernel from
dnl qcom/audioreach/module-1700b911.bin.
define(`MODULE_ID_TFADSP_RX', 0x1700B911) dnl
dnl AR_MODULE_TFADSP_RX(index, sgidx, container-idx, iid, max-ip-ports, max-op-ports, src-port,
dnl dst-port, dst-iid)
define(`AR_MODULE_TFADSP_RX',
`'
`SectionVendorTuples."NAME_PREFIX.tfadsp_rx$1_tuples" {'
`        tokens "audioreach_tokens"'
`'
`        tuples."word.u32_data" {'
`                AR_TKN_U32_MODULE_INSTANCE_ID STR($4)'
`                AR_TKN_U32_MODULE_ID STR(MODULE_ID_TFADSP_RX)'
`                AR_TKN_U32_MODULE_MAX_IP_PORTS STR($5)'
`                AR_TKN_U32_MODULE_MAX_OP_PORTS STR($6)'
`                AR_TKN_U32_MODULE_SRC_OP_PORT_ID STR($7)'
`                AR_TKN_U32_MODULE_DST_IN_PORT_ID STR($8)'
`                AR_TKN_U32_MODULE_SRC_INSTANCE_ID STR($4)'
`                AR_TKN_U32_MODULE_DST_INSTANCE_ID STR($9)'
`        }'
`}'
`'
`SectionData."NAME_PREFIX.tfadsp_rx$1_data" {'
`        tuples "NAME_PREFIX.tfadsp_rx$1_tuples"'
`}'
`'
`SectionWidget."NAME_PREFIX.tfadsp_rx$1" {'
`        index STR($1)'
`        type "buffer"'
`        no_pm "true"'
`        subseq "10"'
`        data ['
`                "NAME_PREFIX.sub_graph$2_data"'
`                "NAME_PREFIX.container$3_data"'
`                "NAME_PREFIX.tfadsp_rx$1_data"'
`        ]'
`}') dnl
