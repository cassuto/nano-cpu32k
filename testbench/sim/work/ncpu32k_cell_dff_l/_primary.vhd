library verilog;
use verilog.vl_types.all;
entity ncpu32k_cell_dff_l is
    generic(
        DW              : integer := 1
    );
    port(
        CLK             : in     vl_logic;
        LOAD            : in     vl_logic;
        D               : in     vl_logic_vector;
        Q               : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of DW : constant is 1;
end ncpu32k_cell_dff_l;
