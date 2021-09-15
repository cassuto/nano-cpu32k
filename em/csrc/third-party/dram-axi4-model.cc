/***************************************************************************************
* This code is based on XiangShan-difftest project.
*
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

#include "common.hh"
#include "memory.hh"
#include "axi4.hh"
#include "dram-axi4-model.hh"

DRAM::DRAM(Memory *mem_)
    : mem(mem_),
      dram(nullptr),
      wait_resp_r(nullptr),
      wait_resp_b(nullptr),
      wait_req_w(nullptr),
      raddr(0), roffset(0), rlen(0),
      waddr(0), woffset(0), wlen(0)

{
#if !defined(DRAMSIM3_CONFIG) || !defined(DRAMSIM3_OUTDIR)
#error DRAMSIM3_CONFIG or DRAMSIM3_OUTDIR is not defined
#endif
    assert(dram == NULL);
    dram = new ComplexCoDRAMsim3(DRAMSIM3_CONFIG, DRAMSIM3_OUTDIR);
}

DRAM::~DRAM()
{
    delete dram;
}

uint64_t DRAM::ram_read_helper(uint8_t en, uint64_t rIdx)
{
    assert(mem);
    if (en && rIdx >= mem->get_size() / sizeof(uint64_t))
    {
        rIdx %= mem->get_size() / sizeof(uint64_t);
    }
    uint64_t rdata = (en) ? mem->dram_readm64(rIdx) : 0;
    return rdata;
}

void DRAM::ram_write_helper(uint64_t wIdx, uint64_t wdata, uint64_t wmask, uint8_t wen)
{
    assert(mem);
    if (wen)
    {
        if (wIdx >= mem->get_size() / sizeof(uint64_t))
        {
            fprintf(stderr, "ERROR: mem wIdx = 0x%lx out of bound!\n", wIdx);
            assert(wIdx < mem->get_size() / sizeof(uint64_t));
        }
        mem->dram_writem64(wIdx, (mem->dram_readm64(wIdx) & ~wmask) | (wdata & wmask));
    }
}

uint64_t DRAM::pmem_read(uint64_t raddr)
{
    if (raddr % sizeof(uint64_t))
    {
        fprintf(stderr, "Warning: pmem_read only supports 64-bit aligned memory access\n");
    }
    raddr -= 0x80000000;
    return ram_read_helper(1, raddr / sizeof(uint64_t));
}

void DRAM::pmem_write(uint64_t waddr, uint64_t wdata)
{
    if (waddr % sizeof(uint64_t))
    {
        fprintf(stderr, "Warning: pmem_write only supports 64-bit aligned memory access\n");
    }
    waddr -= 0x80000000;
    return ram_write_helper(waddr / sizeof(uint64_t), wdata, -1UL, 1);
}

// currently does not support masked read or write

void DRAM::axi_read_data(const axi_ar_channel &ar, dramsim3_meta *meta)
{
    uint64_t address = ar.addr % mem->get_size();
    uint64_t beatsize = 1 << ar.size;
    uint8_t beatlen = ar.len + 1;
    uint64_t transaction_size = beatsize * beatlen;
    assert(beatsize <= 8);
    assert((transaction_size % sizeof(uint64_t)) == 0);
    // axi burst FIXED
    if (ar.burst == 0x0)
    {
        fprintf(stderr, "axi burst FIXED not supported!");
        assert(0);
    }
    // axi burst INCR
    else if (ar.burst == 1)
    {
        assert(transaction_size / sizeof(uint64_t) <= MAX_AXI_DATA_LEN);
        for (int i = 0; i < transaction_size / sizeof(uint64_t); i++)
        {
            meta->data[i] = mem->dram_readm64(address / sizeof(uint64_t));
            address += sizeof(uint64_t);
        }
    }
    // axi burst WRAP
    else if (ar.burst == 2)
    {
        uint64_t low = (address / transaction_size) * transaction_size;
        uint64_t high = low + transaction_size;
        assert(transaction_size / sizeof(uint64_t) <= MAX_AXI_DATA_LEN);
        for (int i = 0; i < transaction_size / sizeof(uint64_t); i++)
        {
            if (address == high)
            {
                address = low;
            }
            meta->data[i] = mem->dram_readm64(address / sizeof(uint64_t));
            address += sizeof(uint64_t);
        }
    }
    else
    {
        fprintf(stderr, "reserved arburst!");
        assert(0);
    }
    meta->len = beatlen;
    meta->size = beatsize;
    meta->offset = 0;
    meta->id = ar.id;
}

CoDRAMRequest *DRAM::dramsim3_request(const axi_channel &axi, bool is_write)
{
    uint64_t address = (is_write) ? axi.aw.addr : axi.ar.addr;
    dramsim3_meta *meta = new dramsim3_meta;
    // WRITE
    if (is_write)
    {
        meta->len = axi.aw.len + 1;
        meta->size = 1 << axi.aw.size;
        meta->offset = 0;
        meta->id = axi.aw.id;
    }
    else
    {
        axi_read_data(axi.ar, meta);
    }
    CoDRAMRequest *req = new CoDRAMRequest();
    req->address = address;
    req->is_write = is_write;
    req->meta = meta;
    return req;
}

// currently only accept one in-flight read + one in-flight write

void DRAM::dramsim3_helper_rising(const axi_channel &axi)
{
    // ticks DRAMsim3 according to CPU_FREQ:DRAM_FREQ
    dram->tick();

    // read data fire: check the last read request
    if (axi_check_rdata_fire(axi))
    {
        if (wait_resp_r == NULL)
        {
            fprintf(stderr, "ERROR: There's no in-flight read request.\n");
            assert(wait_resp_r != NULL);
        }
        dramsim3_meta *meta = static_cast<dramsim3_meta *>(wait_resp_r->req->meta);
        meta->offset++;
        // check whether the last rdata response has finished
        if (meta->offset == meta->len)
        {
            delete meta;
            delete wait_resp_r->req;
            delete wait_resp_r;
            wait_resp_r = NULL;
        }
    }

    // read address fire: accept a new request
    if (axi_check_raddr_fire(axi))
    {
        dram->add_request(dramsim3_request(axi, false));
    }

    // the last write transaction is acknowledged
    if (axi_check_wack_fire(axi))
    {
        if (wait_resp_b == NULL)
        {
            fprintf(stderr, "ERROR: write response fire for nothing in-flight.\n");
            assert(wait_resp_b != NULL);
        }
        // flush data to memory
        uint64_t waddr = wait_resp_b->req->address % mem->get_size();
        dramsim3_meta *meta = static_cast<dramsim3_meta *>(wait_resp_b->req->meta);
        void *start_addr = mem->dram_refm64(waddr / sizeof(uint64_t));
        memcpy(start_addr, meta->data, meta->len * meta->size);
        printf("flush data=");
        for(int i=0;i<meta->len;i++){
            printf("%#x ", meta->data[i]);
        }
        printf("\n");
        delete meta;
        delete wait_resp_b->req;
        delete wait_resp_b;
        wait_resp_b = NULL;
    }

    // write address fire: accept a new write request
    if (axi_check_waddr_fire(axi))
    {
        if (wait_req_w != NULL)
        {
            printf("ERROR: The last write request has not finished.\n");
            assert(wait_req_w == NULL);
        }
        wait_req_w = dramsim3_request(axi, true);
        // printf("accept a new write request to addr = 0x%lx, len = %d\n", axi.aw.addr, axi.aw.len);
    }

    // write data fire: for the last write transaction
    if (axi_check_wdata_fire(axi))
    {
        if (wait_req_w == NULL)
        {
            fprintf(stderr, "ERROR: wdata fire for nothing in-flight.\n");
            assert(wait_req_w != NULL);
        }
        dramsim3_meta *meta = static_cast<dramsim3_meta *>(wait_req_w->meta);
        void *data_start = meta->data + meta->offset * meta->size / sizeof(uint64_t);
        uint64_t waddr = axi.aw.addr % mem->get_size();
#if 0
        const void *src_addr = mem + (waddr + meta->offset * meta->size) / sizeof(uint64_t);
#else
        assert(meta->size <= 8); // The current STRB supports no more than 8 bytes of data
        const void *src_addr = mem->dram_refm64((waddr + meta->offset * meta->size) / sizeof(uint64_t));
#endif
        axi_get_wdata(axi, data_start, src_addr, meta->size);
        meta->offset++;
        // printf("accept a new write data\n");
        printf("offset=%#x data=", meta->offset);
        for(int i=0;i<meta->len;i++){
            printf("%#x ", meta->data[i]);
        }
        printf("\n");
    }
    if (wait_req_w)
    {
        dramsim3_meta *meta = static_cast<dramsim3_meta *>(wait_req_w->meta);
        // if this is the last beat
        if (meta->offset == meta->len && dram->will_accept(wait_req_w->address, true))
        {
            dram->add_request(wait_req_w);
            wait_req_w = NULL;
        }
    }
}

void DRAM::dramsim3_helper_falling(axi_channel &axi)
{
    // default branch to avoid wrong handshake
    axi.aw.ready = 0;
    axi.w.ready = 0;
    axi.b.valid = 0;
    axi.ar.ready = 0;
    axi.r.valid = 0;

    // RDATA: if finished, we try the next rdata response
    if (!wait_resp_r)
        wait_resp_r = dram->check_read_response();
    // if there's some data response, put it onto axi bus
    if (wait_resp_r)
    {
        dramsim3_meta *meta = static_cast<dramsim3_meta *>(wait_resp_r->req->meta);
        // printf("meta->size %d offset %d\n", meta->size, meta->offset*meta->size/sizeof(uint64_t));
        void *data_start = meta->data + meta->offset * meta->size / sizeof(uint64_t);
        axi_put_rdata(axi, data_start, meta->size, meta->offset == meta->len - 1, meta->id);
    }

    // RADDR: check whether the read request can be accepted
    axi_addr_t raddr;
    if (axi_get_raddr(axi, raddr) && dram->will_accept(raddr, false))
    {
        axi_accept_raddr(axi);
        // printf("try to accept read request to 0x%lx\n", raddr);
    }

    // WREQ: check whether the write request can be accepted
    // Note: block the next write here to simplify logic
    axi_addr_t waddr;
    if (wait_req_w == NULL && axi_get_waddr(axi, waddr) && dram->will_accept(waddr, true))
    {
        axi_accept_waddr(axi);
        axi_accept_wdata(axi);
        // printf("try to accept write request to 0x%lx\n", waddr);
    }

    // WDATA: check whether the write data can be accepted
    if (wait_req_w != NULL && dram->will_accept(wait_req_w->address, true))
    {
        dramsim3_meta *meta = static_cast<dramsim3_meta *>(wait_req_w->meta);
        // we have to check whether the last finished write request has been accepted by dram
        if (meta->offset != meta->len)
        {
            axi_accept_wdata(axi);
        }
    }

    // WRESP: if finished, we try the next write response
    if (!wait_resp_b)
        wait_resp_b = dram->check_write_response();
    // if there's some write response, put it onto axi bus
    if (wait_resp_b)
    {
        dramsim3_meta *meta = static_cast<dramsim3_meta *>(wait_resp_b->req->meta);
        axi_put_wack(axi, meta->id);
    }
}
