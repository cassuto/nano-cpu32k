#ifndef AXI4_CROSSBAR_H_
#define AXI4_CROSSBAR_H_

#include "common.hh"
#include "axi4.hh"

#define MAX_AXI_DATA_LEN 8

class CoDRAMsim3;
class CoDRAMRequest;
class CoDRAMResponse;

class Axi4CrossbarRequest
{
public:
    uint64_t address;
    bool is_write;
    bool is_mmio;
    uint8_t len;
    uint8_t size;
    uint8_t offset;
    uint8_t id;
    uint64_t data[MAX_AXI_DATA_LEN];
    CoDRAMRequest *dram_req;
};

class Axi4CrossbarResponse
{
public:
    Axi4CrossbarRequest *req;
    CoDRAMResponse *dram_resp;
};

class Axi4Crossbar
{
public:
    Axi4Crossbar(Memory *mem_);
    ~Axi4Crossbar();

    void clk_rising(const axi_channel &axi);
    void clk_falling(axi_channel &axi);

private:
    bool is_mmio(uint64_t address);
    uint64_t pread(uint64_t address, uint8_t beatsize);
    void pwrite(uint64_t address, uint64_t dat, uint8_t beatsize);
    Axi4CrossbarRequest *axi_request(const axi_channel &axi, bool is_write);
    void axi_read_data(const axi_ar_channel &ar, Axi4CrossbarRequest *req);

private:
    Memory *mem;
    CoDRAMsim3 *dramsim;
    phy_addr_t mmio_phy_base, mmio_phy_end_addr;
    Axi4CrossbarResponse *wait_resp_r;
    Axi4CrossbarResponse *wait_resp_b;
    Axi4CrossbarRequest *wait_req_w;
    Axi4CrossbarRequest *wait_req_r;
};

#endif
