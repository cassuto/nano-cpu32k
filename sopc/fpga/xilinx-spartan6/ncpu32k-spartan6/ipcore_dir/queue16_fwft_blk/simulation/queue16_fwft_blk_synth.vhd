--------------------------------------------------------------------------------
--
-- FIFO Generator Core Demo Testbench 
--
--------------------------------------------------------------------------------
--
-- (c) Copyright 2009 - 2010 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--------------------------------------------------------------------------------
--
-- Filename: queue16_fwft_blk_synth.vhd
--
-- Description:
--   This is the demo testbench for fifo_generator core.
--
--------------------------------------------------------------------------------
-- Library Declarations
--------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.STD_LOGIC_1164.ALL;
USE ieee.STD_LOGIC_unsigned.ALL;
USE IEEE.STD_LOGIC_arith.ALL;
USE ieee.numeric_std.ALL;
USE ieee.STD_LOGIC_misc.ALL;

LIBRARY std;
USE std.textio.ALL;

LIBRARY work;
USE work.queue16_fwft_blk_pkg.ALL;

--------------------------------------------------------------------------------
-- Entity Declaration
--------------------------------------------------------------------------------
ENTITY queue16_fwft_blk_synth IS
  GENERIC(
  	   FREEZEON_ERROR : INTEGER := 0;
	   TB_STOP_CNT    : INTEGER := 0;
	   TB_SEED        : INTEGER := 1
	 );
  PORT(
	WR_CLK     :  IN  STD_LOGIC;
	RD_CLK     :  IN  STD_LOGIC;
        RESET      :  IN  STD_LOGIC;
        SIM_DONE   :  OUT STD_LOGIC;
        STATUS     :  OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
      );
END ENTITY;

