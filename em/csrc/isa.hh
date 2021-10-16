#ifndef ISA_H
#define ISA_H

#include "common.hh"

/*
 * Opcodes
 */

#define INS32_NOP (INS32_OP_AND)

#define INS32_OP_AND    0x0
#define INS32_OP_AND_I  0x1
#define INS32_OP_OR     0x2
#define INS32_OP_OR_I   0x3
#define INS32_OP_XOR    0x4
#define INS32_OP_XOR_I  0x5
#define INS32_OP_LSL    0x6
#define INS32_OP_LSL_I  0x7
#define INS32_OP_LSR    0x8
#define INS32_OP_LSR_I  0x9
#define INS32_OP_ADD    0xa
#define INS32_OP_ADD_I  0xb
#define INS32_OP_SUB    0xc
#define INS32_OP_JMP    0xd
#define INS32_OP_JMP_I  0xe
#define INS32_OP_JMP_I_LNK 0xf
#define INS32_OP_BEQ    0x10
#define INS32_OP_BNE    0x11
#define INS32_OP_BGT    0x12
#define INS32_OP_BGTU   0x13
#define INS32_OP_BLE    0x14
#define INS32_OP_BLEU   0x15

#define INS32_OP_LDWU   0x17
#define INS32_OP_STW    0x18
#define INS32_OP_LDHU   0x19
#define INS32_OP_LDH    0x1a
#define INS32_OP_STH    0x1b
#define INS32_OP_LDBU   0x1c
#define INS32_OP_LDB    0x1d
#define INS32_OP_STB    0x1e

#define INS32_OP_BARR   0x20
#define INS32_OP_SYSCALL 0x21
#define INS32_OP_RETE    0x22
#define INS32_OP_WMSR   0x23
#define INS32_OP_RMSR   0x24


#define INS32_OP_ASR    0x30
#define INS32_OP_ASR_I  0x31
#define INS32_OP_MUL    0x32
#define INS32_OP_DIV    0x33
#define INS32_OP_DIVU   0x34
#define INS32_OP_MOD    0x35
#define INS32_OP_MODU   0x36
#define INS32_OP_MHI    0x37

#define INS32_OP_LDWA   0x50
#define INS32_OP_STWA   0x51

#define INS32_MASK_OPCODE   0x00000fe0
#define INS32_MASK_RD       0x0000001f
#define INS32_MASK_RS1      0x0001f000
#define INS32_MASK_RS2      0x003e0000
#define INS32_MASK_IMM15    0xfffe0000
#define INS32_MASK_IMM17    0xffff8000
#define INS32_MASK_REL15    0xfffe0000
#define INS32_MASK_REL25    0xfffff01f
#define INS32_MASK_FMT1_OPC2     0xffc00000

#define INS32_SHIFTRIGHT_OPCODE   5
#define INS32_SHIFTRIGHT_RD       0
#define INS32_SHIFTRIGHT_RS1      (5+7)
#define INS32_SHIFTRIGHT_RS2      (5+7+5)
#define INS32_SHIFTRIGHT_IMM15    (5+7+5)
#define INS32_SHIFTRIGHT_IMM17    (5+7+3)
#define INS32_SHIFTRIGHT_REL15    (5+7+5)
#define INS32_SHIFTRIGHT_FMT1_OPC2     (5+7+5+5)

static inline uint32_t ins32_parse_rel25(insn_t insn)
{
    return (insn&0x1f) | (((insn>>12)&0xfffff)<<5);
}

#define INS32_GET_BITS(src, opc) ((uint32_t)((src) & INS32_MASK_ ## opc) >> (INS32_SHIFTRIGHT_ ## opc))

#define INSN_LEN            4
#define INSN_LEN_SHIFT      2

#define ADDR_RLNK           1
#define ADDR_SP             2

/*
 * MSR
 */

#define MAX_MSR_BANK_BITS 9 /* (1 << MAX_MSR_BANK_BITS) = 512 */

