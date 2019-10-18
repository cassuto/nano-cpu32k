library verilog;
use verilog.vl_types.all;
entity ncpu32k_core is
    port(
        clk_i           : in     vl_logic;
        rst_n_i         : in     vl_logic;
        d_i             : in     vl_logic_vector(31 downto 0);
        insn_i          : in     vl_logic_vector(31 downto 0);
        insn_ready_i    : in     vl_logic;
        dbus_rd_ready_i : in     vl_logic;
        dbus_we_done_i  : in     vl_logic;
        d_o             : out    vl_logic_vector(31 downto 0);
        addr_o          : out    vl_logic_vector(31 downto 0);
        dbus_rd_o       : out    vl_logic;
        dbus_we_o       : out    vl_logic;
        iaddr_o         : out    vl_logic_vector(31 downto 0);
        ibus_rd_o       : out    vl_logic
    );
end ncpu32k_core;
