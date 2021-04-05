/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
/*                                                                         */
/*  Copyright (C) 2019-2021 cassuto <psc-system@outlook.com>, China.       */
/*  This project is free edition; you can redistribute it and/or           */
/*  modify it under the terms of the GNU Lesser General Public             */
/*  License(GPL) as published by the Free Software Foundation; either      */
/*  version 2.1 of the License, or (at your option) any later version.     */
/*                                                                         */
/*  This project is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      */
/*  Lesser General Public License for more details.                        */
/***************************************************************************/

`ifndef _NCPU32K_CONFIG_H
`define _NCPU32K_CONFIG_H

`timescale 1ns / 1ps

/////////////////////////////////////////////////////////////////////////////
// Platform definitions
/////////////////////////////////////////////////////////////////////////////

`ifndef IN_SIM
`define PLATFORM_XILINX_XC6
`endif

// For FPGA, define this macro to disable `RST_N` port of DFF,
// which reduces routing overheads. However, once when the system is powered on,
// it cannot be reset again!
`define NCPU_NO_RST

/////////////////////////////////////////////////////////////////////////////
// Configure Asertions
/////////////////////////////////////////////////////////////////////////////

// Check the uncertain state (X)
// `define NCPU_CHECK_X

// Assertions are automatically ignored during synthesis.
// If you want to speed up the simulation, comment this macro out.
`define NCPU_ENABLE_ASSERT

/////////////////////////////////////////////////////////////////////////////
// Design Constants
/////////////////////////////////////////////////////////////////////////////


// Data Operand Bitwidth
`define NCPU_DW 32
// Address Bus Bitwidth (<= DW)
`define NCPU_AW 32

// Single instruction Bitwidth
`define NCPU_IW 32

// Regfile address Bitwidth
`define NCPU_REG_AW 5

// Number of IRQ lines
`define NCPU_NIRQ 32


/////////////////////////////////////////////////////////////////////////////
// MSR
/////////////////////////////////////////////////////////////////////////////

// PSR register Bitwidth
`define NCPU_PSR_DW 10
// TLB register address Bitwidth
`define NCPU_TLB_AW 7

`define NCPU_MSR_BANK_OFF_AW 9
`define NCPU_MSR_BANK_AW (14-9) // 14 is the bitwidth of imm14

// MSR Banks
`define NCPU_MSR_BANK_PS	0
`define NCPU_MSR_BANK_IMM	1
`define NCPU_MSR_BANK_DMM	2
`define NCPU_MSR_BANK_ICA	3
`define NCPU_MSR_BANK_DCA	4
`define NCPU_MSR_BANK_DBG	5
`define NCPU_MSR_BANK_IRQC	6
`define NCPU_MSR_BANK_TSC	7

//
// PS (One-hot encoding)
//

// PS - PSR
`define NCPU_MSR_PSR	0
// PS - CPUID
`define NCPU_MSR_CPUID 1
// PS - EPSR
`define NCPU_MSR_EPSR 2
// PS - EPC
`define NCPU_MSR_EPC	3
// PS - ELSA
`define NCPU_MSR_ELSA 4
// PS.COREID
`define NCPU_MSR_COREID 5

//
// IMM
//

// IMM TLB (8th bit = TLB sel)
`define NCPU_MSR_IMM_TLBSEL 8
// TLBH (7th bit = TLBH sel)
`define NCPU_MSR_IMM_TLBH_SEL 7

//
// DMM
//

// DMM TLB (8th bit = TLB sel)
`define NCPU_MSR_DMM_TLBSEL 8
// TLBH (7th bit = TLBH sel)
`define NCPU_MSR_DMM_TLBH_SEL 7

//
// IRQC (One-hot encoding)
//
`define NCPU_MSR_IRQC_IMR 0
`define NCPU_MSR_IRQC_IRR 1

//
// TSC
//
`define NCPU_MSR_TSC_TSR 0
`define NCPU_MSR_TSC_TCR 1

