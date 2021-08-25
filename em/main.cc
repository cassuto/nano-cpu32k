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
#include "peripheral/device-tree.hh"
#include <string>
#include <getopt.h>

static const struct option long_options[] = {
    {"no-RTL", no_argument, NULL, 0},                         /* 0 */
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
    {"bin-load-addr", required_argument, NULL, 'a'},
    {"bin-pathname", required_argument, NULL, 'b'},
    {"reset-vector", required_argument, NULL, 'r'},
    {"help", no_argument, NULL, 'h'},
    {0, 0, NULL, 0}};

class Args
{
public:
    Args()
    {
        /* Default settings */
        no_rtl = false;
        reset_vector = 0x0;
        ram_size = 32 * 1024 * 1024;
        dmmu_tlb_count = 128;
        immu_tlb_count = 128;
        dmmu_enable_uncached_seg = true;
        icache_p_ways = 2;
        icache_p_sets = 6;
        icache_p_line = 6;
        dcache_p_ways = 2;
        dcache_p_sets = 6;
        dcache_p_line = 6;
        mmio_phy_base = 0x80000000;
        IRQ_TSC = 0;
        bin_load_addr = 0x0;
        device_clk_div = 100;
    }

    bool no_rtl;
    std::string bin_pathname;
    phy_addr_t reset_vector;
    int ram_size;
    int dmmu_tlb_count, immu_tlb_count;
    bool dmmu_enable_uncached_seg;
    int icache_p_ways, icache_p_sets, icache_p_line;
    int dcache_p_ways, dcache_p_sets, dcache_p_line;
    phy_addr_t mmio_phy_base;
    int IRQ_TSC;
    phy_addr_t bin_load_addr;
    uint64_t device_clk_div;
};

static const char *optstirng = "-b:a:r:";
static Args args;
static CPU *emu_CPU;
static DeviceTree *emu_dev;
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
                args.no_rtl = true;
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
                if (strcmp(optarg, "true") && strcmp(optarg, "false"))
                {
                    fprintf(stderr, "Invalid value for --dmmu-enable-uncached-seg\n");
                    return usage(argv[0]);
                }
                args.dmmu_enable_uncached_seg = (strcmp(optarg, "true") == 0);
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
            args.reset_vector = atoll(optarg);
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
    if (parse_args(argc, argv))
        return 1;

    emu_CPU = new CPU(args.dmmu_tlb_count, args.immu_tlb_count,
                      args.dmmu_enable_uncached_seg,
                      args.icache_p_ways, args.icache_p_sets, args.icache_p_line,
                      args.dcache_p_ways, args.dcache_p_sets, args.dcache_p_line,
                      args.ram_size, args.mmio_phy_base,
                      args.IRQ_TSC);

    FILE *bin_fp = fopen(args.bin_pathname.c_str(), "rb");
    if (!bin_fp)
    {
        fprintf(stderr, "Failed to open file '%s'\n", args.bin_pathname.c_str());
    }
    emu_CPU->memory()->load_address_fp(bin_fp, args.bin_load_addr);

    emu_dev = new DeviceTree(emu_CPU, emu_CPU->memory(), args.mmio_phy_base);

    emu_CPU->reset(args.reset_vector);

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

    return 0;
}

void panic(int code)
{
    fprintf(stderr, "[ERR] Panic. code = %d\n", code);
    exit(code);
}
