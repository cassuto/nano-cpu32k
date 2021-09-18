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

#include "cpu.hh"
#include "memory.hh"
#include "emu.hh"
#include "dpi-c.hh"
#include "symtable.hh"
#include "peripheral/device-tree.hh"
#include <string>
#include <getopt.h>

static const struct option long_options[] = {
    {"mode", required_argument, NULL, 0},                     /* 0 */
    {"ram-size", required_argument, NULL, 0},                 /* 1 */
    {"dmmu-tlb-count", required_argument, NULL, 0},           /* 2 */
    {"immu-tlb-count", required_argument, NULL, 0},           /* 3 */
    {"dmmu-enable-uncached-seg", required_argument, NULL, 0}, /* 4 */
    {"icache-p-ways", required_argument, NULL, 0},            /* 5 */
    {"icache-p-sets", required_argument, NULL, 0},            /* 6 */
    {"icache-p-line", required_argument, NULL, 0},            /* 7 */
    {"dcache-p-ways", required_argument, NULL, 0},            /* 8 */
    {"dcache-p-sets", required_argument, NULL, 0},            /* 9 */
    {"dcache-p-line", required_argument, NULL, 0},            /* 10 */
    {"mmio-phy-base", required_argument, NULL, 0},            /* 11 */
    {"irq-tsc", required_argument, NULL, 0},                  /* 12 */
    {"device-clk-div", required_argument, NULL, 0},           /* 13 */
    {"enable-icache", required_argument, NULL, 0},            /* 14 */
    {"enable-dcache", required_argument, NULL, 0},            /* 15 */
    {"wave-begin", required_argument, NULL, 0},               /* 16 */
    {"wave-end", required_argument, NULL, 0},                 /* 17 */
    {"commit-timeout-max", required_argument, NULL, 0},       /* 18 */
    {"immu-enable-uncached-seg", required_argument, NULL, 0}, /* 19 */
    {"symbol-file", required_argument, NULL, 0},              /* 20 */
    {"bin-load-addr", required_argument, NULL, 'a'},
    {"bin-pathname", required_argument, NULL, 'b'},
    {"reset-vector", required_argument, NULL, 'r'},
    {"dump-wave", required_argument, NULL, 'd'},
    {"help", no_argument, NULL, 'h'},
    {0, 0, NULL, 0}};

enum Mode
{
    ModeStandalone = 0,
    ModeSimulateOnly,
    ModeDifftest
};

class Args
{
public:
    Args()
    {
        /* Default settings */
        mode = ModeDifftest;

        vect_ERST = 0x80000000;
        vect_EINSN = 0x80000004;
        vect_EIRQ = 0x80000008;
        vect_ESYSCALL = 0x8000000c;
        vect_EIPF = 0x80000014;
        vect_EDPF = 0x80000018;
        vect_EITM = 0x8000001c;
        vect_EDTM = 0x80000020;
        vect_EALGIN = 0x80000024;
        vect_EINT = 0x80000028;

        ram_size = 32 * 1024 * 1024;
        dmmu_tlb_count = 128;
        immu_tlb_count = 128;
        dmmu_enable_uncached_seg = true;
        immu_enable_uncached_seg = true;
        enable_icache = true;
        enable_dcache = true;
        icache_p_ways = 1;
        icache_p_sets = 4;
        icache_p_line = 6;
        dcache_p_ways = 1;
        dcache_p_sets = 4;
        dcache_p_line = 6;
        dram_phy_base = 0x80000000;
        mmio_phy_base = 0x00000000;
        mmio_phy_end_addr = 0x7fffffff;
        IRQ_TSC = 0;
        bin_load_addr = dram_phy_base;
        device_clk_div = 100;
        vcdfile = "dump.vcd";
        wave_begin = 0;
        wave_end = 10000;
        commit_timeout_max = 100000;
        symbol_file = "";
    }