/* MSR banks  */
#define MSR_BANK_PS (0 << MAX_MSR_BANK_BITS)
#define MSR_BANK_IMM (1 << MAX_MSR_BANK_BITS)
#define MSR_BANK_DMM (2 << MAX_MSR_BANK_BITS)
#define MSR_BANK_ICA (3 << MAX_MSR_BANK_BITS)
#define MSR_BANK_DCA (4 << MAX_MSR_BANK_BITS)
#define MSR_BANK_DBG (5 << MAX_MSR_BANK_BITS)
#define MSR_BANK_IRQC (6 << MAX_MSR_BANK_BITS)
#define MSR_BANK_TSC (7 << MAX_MSR_BANK_BITS)
#define MSR_BANK_SR (8 << MAX_MSR_BANK_BITS)

/*********************************************************************
* MSR bank - PS
**********************************************************************/

/* MSR.PSR R/W */
#define MSR_PSR (MSR_BANK_PS + (1 << 0))
#define MSR_PSR_CY_SHIFT 1
#define MSR_PSR_CY (1 << MSR_PSR_CY_SHIFT)
#define MSR_PSR_OV_SHIFT 2
#define MSR_PSR_OV (1 << MSR_PSR_OV_SHIFT)
#define MSR_PSR_OE_SHIFT 3
#define MSR_PSR_OE (1 << MSR_PSR_OE_SHIFT)
#define MSR_PSR_RM_SHIFT 4
#define MSR_PSR_RM (1 << MSR_PSR_RM_SHIFT)
#define MSR_PSR_IRE_SHIFT 5
#define MSR_PSR_IRE (1 << MSR_PSR_IRE_SHIFT)
#define MSR_PSR_IMME_SHIFT 6
#define MSR_PSR_IMME (1 << MSR_PSR_IMME_SHIFT)
#define MSR_PSR_DMME_SHIFT 7
#define MSR_PSR_DMME (1 << MSR_PSR_DMME_SHIFT)
#define MSR_PSR_ICE_SHIFT 8
#define MSR_PSR_ICE (1 << MSR_PSR_ICE_SHIFT)
#define MSR_PSR_DCE_SHIFT 9
#define MSR_PSR_DCE (1 << MSR_PSR_DCE_SHIFT)

/* MSR.CPUID R */
#define MSR_CPUID (MSR_BANK_PS + (1 << 1))
#define MSR_CPUID_VER_SHIFT 0
#define MSR_CPUID_VER 0x000000ff
#define MSR_CPUID_REV_SHIFT 8
#define MSR_CPUID_REV 0x0003ff00
#define MSR_CPUID_FIMM_SHIFT 18
#define MSR_CPUID_FIMM (1 << MSR_CPUID_FIMM_SHIFT)
#define MSR_CPUID_FDMM_SHIFT 19
#define MSR_CPUID_FDMM (1 << MSR_CPUID_FDMM_SHIFT)
#define MSR_CPUID_FICA_SHIFT 20
#define MSR_CPUID_FICA (1 << MSR_CPUID_FICA_SHIFT)
#define MSR_CPUID_FDCA_SHIFT 21
#define MSR_CPUID_FDCA (1 << MSR_CPUID_FDCA_SHIFT)
#define MSR_CPUID_FDBG_SHIFT 22
#define MSR_CPUID_FDBG (1 << MSR_CPUID_FDBG_SHIFT)
#define MSR_CPUID_FFPU_SHIFT 23
#define MSR_CPUID_FFPU (1 << MSR_CPUID_FFPU_SHIFT)
#define MSR_CPUID_FIRQC_SHIFT 24
#define MSR_CPUID_FIRQC (1 << MSR_CPUID_FIRQC_SHIFT)
#define MSR_CPUID_FTSC_SHIFT 25
#define MSR_CPUID_FTSC (1 << MSR_CPUID_FTSC_SHIFT)

/* MSR.EPSR R/W */
#define MSR_EPSR (MSR_BANK_PS + (1 << 2))

/* MSR.EPC R/W */
#define MSR_EPC (MSR_BANK_PS + (1 << 3))

