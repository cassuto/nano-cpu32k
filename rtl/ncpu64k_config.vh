`ifndef NCPU64K_CONFIG_H_
`define NCPU64K_CONFIG_H_

/* Asynchronous/synchronous reset */
//`define NCPU_RST_ASYNC
`undef NCPU_RST_ASYNC

/* Reset Polarity */
`define NCPU_RST_POS_POLARITY
//`undef NCPU_RST_POS_POLARITY

/* Assert in simulation */
`define NCPU_ENABLE_ASSERT
//`undef NCPU_ENABLE_ASSERT

/* Check X state in simulation */
//`define NCPU_CHECK_X
`undef NCPU_CHECK_X

/* Length of a insn */
`define NCPU_INSN_LEN 4

/* Use technology library */
//`define NCPU_USE_TECHLIB
`undef NCPU_USE_TECHLIB

`endif
