library verilog;
use verilog.vl_types.all;
entity ncpu32k_cell_dpram_sclk is
    generic(
        ADDR_WIDTH      : integer := 32;
        DATA_WIDTH      : integer := 32;
        CLEAR_ON_INIT   : integer := 1;
        SYNC_READ       : integer := 1;
        ENABLE_BYPASS   : integer := 1
    );
    port(
        clk_i           : in     vl_logic;
        rst_n_i         : in     vl_logic;
        raddr           : in     vl_logic_vector;
        re              : in     vl_logic;
        waddr           : in     vl_logic_vector;
        we              : in     vl_logic;
        din             : in     vl_logic_vector;
        dout            : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ADDR_WIDTH : constant is 1;
    attribute mti_svvh_generic_type of DATA_WIDTH : constant is 1;
    attribute mti_svvh_generic_type of CLEAR_ON_INIT : constant is 1;
    attribute mti_svvh_generic_type of SYNC_READ : constant is 1;
    attribute mti_svvh_generic_type of ENABLE_BYPASS : constant is 1;
end ncpu32k_cell_dpram_sclk;
