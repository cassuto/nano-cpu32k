/***************************************************************************************
* Copyright (c) 2020-2021 Institute of Computing Technology, Chinese Academy of Sciences
* Copyright (c) 2020-2021 Peng Cheng Laboratory
*
* XiangShan is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include "memory.hh"
#include "cosimulation.h"
#include "axi4-crossbar.hh"

Axi4Crossbar::Axi4Crossbar(Memory *mem_)
    : mem(mem_),
      dramsim(nullptr),
      wait_resp_r(nullptr),
      wait_resp_b(nullptr),
      wait_req_w(nullptr),
      wait_req_r(nullptr)
{
#if !defined(DRAMSIM3_CONFIG) || !defined(DRAMSIM3_OUTDIR)
#error DRAMSIM3_CONFIG or DRAMSIM3_OUTDIR is not defined
#endif
    dramsim = new ComplexCoDRAMsim3(DRAMSIM3_CONFIG, DRAMSIM3_OUTDIR);
}

Axi4Crossbar::~Axi4Crossbar()
{
    delete dramsim;
}

bool Axi4Crossbar::is_mmio(uint64_t address)
{
    return ((address >= mem->get_mmio_phy_base()) && (address <= mem->get_mmio_phy_end_addr()));
}

uint64_t Axi4Crossbar::pread(uint64_t address, uint8_t beatsize)
{
    uint64_t dat;
    switch (beatsize)
    {
    case 8:
        dat = mem->phy_readm64(address);
        break;
    case 4:
        dat = mem->phy_readm32(address);
        break;
    case 2:
        dat = mem->phy_readm16(address);
        break;
    case 1:
        dat = mem->phy_readm8(address);
        break;
    default:
        assert(0);
    }
    uint32_t bytelane = address & (sizeof(uint64_t) - 1);
    return ((uint64_t)dat << (bytelane << 3));
}

void Axi4Crossbar::pwrite(uint64_t address, uint64_t dat, uint8_t beatsize)
{
    uint32_t bytelane = address & (sizeof(uint64_t) - 1);
    switch (beatsize)
    {
    case 8:
        mem->phy_writem64(address, dat >> (bytelane << 3));
        break;
    case 4:
        mem->phy_writem32(address, dat >> (bytelane << 3));
        break;
    case 2:
        mem->phy_writem16(address, dat >> (bytelane << 3));
        break;
    case 1:
        mem->phy_writem8(address, dat >> (bytelane << 3));
        break;
    default:
        assert(0);
    }
}

void Axi4Crossbar::axi_read_data(const axi_ar_channel &ar, Axi4CrossbarRequest *req)
{
    uint64_t address = ar.addr;
    uint64_t beatsize = 1 << ar.size;
    uint8_t beatlen = ar.len + 1;
    uint64_t transaction_size = beatsize * beatlen;
    assert(beatsize <= 8);
    assert(beatlen <= MAX_AXI_DATA_LEN);
    assert(transaction_size % beatsize == 0);

    // axi burst FIXEDs
    if (ar.burst == 0x0)
    {
        fprintf(stderr, "axi burst FIXED not supported!");
        assert(0);
    }
    // axi burst INCR
    else if (ar.burst == 1)
    {
        for (int i = 0; i < beatlen; i++)
        {
            req->data[i] = pread(address, beatsize);
            address += beatsize;
        }
    }
    // axi burst WRAP
    else if (ar.burst == 2)
    {
        uint64_t low = (address / transaction_size) * transaction_size;
        uint64_t high = low + transaction_size;
        // TODO: untested
        for (int i = 0; i < beatlen; i++)
        {
            if (address == high)
            {
                address = low;
            }
            req->data[i] = pread(address, beatsize);
            address += beatsize;
        }
    }
    else
    {
        fprintf(stderr, "reserved arburst!");
        assert(0);
    }
    req->len = beatlen;
    req->size = beatsize;
    req->offset = 0;
    req->id = ar.id;
}

Axi4CrossbarRequest *Axi4Crossbar::axi_request(const axi_channel &axi, bool is_write)
{
    Axi4CrossbarRequest *req = new Axi4CrossbarRequest();

    req->address = (is_write) ? axi.aw.addr : axi.ar.addr;
    req->is_write = is_write;
    req->is_mmio = is_mmio(req->address);
    req->resp_inflight = false;
    if (is_write)
    {
        req->len = axi.aw.len + 1;
        req->size = 1 << axi.aw.size;
        req->offset = 0;
        req->id = axi.aw.id;
    }
    else
    {
        axi_read_data(axi.ar, req);
    }

    if (req->is_mmio)
    {
        req->dram_req = nullptr;
    }
    else
    {
        req->dram_req = new CoDRAMRequest();
        req->dram_req->address = req->address % mem->get_size();
        req->dram_req->is_write = is_write;
        req->dram_req->meta = nullptr;
    }
    return req;
}

// currently only accept one in-flight read + one in-flight write,

void Axi4Crossbar::clk_rising(const axi_channel &axi)
{
    // ticks DRAMsim3 according to CPU_FREQ:DRAM_FREQ
    dramsim->tick();

    // read data fire: check the last read request
    if (axi_check_rdata_fire(axi))
    {
        if (wait_resp_r == nullptr)
        {
            fprintf(stderr, "ERROR: There's no in-flight read request.\n");
            assert(wait_resp_r);
        }
        wait_resp_r->req->offset++;
        // check whether the last rdata response has finished
        if (wait_resp_r->req->offset == wait_resp_r->req->len)
        {
            delete wait_resp_r->req;
            delete wait_resp_r->dram_resp;
            delete wait_resp_r;
            wait_resp_r = nullptr;
            wait_req_r = nullptr;
        }
    }

    // read address fire: accept a new request
    if (axi_check_raddr_fire(axi))
    {
        wait_req_r = axi_request(axi, false);
        if (!wait_req_r->is_mmio)
            dramsim->add_request(wait_req_r->dram_req);
    }

    // the last write transaction is acknowledged
    if (axi_check_wack_fire(axi))
    {
        if (wait_resp_b == nullptr)
        {
            fprintf(stderr, "ERROR: write response fire for nothing in-flight.\n");
            assert(wait_resp_b);
        }
        delete wait_resp_b->req;
        delete wait_resp_b->dram_resp;
        delete wait_resp_b;
        wait_resp_b = nullptr;
        wait_req_w = nullptr;
    }

    // write address fire: accept a new write request
    if (axi_check_waddr_fire(axi))
    {
        if (wait_req_w)
        {
            fprintf(stderr, "ERROR: The last write request has not finished.\n");
            assert(wait_req_w == nullptr);
        }
        wait_req_w = axi_request(axi, true);
        // printf("accept a new write request to addr = 0x%lx, len = %d\n", axi.aw.addr, axi.aw.len);
    }

    // write data fire
    if (axi_check_wdata_fire(axi))
    {
        if (wait_req_w == nullptr)
        {
            fprintf(stderr, "ERROR: wdata fire for nothing in-flight.\n");
            assert(wait_req_w);
        }

        assert(wait_req_w->size <= 8); // The current STRB supports no more than 8 bytes of data
        uint64_t waddr = wait_req_w->address + wait_req_w->offset * wait_req_w->size;

        // FIXME For MMIO, wstrb behaves incorrectly
        uint64_t wdat = pread(waddr, wait_req_w->size);
        axi_get_wdata(axi, &wdat, &wdat, sizeof(uint64_t));
        pwrite(waddr, wdat, wait_req_w->size);

        //if(wait_req_w->is_mmio)
        printf("mmio waddr=%#x size=%d\n", waddr, wait_req_w->size);

        wait_req_w->offset++;
        // printf("accept a new write data. waddr=%#lx\n", waddr);
    }
    // if this is the last beat
    if (wait_req_w && !wait_req_w->resp_inflight && (wait_req_w->offset == wait_req_w->len))
    {
        if (wait_req_w->is_mmio)
        {
            wait_req_w->resp_inflight = true;
        }
        else
        {
            if (dramsim->will_accept(wait_req_w->address, true))
            {
                dramsim->add_request(wait_req_w->dram_req);
                wait_req_w->resp_inflight = true;
            }
        }
    }
}

void Axi4Crossbar::clk_falling(axi_channel &axi)
{
    // default branch to avoid wrong handshake
    axi.aw.ready = 0;
    axi.w.ready = 0;
    axi.b.valid = 0;
    axi.ar.ready = 0;
    axi.r.valid = 0;

    // RDATA: if finished, we try the next rdata response
    if (!wait_resp_r && wait_req_r)
    {
        if (wait_req_r->is_mmio)
        {
            wait_resp_r = new Axi4CrossbarResponse();
            wait_resp_r->req = wait_req_r;
            wait_resp_r->dram_resp = nullptr;
        }
        else
        {
            CoDRAMResponse *dram_resp = dramsim->check_read_response();
            if (dram_resp)
            {
                wait_resp_r = new Axi4CrossbarResponse();
                wait_resp_r->req = wait_req_r;
                wait_resp_r->dram_resp = dram_resp;
            }
        }
    }
    // if there's some data response, put it onto axi bus
    if (wait_resp_r)
    {
        const uint64_t *data_start = wait_resp_r->req->data + wait_resp_r->req->offset;
        axi_put_rdata(axi, data_start, wait_resp_r->req->size, wait_resp_r->req->offset == wait_resp_r->req->len - 1, wait_resp_r->req->id);
    }

    // RADDR: check whether the read request can be accepted
    axi_addr_t raddr;
    if (wait_req_r == nullptr && axi_get_raddr(axi, raddr))
    {
        bool fire = is_mmio(axi.ar.addr) ? true : dramsim->will_accept(raddr, false);
        if (fire)
        {
            axi_accept_raddr(axi);
            // printf("try to accept read request to 0x%lx\n", raddr);
        }
    }

    // WREQ: check whether the write request can be accepted
    // Note: block the next write here to simplify logic
    axi_addr_t waddr;
    if (wait_req_w == nullptr && axi_get_waddr(axi, waddr))
    {
        bool fire = is_mmio(axi.aw.addr) ? true : dramsim->will_accept(waddr, true);
        if (fire)
        {
            axi_accept_waddr(axi);
            axi_accept_wdata(axi);
            // printf("try to accept write request to 0x%lx\n", waddr);
        }
    }

    // WDATA: check whether the write data can be accepted
    if (wait_req_w)
    {
        // we have to check whether the last finished write request has been accepted by dramsim
        bool fire = (wait_req_w->is_mmio) ? true : dramsim->will_accept(wait_req_w->address, true);
        if (fire)
        {
            if (wait_req_w->offset != wait_req_w->len)
                axi_accept_wdata(axi);
        }
    }

    // WRESP: if finished, we try the next write response
    if (!wait_resp_b && wait_req_w)
    {
        if (wait_req_w->is_mmio)
        {
            wait_resp_b = new Axi4CrossbarResponse();
            wait_resp_b->req = wait_req_w;
            wait_resp_b->dram_resp = nullptr;
        }
        else
        {
            CoDRAMResponse *dram_resp = dramsim->check_write_response();
            if (dram_resp)
            {
                wait_resp_b = new Axi4CrossbarResponse();
                wait_resp_b->req = wait_req_w;
                wait_resp_b->dram_resp = dram_resp;
            }
        }
    }
    // if there's some write response, put it onto axi bus
    if (wait_resp_b)
    {
        axi_put_wack(axi, wait_resp_b->req->id);
    }
}
