/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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

// Tips: After editing this configuration, you may need to recompile the entire
// design, depending on whether your compiler can detect header file dependencies.

//
// Macros defined by compiler environment:
//
//    SYNTHESIS   (Indicates whether we are in synthesis flow)
//    IN_SIM      (Indicates whether we are in simulation flow)
//    IN_LINT     (Indicates whether we are in code lint flow)
//
// If your compiler doesn't support above macros, please add them manually
// according to your work flow.
//

// In lint mode, enable all other modes to ensure we cover all the codes
// (expect features you disabled in the configutation)
`ifdef IN_LINT
   `ifndef SYNTHESIS
      `define SYNTHESIS
   `endif
   `ifndef IN_SIM
      `define IN_SIM
   `endif
`endif

/////////////////////////////////////////////////////////////////////////////
// Platform definitions
/////////////////////////////////////////////////////////////////////////////

`ifndef IN_SIM
`define PLATFORM_XILINX_XC6
`endif

// Stages of clock domain cross converter
`define NCPU_CDC_STAGES 2

// For FPGA, you could define this macro to disable `RST_N` port of DFF,
// which reduces routing overheads. However, once when the system is powered on,
// it cannot be reset again!
`define NCPU_NO_RST

/////////////////////////////////////////////////////////////////////////////
// Configure Simulation Checks
/////////////////////////////////////////////////////////////////////////////
`ifdef IN_SIM

// Check the uncertain state (X)
`undef NCPU_CHECK_X

// Assertions are automatically ignored during synthesis.
// If you want to speed up the simulation, comment this macro out.
`define NCPU_ENABLE_ASSERT

// Tracer for simulation verification
`define NCPU_ENABLE_TRACER

// Message port (Currently only for simulation verification)
`define NCPU_ENABLE_MSGPORT

`endif

/////////////////////////////////////////////////////////////////////////////
// Design Constants
/////////////////////////////////////////////////////////////////////////////


// Data Operand Bitwidth
`define NCPU_DW 32
`define NCPU_DW_BYTES_LOG2 2
// Address Bus Bitwidth (<= DW)
`define NCPU_AW 32

// Single Instruction Bitwidth
`define NCPU_IW 32

// Instruction Bus Bitwidth
`define NCPU_IBW 64
`define NCPU_IBW_BYTES_LOG2 3

// Logical Regfile Address Bitwidth
`define NCPU_REG_AW 5

// Number of IRQ lines
`define NCPU_NIRQ 32

// Width of WMSR we signals
`ifdef NCPU_ENABLE_MSGPORT
`define NCPU_WMSR_WE_DW (16+`NCPU_TLB_AW)
`else
`define NCPU_WMSR_WE_DW (14+`NCPU_TLB_AW)
`endif

/////////////////////////////////////////////////////////////////////////////
// MSR
/////////////////////////////////////////////////////////////////////////////

// PSR register bitwidth
`define NCPU_PSR_DW 10
// TLB register address bitwidth
`define NCPU_TLB_AW 7

`define NCPU_MSR_BANK_OFF_AW 9
`define NCPU_MSR_BANK_AW (14-9) // 14 is the bitwidth of imm14

// MSR Banks
`define NCPU_MSR_BANK_PS	0
`define NCPU_MSR_BANK_IMM	1
`define NCPU_MSR_BANK_DMM	2
`define NCPU_MSR_BANK_IC	3
`define NCPU_MSR_BANK_DC	4
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
// IC (ICache)
//

// IC - ID
`define NCPU_MSR_IC_ID 0
// IC - INV
`define NCPU_MSR_IC_INV 1

//
// DC (ICache)
//

// DC - ID
`define NCPU_MSR_DC_ID 0
// DC - INV
`define NCPU_MSR_DC_INV 1
// DC - FLS
`define NCPU_MSR_DC_FLS 2

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
`define NCPU_OP_BGT 7'h12
`define NCPU_OP_BGTU 7'h13
`define NCPU_OP_BLE 7'h14
`define NCPU_OP_BLEU 7'h15

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
`define NCPU_ALU_IOPW 9 // One-hot Insn Opocde Bitwidth
`define NCPU_ALU_ADD 0
`define NCPU_ALU_SUB 1
`define NCPU_ALU_MHI 2
`define NCPU_ALU_AND 3
`define NCPU_ALU_OR 4
`define NCPU_ALU_XOR 5
`define NCPU_ALU_LSL 6
`define NCPU_ALU_LSR 7
`define NCPU_ALU_ASR 8

// Branch operations
`define NCPU_BRU_IOPW 8
`define NCPU_BRU_BEQ 0
`define NCPU_BRU_BNE 1
`define NCPU_BRU_BGT 2
`define NCPU_BRU_BGTU 3
`define NCPU_BRU_BLE 4
`define NCPU_BRU_BLEU 5
`define NCPU_BRU_JMPREG 6
`define NCPU_BRU_JMPREL 7

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

/////////////////////////////////////////////////////////////////////////////
// FUID for optag
/////////////////////////////////////////////////////////////////////////////

`define NCPU_FUIDW 2
`define NCPU_FUID_FREE 2'b00
`define NCPU_FUID_ALU 2'b01
`define NCPU_FUID_LPU 2'b10
`define NCPU_FUID_AGU 2'b11

/////////////////////////////////////////////////////////////////////////////
// EXC tag in ROB
/////////////////////////////////////////////////////////////////////////////

`define NCPU_EXC_TAGW 3
`define NCPU_EXC_TAG_NONE

// Work around for ISE initial parameter bug
`ifndef IN_LINT
   `ifdef PLATFORM_XILINX_XC6
      `define PARAM_NOT_SPECIFIED = -1
   `else
      `define PARAM_NOT_SPECIFIED
   `endif
`else
   `define PARAM_NOT_SPECIFIED
`endif

`endif // _NCPU32K_CONFIG_H
