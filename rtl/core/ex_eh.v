/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

`include "ncpu64k_config.vh"

module ex_eh
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_ESYSCALL_VECTOR = 0,
   parameter                           CONFIG_EITM_VECTOR = 0,
   parameter                           CONFIG_EIPF_VECTOR = 0,
   parameter                           CONFIG_EIRQ_VECTOR = 0,
   parameter                           CONFIG_EINSN_VECTOR = 0
)
(
   input [`NCPU_FE_W-1:0]              ex_fe,
   input [CONFIG_AW-1:0]               msr_evect,
   output                              exc_flush,
   output [`PC_W-1:0]                  exc_flush_tgt,
);

   assign exc_flush = (
      ex_fe[`NCPU_EPU_ESYSCALL] |
      ex_fe[`NCPU_EPU_ERET] |
      ex_fe[`NCPU_EPU_EITM] |
      ex_fe[`NCPU_EPU_EIPF] |
      ex_fe[`NCPU_EPU_EIRQ] |
      ex_fe[`NCPU_EPU_EINSN]
   );

   assign exc_flush_tgt = 
      ({`PC_W{ex_fe[`NCPU_EPU_ESYSCALL]}} & {msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_ESYSCALL_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
      ({`PC_W{ex_fe[`NCPU_EPU_ERET]}} & msr_epc[`NCPU_P_INSN_LEN +: `PC_W]) |
      ({`PC_W{ex_fe[`NCPU_EPU_EITM]}} & {msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EITM_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
      ({`PC_W{ex_fe[`NCPU_EPU_EIPF]}} & {msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EIPF_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
      ({`PC_W{ex_fe[`NCPU_EPU_EIRQ]}} & {msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EIRQ_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
      ({`PC_W{ex_fe[`NCPU_EPU_EINSN]}} & {msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EINSN_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]});

endmodule

