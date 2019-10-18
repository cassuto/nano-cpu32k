library verilog;
use verilog.vl_types.all;
entity ncpu32k_regfile is
    port(
        clk_i           : in     vl_logic;
        rst_n_i         : in     vl_logic;
        rs1_addr_i      : in     vl_logic_vector(4 downto 0);
        rs2_addr_i      : in     vl_logic_vector(4 downto 0);
        rs1_re_i        : in     vl_logic;
        rs2_re_i        : in     vl_logic;
        rd_addr_i       : in     vl_logic_vector(4 downto 0);
        rd_i            : in     vl_logic_vector(31 downto 0);
        rd_we_i         : in     vl_logic;
        rs1_o           : out    vl_logic_vector(31 downto 0);
        rs2_o           : out    vl_logic_vector(31 downto 0)
    );
end ncpu32k_regfile;
