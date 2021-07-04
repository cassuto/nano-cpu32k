// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vtop__Syms.h"


//======================

void Vtop__traceInitTop(Vtop* vlSelf, VerilatedVcd* tracep);

static void traceInit(void* voidSelf, VerilatedVcd* tracep, uint32_t code) {
    // Callback from tracep->open()
    Vtop*const __restrict vlSelf = static_cast<Vtop*>(voidSelf);
    if (!vlSelf->vlSymsp->_vm_contextp__->calcUnusedSigs()) {
        VL_FATAL_MT(__FILE__, __LINE__, __FILE__,
                        "Turning on wave traces requires Verilated::traceEverOn(true) call before time 0.");
    }
    vlSelf->vlSymsp->__Vm_baseCode = code;
    tracep->module(vlSelf->vlSymsp->name());
    tracep->scopeEscape(' ');
    Vtop__traceInitTop(vlSelf, tracep);
    tracep->scopeEscape('.');
}

void Vtop__traceRegister(Vtop* vlSelf, VerilatedVcd* tracep);

void Vtop::trace(VerilatedVcdC* tfp, int, int) {
    tfp->spTrace()->addInitCb(&traceInit, this);
    Vtop__traceRegister(this, tfp->spTrace());
}

//======================


void Vtop__traceInitSub0(Vtop* vlSelf, VerilatedVcd* tracep) VL_ATTR_COLD;

void Vtop__traceInitTop(Vtop* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    {
        Vtop__traceInitSub0(vlSelf, tracep);
    }
}

void Vtop__traceInitSub0(Vtop* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    const int c = vlSymsp->__Vm_baseCode;
    if (false && tracep && c) {}  // Prevent unused
    // Body
    {
        tracep->declBit(c+1,"clk", false,-1);
        tracep->declBit(c+2,"reset", false,-1);
        tracep->declBus(c+3,"out", false,-1, 3,0);
        tracep->declBit(c+1,"top clk", false,-1);
        tracep->declBit(c+2,"top reset", false,-1);
        tracep->declBus(c+3,"top out", false,-1, 3,0);
    }
}

void Vtop__traceFullTop0(void* voidSelf, VerilatedVcd* tracep) VL_ATTR_COLD;
void Vtop__traceChgTop0(void* voidSelf, VerilatedVcd* tracep);
void Vtop__traceCleanup(void* voidSelf, VerilatedVcd* /*unused*/);

void Vtop__traceRegister(Vtop* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    {
        tracep->addFullCb(&Vtop__traceFullTop0, vlSelf);
        tracep->addChgCb(&Vtop__traceChgTop0, vlSelf);
        tracep->addCleanupCb(&Vtop__traceCleanup, vlSelf);
    }
}

void Vtop__traceFullSub0(Vtop* vlSelf, VerilatedVcd* tracep) VL_ATTR_COLD;

void Vtop__traceFullTop0(void* voidSelf, VerilatedVcd* tracep) {
    Vtop* const __restrict vlSelf = static_cast<Vtop*>(voidSelf);
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    {
        Vtop__traceFullSub0(vlSymsp->TOPp, tracep);
    }
}

void Vtop__traceFullSub0(Vtop* vlSelf, VerilatedVcd* tracep) {
    if (false && vlSelf) {}  // Prevent unused
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    vluint32_t* const oldp = tracep->oldp(vlSymsp->__Vm_baseCode);
    if (false && oldp) {}  // Prevent unused
    // Body
    {
        tracep->fullBit(oldp+1,(vlSelf->clk));
        tracep->fullBit(oldp+2,(vlSelf->reset));
        tracep->fullCData(oldp+3,(vlSelf->out),4);
    }
}
