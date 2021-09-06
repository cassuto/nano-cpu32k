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

#ifndef DRAM_AXI4_MODEL_H_
#define DRAM_AXI4_MODEL_H_

#include "common.hh"
#include "cosimulation.h"

#define MAX_AXI_DATA_LEN 8

struct dramsim3_meta
{
    uint8_t len;
    uint8_t size;
    uint8_t offset;
    uint8_t id;
    uint64_t data[MAX_AXI_DATA_LEN];
};

class DRAM
{
public:
    DRAM(Memory *mem_);
    ~DRAM();

    uint64_t ram_read_helper(uint8_t en, uint64_t rIdx);
    void ram_write_helper(uint64_t wIdx, uint64_t wdata, uint64_t wmask, uint8_t wen);
    uint64_t pmem_read(uint64_t raddr);
    void pmem_write(uint64_t waddr, uint64_t wdata);

    void dramsim3_helper_rising(const axi_channel &axi);
    void dramsim3_helper_falling(axi_channel &axi);

private:
    void axi_read_data(const axi_ar_channel &ar, dramsim3_meta *meta);
    CoDRAMRequest *dramsim3_request(const axi_channel &axi, bool is_write);

private:
    Memory *mem;
    CoDRAMsim3 *dram;
    CoDRAMResponse *wait_resp_r;
    CoDRAMResponse *wait_resp_b;
    CoDRAMRequest *wait_req_w;
    uint64_t raddr, roffset, rlen;
    uint64_t waddr, woffset, wlen;
};

#endif
