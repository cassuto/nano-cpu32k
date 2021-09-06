#include <iostream>
#include "./../ext/headers/args.hxx"
#include "cpu.h"
#include "cosimulation.h"
#include<time.h>
using namespace dramsim3;

// test co-simulation framework like StreamCPU
int cosim_main() {
    std::cout << "Testing DRAMsim3 co-simulation mode." << std::endl;

    uint64_t cpu_clock;
    CoDRAMsim3 *dram = new ComplexCoDRAMsim3("configs/XiangShan.ini", "runs");

    bool inserted_a_ = false;
    bool inserted_b_ = false;
    bool inserted_c_ = false;
    uint64_t addr_a_, addr_b_, addr_c_, offset_ = 0;
    uint64_t array_size_ = 0x100;
    clock_t start, end;
    start = clock();
    for (cpu_clock = 0; cpu_clock < 10000000; cpu_clock++) {
        if (offset_ >= array_size_ || cpu_clock == 0) {
            addr_a_ = cpu_clock << 10;
            addr_b_ = (cpu_clock << 20) + 0x100;
            addr_c_ = (cpu_clock << 30) + 0x200;
            offset_ = 0;
        }

        if (!inserted_a_ && dram->will_accept(addr_a_ + offset_, false)) {
            dram->add_request(new CoDRAMRequest(addr_a_ + offset_, false));
            inserted_a_ = true;
        }
        if (!inserted_b_ && dram->will_accept(addr_b_ + offset_, false)) {
            dram->add_request(new CoDRAMRequest(addr_b_ + offset_, false));
            inserted_b_ = true;
        }
        if (!inserted_c_ && dram->will_accept(addr_c_ + offset_, true)) {
            dram->add_request(new CoDRAMRequest(addr_c_ + offset_, true));
            inserted_c_ = true;
        }
        // moving on to next element
        if (inserted_a_ && inserted_b_ && inserted_c_) {
            offset_ += 0x40;
            inserted_a_ = false;
            inserted_b_ = false;
            inserted_c_ = false;
        }

        dram->tick();

        auto resp = dram->check_read_response();
        if (resp) {
            // std::cout << "cycle " << std::dec << cpu_clock << " resp "
            //   << "is_write " << std::dec << resp->req.is_write << " addr " << std::hex << resp->req.address << " "
            //   << "req_time " << std::dec << resp->req_time << " finish_time " << resp->finish_time << " resp_time " << resp->resp_time <<  std::endl;
            delete resp->req;
            delete resp;
        }
        resp = dram->check_write_response();
        if (resp) {
            // std::cout << "cycle " << std::dec << cpu_clock << " resp "
            //   << "is_write " << std::dec << resp->req.is_write << " addr " << std::hex << resp->req.address << " "
            //   << "req_time " << std::dec << resp->req_time << " finish_time " << resp->finish_time << " resp_time " << resp->resp_time <<  std::endl;
            delete resp->req;
            delete resp;
        }
    }
    end = clock();
    std::cout << (double)(end-start)/CLOCKS_PER_SEC << std::endl;
    delete dram;
    return 0;
}

int main(int argc, const char **argv) {
    if (argc > 1 && !strcmp(argv[1], "--cosim")) {
        return cosim_main();
    }
    args::ArgumentParser parser(
        "DRAM Simulator.",
        "Examples: \n."
        "./build/dramsim3main configs/DDR4_8Gb_x8_3200.ini -c 100 -t "
        "sample_trace.txt\n"
        "./build/dramsim3main configs/DDR4_8Gb_x8_3200.ini -s random -c 100");
    args::HelpFlag help(parser, "help", "Display the help menu", {'h', "help"});
    args::ValueFlag<uint64_t> num_cycles_arg(parser, "num_cycles",
                                             "Number of cycles to simulate",
                                             {'c', "cycles"}, 100000);
    args::ValueFlag<std::string> output_dir_arg(
        parser, "output_dir", "Output directory for stats files",
        {'o', "output-dir"}, ".");
    args::ValueFlag<std::string> stream_arg(
        parser, "stream_type", "address stream generator - (random), stream",
        {'s', "stream"}, "");
    args::ValueFlag<std::string> trace_file_arg(
        parser, "trace",
        "Trace file, setting this option will ignore -s option",
        {'t', "trace"});
    args::Positional<std::string> config_arg(
        parser, "config", "The config file name (mandatory)");

    try {
        parser.ParseCLI(argc, argv);
    } catch (args::Help) {
        std::cout << parser;
        return 0;
    } catch (args::ParseError e) {
        std::cerr << e.what() << std::endl;
        std::cerr << parser;
        return 1;
    }

    std::string config_file = args::get(config_arg);
    if (config_file.empty()) {
        std::cerr << parser;
        return 1;
    }

    uint64_t cycles = args::get(num_cycles_arg);
    std::string output_dir = args::get(output_dir_arg);
    std::string trace_file = args::get(trace_file_arg);
    std::string stream_type = args::get(stream_arg);

    CPU *cpu;
    if (!trace_file.empty()) {
        cpu = new TraceBasedCPU(config_file, output_dir, trace_file);
    } else {
        if (stream_type == "stream" || stream_type == "s") {
            cpu = new StreamCPU(config_file, output_dir);
        } else {
            cpu = new RandomCPU(config_file, output_dir);
        }
    }

    for (uint64_t clk = 0; clk < cycles; clk++) {
        cpu->ClockTick();
    }
    cpu->PrintStats();

    delete cpu;

    return 0;
}
