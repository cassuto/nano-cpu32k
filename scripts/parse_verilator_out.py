'''
该脚本用于生成ysyx "Verilator中Warning无法清理说明.xlsx"
'''

import sys
import codecs

PATH_PREFIX = 'build/'

if len(sys.argv) < 3:
    print('Usage %s <input lint.txt> <output lint.csv>' % sys.argv[0])
    exit(1)

with open(sys.argv[1], 'r') as fp:
    with codecs.open(sys.argv[2], 'w', 'gbk') as fw:
        buf = fp.read().split('%')
        for b in buf:
            b = b.splitlines()
            if len(b) == 0:
                continue
            b = b[0]
            type = b[:14]
            if type == 'Warning-UNUSED':
                msg = b[16:]
                # strip path prefix
                if msg[:len(PATH_PREFIX)] == PATH_PREFIX:
                    msg = msg[len(PATH_PREFIX):]
                s = msg.find("'")+1
                e = msg.find("'", s)
                port = msg[s:e]
                
                desc = ''
                if port=='io_slave_awvalid'	or \
                    port=='io_slave_awaddr' or \
                    port=='io_slave_awid' or \
                    port=='io_slave_awlen' or \
                    port=='io_slave_awsize' or \
                    port=='io_slave_awburst' or \
                    port=='io_slave_wvalid' or \
                    port=='io_slave_wdata' or \
                    port=='io_slave_wstrb' or \
                    port=='io_slave_wlast' or \
                    port=='io_slave_bready' or \
                    port=='io_slave_arvalid' or \
                    port=='io_slave_araddr' or \
                    port=='io_slave_arid' or \
                    port=='io_slave_arlen' or \
                    port=='io_slave_arsize' or \
                    port=='io_slave_arburst' or \
                    port=='io_slave_rready':
                    desc = '未实现DMA，因此不使用AXI Slave接口'
                    
                elif port=='ibus_AWREADY' or \
                    port=='ibus_BID'	or \
                    port=='ibus_BRESP'	or \
                    port=='ibus_BUSER'	or \
                    port=='ibus_BVALID'	or \
                    port=='ibus_WREADY':
                    desc='指令Cache不写主存，因此不使用W通道'
                    
                elif port=='io_master_arcache': desc='不支持arcache'
                elif port=='io_master_arlock': desc='不支持arlock'
                elif port=='io_master_arprot': desc='不支持arprot'
                elif port=='io_master_arqos': desc='不支持arqos'
                elif port=='io_master_arregion': desc='不支持arregion'
                elif port=='io_master_aruser': desc='不支持aruser'
                elif port=='io_master_awcache': desc='不支持awcache'
                elif port=='io_master_awlock': desc='不支持awlock'
                elif port=='io_master_awprot': desc='不支持awprot'
                elif port=='io_master_awqos': desc='不支持awqos'
                elif port=='io_master_awregion': desc='不支持awregion'
                elif port=='io_master_awuser': desc='不支持awuser'
                elif port=='io_master_wuser': desc='不支持wuser'
                elif port=='cmt_bpu_upd' or \
                    port=='cmt_pc' or \
                    port=='cmt_prd' or \
                    port=='cmt_prd_we' or \
                    port=='cmt_pfree' or \
                    port=='cmt_opera' or \
                    port=='cmt_operb'  or \
                    port=='cmt_fls_tgt':
                    desc='LSU只使用了2个提交通道中的第1个,剩余通道悬空，但2个通道的控制信号都需要使用'
                    
                elif port=='s1i_msr_addr' or \
                    port=='s1o_commit_bank_off':
                    desc='MSR地址空间内只映射了部分寄存器，部分地址线悬空'
                    
                elif port=='s1i_barr': desc='未实现内存屏障指令'
                elif port=='ibus_RRESP': desc='不支持RRESP返回非OK的状态'
                elif port=='ibus_RID': desc='未使用ID'
                elif port=='ibus_RUSER': desc='未使用user'
                elif port=='s1o_op_inv_paddr': desc='Cache Invalidate以块为单位，只用到了块号'
                elif port=='s2o_paddr': desc='地址对齐于64字节边界，低3位未使用'
                elif port=='tlb_l_ff': desc='PTE中某些bit保留给软件，硬件未使用'
                elif port=='tlb_h_ff': desc='PTE中某些bit保留给软件，硬件未使用'
                elif port=='iq_push_offset': desc='计数器输出的数据宽度为2位，实际只用到1位'
                elif port=='tcr_ff': desc='最高位保留给软件，硬件未使用'
                elif port=='dbus_RRESP': desc='不支持RRESP返回非OK的状态'
                elif port=='dbus_RID': desc='未使用ID'
                elif port=='dbus_RUSER': desc='未使用user'
                elif port=='dbus_BRESP': desc='不支持BRESP返回非OK的状态'
                elif port=='dbus_BID': desc='未使用ID'
                elif port=='dbus_BUSER': desc='未使用user'
                elif port=='tlb_l_ff': desc='PTE中某些bit保留给软件，硬件未使用'
                elif port=='tlb_h_ff': desc='PTE中某些bit保留给软件，硬件未使用'
                elif port=='shift_wide': desc='需先移位再截断成32位'
                elif port=='i_addr': desc='用于数据对齐和拼接，某些地址线未使用'
                else:
                    print('No description for port "%s", please add one' % port)
                    
                fw.write('"%s","%s","%s"\n' % (type, msg, desc))
        