`define NCPU_TSC_CNT_DW 28
`define NCPU_MSR_TSC_TCR_EN 28
`define NCPU_MSR_TSC_TCR_I 29
`define NCPU_MSR_TSC_TCR_P 30
`define NCPU_MSR_TSC_TCR_RB1 31

/////////////////////////////////////////////////////////////////////////////
// Exception Vector Table (default values!)
/////////////////////////////////////////////////////////////////////////////
`define NCPU_ERST_VECTOR 32'h0
`define NCPU_EINSN_VECTOR 32'h4
`define NCPU_EIRQ_VECTOR 32'h8
`define NCPU_ESYSCALL_VECTOR 32'hc
`define NCPU_EBUS_VECTOR 32'h10
`define NCPU_EIPF_VECTOR 32'h14
`define NCPU_EDPF_VECTOR 32'h18
`define NCPU_EITM_VECTOR 32'h1c
`define NCPU_EDTM_VECTOR 32'h20
`define NCPU_EALIGN_VECTOR 32'h24

/////////////////////////////////////////////////////////////////////////////
// ISA GROUP - BASE
/////////////////////////////////////////////////////////////////////////////
`define NCPU_OP_AND 7'h0
`define NCPU_OP_AND_I 7'h1
`define NCPU_OP_OR 7'h2
`define NCPU_OP_OR_I 7'h3
`define NCPU_OP_XOR 7'h4
`define NCPU_OP_XOR_I 7'h5
`define NCPU_OP_LSL 7'h6
`define NCPU_OP_LSL_I 7'h7
`define NCPU_OP_LSR 7'h8
`define NCPU_OP_LSR_I 7'h9
`define NCPU_OP_ADD 7'ha
`define NCPU_OP_ADD_I 7'hb
`define NCPU_OP_SUB 7'hc
`define NCPU_OP_JMP 7'hd
`define NCPU_OP_JMP_I 7'he
`define NCPU_OP_JMP_LNK_I 7'hf
`define NCPU_OP_BEQ 7'h10
`define NCPU_OP_BNE 7'h11
`define NCPU_OP_BLT 7'h12
`define NCPU_OP_BLTU 7'h13
`define NCPU_OP_BGE 7'h14
`define NCPU_OP_BGEU 7'h15

`define NCPU_OP_LDWU 7'h17
`define NCPU_OP_STW 7'h18
`define NCPU_OP_LDHU 7'h19
`define NCPU_OP_LDH 7'h1a
`define NCPU_OP_STH 7'h1b
`define NCPU_OP_LDBU 7'h1c
`define NCPU_OP_LDB 7'h1d
`define NCPU_OP_STB 7'h1e

`define NCPU_OP_MBARR 7'h20
`define NCPU_OP_SYSCALL 7'h21
`define NCPU_OP_RET 7'h22
`define NCPU_OP_WMSR 7'h23
`define NCPU_OP_RMSR 7'h24


/////////////////////////////////////////////////////////////////////////////
// ISA GROUP - VIRT:
/////////////////////////////////////////////////////////////////////////////
`define NCPU_OP_ASR 7'h30
`define NCPU_OP_ASR_I 7'h31
`define NCPU_OP_MUL 7'h32
`define NCPU_OP_DIV 7'h33
`define NCPU_OP_DIVU 7'h34
`define NCPU_OP_MOD 7'h35
`define NCPU_OP_MODU 7'h36
`define NCPU_OP_MHI 7'h37

`define NCPU_OP_FADDS 7'h40
`define NCPU_OP_FSUBS 7'h41
`define NCPU_OP_FMULS 7'h42
`define NCPU_OP_FDIVS 7'h43
`define NCPU_OP_FCMPS 7'h44
`define NCPU_OP_FITFS 7'h45
`define NCPU_OP_FFTIS 7'h46

/////////////////////////////////////////////////////////////////////////////
// Internal OPC
/////////////////////////////////////////////////////////////////////////////

// 1-clk-latency operations
`define NCPU_ALU_IOPW 17 // One-hot Insn Opocde Bitwidth
`define NCPU_ALU_ADD 0
`define NCPU_ALU_SUB 1
`define NCPU_ALU_MHI 2
`define NCPU_ALU_AND 3
`define NCPU_ALU_OR 4
`define NCPU_ALU_XOR 5
`define NCPU_ALU_LSL 6
`define NCPU_ALU_LSR 7
`define NCPU_ALU_ASR 8
`define NCPU_ALU_BEQ 9
`define NCPU_ALU_BNE 10
`define NCPU_ALU_BLT 11
`define NCPU_ALU_BLTU 12
`define NCPU_ALU_BGE 13
`define NCPU_ALU_BGEU 14
`define NCPU_ALU_JMPREG 15
`define NCPU_ALU_JMPREL 16

// Multi-clks-latency operations
`define NCPU_LPU_IOPW 5 // One-hot Insn Opocde Bitwidth
`define NCPU_LPU_MUL 0
`define NCPU_LPU_DIV 1
`define NCPU_LPU_DIVU 2
`define NCPU_LPU_MOD 3
`define NCPU_LPU_MODU 4

// FPU
`define NCPU_FPU_IOPW 1

// EPU (Exception and Extended Processor Unit)
`define NCPU_EPU_IOPW 8
`define NCPU_EPU_WMSR 0
`define NCPU_EPU_RMSR 1
`define NCPU_EPU_ESYSCALL 2
`define NCPU_EPU_ERET 3
`define NCPU_EPU_EITM 4
`define NCPU_EPU_EIPF 5
`define NCPU_EPU_EIRQ 6
`define NCPU_EPU_EINSN (`NCPU_EPU_IOPW-1)

`define NCPU_REGNO_LNK 1 // the only one machine-dependent register

/////////////////////////////////////////////////////////////////////////////
// uOP
/////////////////////////////////////////////////////////////////////////////

`define NCPU_EPU_UOPW 4
`define NCPU_ALU_UOPW_OPC 5
`define NCPU_ALU_UOPW (`NCPU_ALU_UOPW_OPC + 15) /* uOP with rel15 operand */
`define NCPU_LPU_UOPW 3
`define NCPU_AGU_UOPW 7
`define NCPU_FPU_UOPW 1

`endif // _NCPU32K_CONFIG_H