ARCHITECTURE simulation_arch OF queue16_fwft_blk_synth IS

    -- FIFO interface signal declarations
    SIGNAL wr_clk_i                       :   STD_LOGIC;
    SIGNAL rd_clk_i                       :   STD_LOGIC;
    SIGNAL wr_en                          :   STD_LOGIC;
    SIGNAL rd_en                          :   STD_LOGIC;
    SIGNAL din                            :   STD_LOGIC_VECTOR(8-1 DOWNTO 0);
    SIGNAL dout                           :   STD_LOGIC_VECTOR(8-1 DOWNTO 0);
    SIGNAL full                           :   STD_LOGIC;
    SIGNAL empty                          :   STD_LOGIC;
   -- TB Signals
    SIGNAL wr_data                        :   STD_LOGIC_VECTOR(8-1 DOWNTO 0);
    SIGNAL dout_i                         :   STD_LOGIC_VECTOR(8-1 DOWNTO 0);
    SIGNAL wr_en_i                        :   STD_LOGIC := '0';
    SIGNAL rd_en_i                        :   STD_LOGIC := '0';
    SIGNAL full_i                         :   STD_LOGIC := '0';
    SIGNAL empty_i                        :   STD_LOGIC := '0';
    SIGNAL almost_full_i                  :   STD_LOGIC := '0';
    SIGNAL almost_empty_i                 :   STD_LOGIC := '0';
    SIGNAL prc_we_i                       :   STD_LOGIC := '0';
    SIGNAL prc_re_i                       :   STD_LOGIC := '0';
    SIGNAL dout_chk_i                     :   STD_LOGIC := '0';
    SIGNAL rst_int_rd                     :   STD_LOGIC := '0';
    SIGNAL rst_int_wr                     :   STD_LOGIC := '0';
    SIGNAL rst_s_wr1                      :   STD_LOGIC := '0';
    SIGNAL rst_s_wr2                      :   STD_LOGIC := '0';
    SIGNAL rst_gen_rd                     :   STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rst_s_wr3                      :   STD_LOGIC := '0';
    SIGNAL rst_s_rd                       :   STD_LOGIC := '0';
    SIGNAL reset_en                       :   STD_LOGIC := '0';
    SIGNAL rst_async_wr1                  :   STD_LOGIC := '0'; 
    SIGNAL rst_async_wr2                  :   STD_LOGIC := '0'; 
    SIGNAL rst_async_wr3                  :   STD_LOGIC := '0'; 
    SIGNAL rst_async_rd1                  :   STD_LOGIC := '0'; 
    SIGNAL rst_async_rd2                  :   STD_LOGIC := '0'; 
    SIGNAL rst_async_rd3                  :   STD_LOGIC := '0'; 


 BEGIN  

   ---- Reset generation logic -----
   rst_int_wr          <= rst_async_wr3 OR rst_s_wr3;
   rst_int_rd          <= rst_async_rd3 OR rst_s_rd;

   --Testbench reset synchronization
   PROCESS(rd_clk_i,RESET)
   BEGIN
     IF(RESET = '1') THEN
       rst_async_rd1    <= '1';
       rst_async_rd2    <= '1';
       rst_async_rd3    <= '1';
     ELSIF(rd_clk_i'event AND rd_clk_i='1') THEN
       rst_async_rd1    <= RESET;
       rst_async_rd2    <= rst_async_rd1;
       rst_async_rd3    <= rst_async_rd2;
     END IF;
   END PROCESS;

   PROCESS(wr_clk_i,RESET)
   BEGIN
     IF(RESET = '1') THEN
       rst_async_wr1  <= '1';
       rst_async_wr2  <= '1';
       rst_async_wr3  <= '1';
     ELSIF(wr_clk_i'event AND wr_clk_i='1') THEN
       rst_async_wr1  <= RESET;
       rst_async_wr2  <= rst_async_wr1;
       rst_async_wr3  <= rst_async_wr2;
     END IF;
   END PROCESS;
   rst_s_wr3   <= '0';
   rst_s_rd    <= '0';
   ------------------
   
   ---- Clock buffers for testbench ----
  wr_clk_i <= WR_CLK;
  rd_clk_i <= RD_CLK;
   ------------------
     
    din                       <=   wr_data;
    dout_i                    <=   dout;
    wr_en                     <=   wr_en_i;
    rd_en                     <=   rd_en_i;
    full_i                    <=   full;
    empty_i                   <=   empty;

    fg_dg_nv: queue16_fwft_blk_dgen
      GENERIC MAP (
          	C_DIN_WIDTH       => 8,
		C_DOUT_WIDTH      => 8,
		TB_SEED           => TB_SEED, 
 		C_CH_TYPE         => 0	
                 )
      PORT MAP (  -- Write Port
                RESET             => rst_int_wr,
                WR_CLK            => wr_clk_i,
		PRC_WR_EN         => prc_we_i,
                FULL              => full_i,
                WR_EN             => wr_en_i,
                WR_DATA           => wr_data
	       );

   fg_dv_nv: queue16_fwft_blk_dverif
    GENERIC MAP (  
	       C_DOUT_WIDTH       => 8,
	       C_DIN_WIDTH        => 8,
	       C_USE_EMBEDDED_REG => 0,
	       TB_SEED            => TB_SEED, 
 	       C_CH_TYPE          => 0
	        )
     PORT MAP(
              RESET               => rst_int_rd,
              RD_CLK              => rd_clk_i,
	      PRC_RD_EN           => prc_re_i,
              RD_EN               => rd_en_i,
	      EMPTY               => empty_i,
	      DATA_OUT            => dout_i,
	      DOUT_CHK            => dout_chk_i
	    );

    fg_pc_nv: queue16_fwft_blk_pctrl
    GENERIC MAP ( 
              AXI_CHANNEL         => "Native",
              C_APPLICATION_TYPE  => 0,
	      C_DOUT_WIDTH        => 8,
	      C_DIN_WIDTH         => 8,
	      C_WR_PNTR_WIDTH     => 10,
    	      C_RD_PNTR_WIDTH     => 10,
 	      C_CH_TYPE           => 0,
              FREEZEON_ERROR      => FREEZEON_ERROR,
	      TB_SEED             => TB_SEED, 
              TB_STOP_CNT         => TB_STOP_CNT
	        )
     PORT MAP(
              RESET_WR            => rst_int_wr,
              RESET_RD            => rst_int_rd,
	      RESET_EN            => reset_en,
              WR_CLK              => wr_clk_i,
              RD_CLK              => rd_clk_i,
              PRC_WR_EN           => prc_we_i,
              PRC_RD_EN           => prc_re_i,
	      FULL                => full_i,
              ALMOST_FULL         => almost_full_i,
              ALMOST_EMPTY        => almost_empty_i,
	      DOUT_CHK            => dout_chk_i,
	      EMPTY               => empty_i,
	      DATA_IN             => wr_data,
	      DATA_OUT            => dout,
	      SIM_DONE            => SIM_DONE,
	      STATUS              => STATUS
	    );





  queue16_fwft_blk_inst : queue16_fwft_blk_exdes 
    PORT MAP (
           WR_CLK                    => wr_clk_i,
           RD_CLK                    => rd_clk_i,
           WR_EN 		     => wr_en,
           RD_EN                     => rd_en,
           DIN                       => din,
           DOUT                      => dout,
           FULL                      => full,
           EMPTY                     => empty);

END ARCHITECTURE;
