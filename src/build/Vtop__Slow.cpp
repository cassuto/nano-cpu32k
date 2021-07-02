// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtop.h for the primary calling header

#include "Vtop.h"
#include "Vtop__Syms.h"

//==========


void Vtop___ctor_var_reset(Vtop* vlSelf);

Vtop::Vtop(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModule{_vcname__}
 {
    // Create Sym instance
    Vtop__Syms* __restrict vlSymsp = new Vtop__Syms(_vcontextp__, this, name());
    // Reset structure values
    Vtop___ctor_var_reset(this);
}

void Vtop::__Vconfigure(Vtop__Syms* _vlSymsp, bool first) {
    if (false && first) {}  // Prevent unused
    this->vlSymsp = _vlSymsp;
}

Vtop::~Vtop() {
    VL_DO_CLEAR(delete vlSymsp, vlSymsp = nullptr);
}

void Vtop___settle__TOP__2(Vtop* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___settle__TOP__2\n"); );
    // Body
    vlSelf->io_out = vlSelf->top__DOT__reg_result;
}

void Vtop___eval_initial(Vtop* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___eval_initial\n"); );
    // Body
    vlSelf->__Vclklast__TOP__clock = vlSelf->clock;
}

void Vtop___eval_settle(Vtop* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___eval_settle\n"); );
    // Body
    Vtop___settle__TOP__2(vlSelf);
}

void Vtop___final(Vtop* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___final\n"); );
}

void Vtop___ctor_var_reset(Vtop* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtop__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop___ctor_var_reset\n"); );
    // Body
    vlSelf->clock = VL_RAND_RESET_I(1);
    vlSelf->reset = VL_RAND_RESET_I(1);
    vlSelf->io_a = VL_RAND_RESET_I(32);
    vlSelf->io_b = VL_RAND_RESET_I(32);
    vlSelf->io_out = VL_RAND_RESET_I(32);
    vlSelf->top__DOT__reg_result = VL_RAND_RESET_I(32);
}