/* MSR.ELSA R/W */
#define MSR_ELSA (MSR_BANK_PS + (1 << 4))

/* MSR.COREID R */
#define MSR_COREID (MSR_BANK_PS + (1 << 5))

/* MSR.EVECT R/W */
#define MSR_EVECT (MSR_BANK_PS + (1 << 6))

/*********************************************************************
* MSR bank - IMM
**********************************************************************/

/* MSR.IMMID R */
#define MSR_IMMID (MSR_BANK_IMM + 0x0)
#define MSR_IMMID_STLB_SHIFT 0
#define MSR_IMMID_STLB 0x7
/* MSR.ITLBL R/W */
#define MSR_ITLBL (MSR_BANK_IMM + 0x100)
#define MSR_ITLBL_V_SHIFT 0
#define MSR_ITLBL_V 0x1
#define MSR_ITLBL_VPN_SHIFT 13
#define MSR_ITLBL_VPN (~((1 << MSR_ITLBL_VPN_SHIFT) - 1))
/* MSR.ITLBH R/W */
#define MSR_ITLBH (MSR_BANK_IMM + 0x180)
#define MSR_ITLBH_P_SHIFT 0
#define MSR_ITLBH_P (1 << MSR_ITLBH_P_SHIFT)
#define MSR_ITLBH_D_SHIFT 1
#define MSR_ITLBH_D (1 << MSR_ITLBH_D_SHIFT)
#define MSR_ITLBH_A_SHIFT 2
#define MSR_ITLBH_A (1 << MSR_ITLBH_A_SHIFT)
#define MSR_ITLBH_UX_SHIFT 3
#define MSR_ITLBH_UX (1 << MSR_ITLBH_UX_SHIFT)
#define MSR_ITLBH_RX_SHIFT 4
#define MSR_ITLBH_RX (1 << MSR_ITLBH_RX_SHIFT)
#define MSR_ITLBH_NC_SHIFT 7
#define MSR_ITLBH_NC (1 << MSR_ITLBH_NC_SHIFT)
#define MSR_ITLBH_S_SHIFT 8
#define MSR_ITLBH_S (1 << MSR_ITLBH_S_SHIFT)
#define MSR_ITLBH_PPN_SHIFT 13
#define MSR_ITLBH_PPN (~((1 << MSR_ITLBH_PPN_SHIFT) - 1))

/*********************************************************************
* MSR bank - DMM
**********************************************************************/

/* MSR.DMMID R */
#define MSR_DMMID (MSR_BANK_DMM + 0x0)
#define MSR_DMMID_STLB_SHIFT 0
#define MSR_DMMID_STLB 0x7
/* MSR.DTLBL R/W */
#define MSR_DTLBL (MSR_BANK_DMM + 0x100)
#define MSR_DTLBL_V_SHIFT 0
#define MSR_DTLBL_V 0x1
#define MSR_DTLBL_VPN_SHIFT 13
#define MSR_DTLBL_VPN (~((1 << MSR_DTLBL_VPN_SHIFT) - 1))
/* MSR.DTLBH R/W */
#define MSR_DTLBH (MSR_BANK_DMM + 0x180)
#define MSR_DTLBH_P_SHIFT 0
#define MSR_DTLBH_P (1 << MSR_DTLBH_P_SHIFT)
#define MSR_DTLBH_D_SHIFT 1
#define MSR_DTLBH_D (1 << MSR_DTLBH_D_SHIFT)
#define MSR_DTLBH_A_SHIFT 2
#define MSR_DTLBH_A (1 << MSR_DTLBH_A_SHIFT)
#define MSR_DTLBH_UW_SHIFT 3
#define MSR_DTLBH_UW (1 << MSR_DTLBH_UW_SHIFT)
#define MSR_DTLBH_UR_SHIFT 4
#define MSR_DTLBH_UR (1 << MSR_DTLBH_UR_SHIFT)
#define MSR_DTLBH_RW_SHIFT 5
#define MSR_DTLBH_RW (1 << MSR_DTLBH_RW_SHIFT)
#define MSR_DTLBH_RR_SHIFT 6
#define MSR_DTLBH_RR (1 << MSR_DTLBH_RR_SHIFT)
#define MSR_DTLBH_NC_SHIFT 7
#define MSR_DTLBH_NC (1 << MSR_DTLBH_NC_SHIFT)
#define MSR_DTLBH_S_SHIFT 8
#define MSR_DTLBH_S (1 << MSR_DTLBH_S_SHIFT)
#define MSR_DTLBH_PPN_SHIFT 13
#define MSR_DTLBH_PPN (~((1 << MSR_DTLBH_PPN_SHIFT) - 1))