    Mode mode;
    std::string bin_pathname;
    phy_addr_t vect_ERST;
    phy_addr_t vect_EINSN;
    phy_addr_t vect_EIRQ;
    phy_addr_t vect_ESYSCALL;
    phy_addr_t vect_EIPF;
    phy_addr_t vect_EDPF;
    phy_addr_t vect_EITM;
    phy_addr_t vect_EDTM;
    phy_addr_t vect_EALGIN;
    phy_addr_t vect_EINT;
    int ram_size;
    int dmmu_tlb_count, immu_tlb_count;
    bool dmmu_enable_uncached_seg;
    bool immu_enable_uncached_seg;
    bool enable_icache, enable_dcache;
    int icache_p_ways, icache_p_sets, icache_p_line;
    int dcache_p_ways, dcache_p_sets, dcache_p_line;
    phy_addr_t dram_phy_base;
    phy_addr_t mmio_phy_base, mmio_phy_end_addr;
    int IRQ_TSC;
    phy_addr_t bin_load_addr;
    uint64_t device_clk_div;
    std::string vcdfile;
    uint64_t wave_begin;
    uint64_t wave_end;
    uint64_t commit_timeout_max;
    std::string symbol_file;
};

static const char *optstirng = "-b:a:r:d:";
static Args args;
/*static*/ CPU *emu_CPU;
static DeviceTree *emu_dev;
/*static*/ Emu *emu;
static Memory *rtl_memory;
static uint64_t device_clk;

static int
usage(const char *exec)
{
    fprintf(stderr, "Usage\n%s %s\n", exec, optstirng);
    for (unsigned i = 0; long_options[i].name; i++)
    {
        printf("\t--%s", long_options[i].name);
        printf(long_options[i].has_arg ? "[=val]\n" : "\n");
    }
    printf("\n");
    return 1;
}

static bool
parse_bool(const char *optarg, const char *paramname)
{
    if (strcmp(optarg, "true") && strcmp(optarg, "false"))
    {
        fprintf(stderr, "Invalid value for --%s\n", paramname);
        exit(1);
    }
    return (strcmp(optarg, "true") == 0);
}

static Mode
parse_mode(const char *optarg)
{
    if (strcmp(optarg, "standalone") == 0)
        return ModeStandalone;
    else if (strcmp(optarg, "simulate-only") == 0)
        return ModeSimulateOnly;
    else if (strcmp(optarg, "difftest") == 0)
        return ModeDifftest;
    else
    {
        fprintf(stderr, "Invalid value for --mode\n");
        exit(1);
    }
}

static int
parse_args(int argc, char **argv)
{
    int opt, long_index;
    while ((opt = getopt_long(argc, const_cast<char *const *>(argv),
                              optstirng, long_options, &long_index)) != -1)
    {
        switch (opt)
        {
        case 0:
            switch (long_index)
            {
            case 0:
                args.mode = parse_mode(optarg);
                break;
            case 1:
                args.ram_size = atoi(optarg);
                break;
            case 2:
                args.dmmu_tlb_count = atoi(optarg);
                break;
            case 3:
                args.immu_tlb_count = atoi(optarg);
                break;
            case 4:
                args.dmmu_enable_uncached_seg = parse_bool(optarg, long_options[4].name);
                break;
            case 5:
                args.icache_p_ways = atoi(optarg);
                break;
            case 6:
                args.icache_p_sets = atoi(optarg);
                break;
            case 7:
                args.icache_p_line = atoi(optarg);
                break;
            case 8:
                args.dcache_p_ways = atoi(optarg);
                break;
            case 9:
                args.dcache_p_sets = atoi(optarg);
                break;
            case 10:
                args.dcache_p_line = atoi(optarg);
                break;
            case 11:
                args.mmio_phy_base = atoi(optarg);
                break;
            case 12:
                args.IRQ_TSC = atoi(optarg);
                break;
            case 13:
                args.device_clk_div = atol(optarg);
                break;
            case 14:
                args.enable_icache = parse_bool(optarg, long_options[14].name);
                break;
            case 15:
                args.enable_dcache = parse_bool(optarg, long_options[15].name);
                break;
            case 16:
                args.wave_begin = atol(optarg);
                break;
            case 17:
                args.wave_end = atol(optarg);
                break;
            case 18:
                args.commit_timeout_max = atol(optarg);
                break;
            case 19:
                args.immu_enable_uncached_seg = parse_bool(optarg, long_options[4].name);
                break;
            case 20:
                args.symbol_file = optarg;
                break;
            default:
                return usage(argv[0]);
            }
            break;

        case 'b':
            args.bin_pathname = optarg;
            break;
        case 'a':
            args.bin_load_addr = atoi(optarg);
            break;
        case 'r':
            args.vect_ERST = atoll(optarg);
            break;
        case 'd':
            args.vcdfile = optarg;
            break;
        default:
            return usage(argv[0]);
        }
    }

    if (args.bin_pathname.empty())
    {
        fprintf(stderr, "You must specify a filename for binary image\n");
        return usage(argv[0]);
    }
    return 0;
}