/*********************************************************************
* MSR bank - ICA
**********************************************************************/

/* MSR.ICID */
#define MSR_ICID (MSR_BANK_ICA + (1 << 0))
#define MSR_ICID_SS_SHIFT 0
#define MSR_ICID_SS 0xf
#define MSR_ICID_SL_SHIFT 4
#define MSR_ICID_SL (0xf << MSR_ICID_SL_SHIFT)
#define MSR_ICID_SW_SHIFT 8
#define MSR_ICID_SW (0xf << MSR_ICID_SW_SHIFT)
#define MSR_ICINV (MSR_BANK_ICA + (1 << 1))

/*********************************************************************
* MSR bank - DCA
**********************************************************************/

/* MSR.DCID */
#define MSR_DCID (MSR_BANK_DCA + (1 << 0))
#define MSR_DCID_SS_SHIFT 0
#define MSR_DCID_SS 0xf
#define MSR_DCID_SL_SHIFT 4
#define MSR_DCID_SL (0xf << MSR_DCID_SL_SHIFT)
#define MSR_DCID_SW_SHIFT 8
#define MSR_DCID_SW (0xf << MSR_DCID_SW_SHIFT)
#define MSR_DCINV (MSR_BANK_DCA + (1 << 1))
#define MSR_DCFLS (MSR_BANK_DCA + (1 << 2))

/*********************************************************************
* MSR bank - DBG
**********************************************************************/

/* MSR.DBGR */
#define MSR_DBGR_NUMPORT (MSR_BANK_DBG + (1 << 0))
#define MSR_DBGR_MSGPORT (MSR_BANK_DBG + (1 << 1))
/* 64bit high-precision TSC */
#define MSR_DBGR_TSCL (MSR_BANK_DBG + (1 << 2))
#define MSR_DBGR_TSCH (MSR_BANK_DBG + (1 << 3))

/*********************************************************************
* MSR bank - IRQC
**********************************************************************/

/* MSR.IMR R/W */
#define MSR_IMR (MSR_BANK_IRQC + (1 << 0))
/* MSR.IRR R */
#define MSR_IRR (MSR_BANK_IRQC + (1 << 1))

/*********************************************************************
* MSR bank - TSC
**********************************************************************/

/* MSR.TSR R/W */
#define MSR_TSR (MSR_BANK_TSC + (1 << 0))

/* MSR.TCR R/W */
#define MSR_TCR (MSR_BANK_TSC + (1 << 1))
#define MSR_TCR_CNT_SHIFT 0
#define MSR_TCR_CNT 0x0fffffff
#define MSR_TCR_EN_SHIFT 28
#define MSR_TCR_EN (1 << MSR_TCR_EN_SHIFT)
#define MSR_TCR_I_SHIFT 29
#define MSR_TCR_I (1 << MSR_TCR_I_SHIFT)
#define MSR_TCR_P_SHIFT 30
#define MSR_TCR_P (1 << MSR_TCR_P_SHIFT)

/*********************************************************************
* MSR bank - SR
**********************************************************************/

#define MSR_SR(_no) (MSR_BANK_SR + (1<<_no))
#define MSR_SR_NUM 4
#define MSR_SR_MAX (MSR_BANK_SR + ((1<<MSR_SR_NUM)-1)) /* Address of each SR is one-hot encoding */

#endif /* OPCODES_H */