int main(int argc, char *argv[])
{
    int retcode = 0;
    if (parse_args(argc, argv))
        return 1;

    emu_CPU = new CPU(args.dmmu_tlb_count, args.immu_tlb_count,
                      args.dmmu_enable_uncached_seg,
                      args.immu_enable_uncached_seg,
                      args.enable_icache, args.enable_dcache,
                      args.icache_p_ways, args.icache_p_sets, args.icache_p_line,
                      args.dcache_p_ways, args.dcache_p_sets, args.dcache_p_line,
                      args.ram_size, args.dram_phy_base, args.mmio_phy_base, args.mmio_phy_end_addr,
                      args.IRQ_TSC,
                      args.vect_EINSN,
                      args.vect_EIRQ,
                      args.vect_ESYSCALL,
                      args.vect_EIPF,
                      args.vect_EDPF,
                      args.vect_EITM,
                      args.vect_EDTM,
                      args.vect_EALGIN,
                      args.vect_EINT);

    FILE *bin_fp = fopen(args.bin_pathname.c_str(), "rb");
    if (!bin_fp)
    {
        fprintf(stderr, "Failed to open file '%s'\n", args.bin_pathname.c_str());
    }
    if (emu_CPU->memory()->load_address_fp(bin_fp, args.bin_load_addr))
    {
        return 1;
    }

    if (!args.symbol_file.empty() && emu_CPU->get_symtable()->load(args.symbol_file.c_str()))
    {
        fprintf(stderr, "Failed to open symbol file '%s'\n", args.symbol_file.c_str());
        return 1;
    }

    emu_dev = new DeviceTree(emu_CPU, emu_CPU->memory(), args.mmio_phy_base);

    emu_CPU->reset(args.vect_ERST);

    switch (args.mode)
    {
    case ModeStandalone:
    {

        for (;;)
        {
            /* step device */
            if (++device_clk == args.device_clk_div)
            {
                device_clk = 0;
                emu_dev->step();
            }
            emu_CPU->run_step();
        }
    }
    break;

    case ModeDifftest:
    {
        /* Configure the reference CPU */
        emu_CPU->init_msr(false);

        /* RTL simulation uses its independent memory and mmio space */
        rtl_memory = new Memory(nullptr, args.ram_size, args.dram_phy_base, args.mmio_phy_base, args.mmio_phy_end_addr);
        if (rtl_memory->load_address_fp(bin_fp, args.bin_load_addr))
        {
            return 1;
        }

        emu = new Emu(args.vcdfile.c_str(), args.wave_begin, args.wave_end, emu_CPU, rtl_memory);
        enable_difftest(emu_CPU, emu, args.commit_timeout_max);
        for (;;)
        {
            if (emu->clk())
            {
                retcode = -1;
                break;
            }
        }
        emu->finish();
        break;
    }

    case ModeSimulateOnly:
    {
        emu = new Emu(args.vcdfile.c_str(), args.wave_begin, args.wave_end, emu_CPU, emu_CPU->memory());
        printf("\n");
        uint64_t cycle, last_cycle = 0;
        for (uint64_t i = 0; /*i < 1000*/; i++)
        {
            if (emu->clk())
            {
                retcode = -1;
                break;
            }
            cycle = emu->get_cycle();
            if (cycle - last_cycle >= 10000UL)
            {
                last_cycle = cycle;
                printf("\r[%lu]", cycle);
            }
        }
        printf("\n");
        emu->finish();
        break;
    }
    }
    fprintf(stderr, "Normally exit with code = %d\n", retcode);
    return 0;
}

void panic(int code)
{
    fprintf(stderr, "[ERR] Panic. code = %d\n", code);
    exit(code);
}
