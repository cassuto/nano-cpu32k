
#include "translate.h"

struct mips_opcode
{
    uint8_t type; /* 0=R-type 1=I-type 2=J-type */
    void (*translate_proc)(uint8_t **gen, uint8_t *insn);
};

static uint8_t opcode;
static uint8_t R_sa,R_rd,R_rt,R_rs,R_func;
static uint16_t I_imm16;
static uint8_t I_rt,I_rs;
static uint32_t J_rel26;

static void dummy_invalid(uint8_t **gen, uint8_t *insn);
static void translate_add(uint8_t **gen, uint8_t *insn);

static struct mips_opcode mips_opcode_table[64] = {
    /* 0 */ {-1, &dummy_invalid},
    /* 1 */ {-1, &dummy_invalid},
    /* 2 */ {-1, &dummy_invalid},
    /* 3 */ {-1, &dummy_invalid},
    /* 4 */ {-1, &dummy_invalid},
    /* 5 */ {-1, &dummy_invalid},
    /* 6 */ {-1, &dummy_invalid},
    /* 7 */ {-1, &dummy_invalid},
    /* 8 */ {-1, &dummy_invalid},
    /* 9 */ {-1, &dummy_invalid},
    /* 10 */ {-1, &dummy_invalid},
    /* 11 */ {-1, &dummy_invalid},
    /* 12 */ {-1, &dummy_invalid},
    /* 13 */ {-1, &dummy_invalid},
    /* 14 */ {-1, &dummy_invalid},
    /* 15 */ {-1, &dummy_invalid},
    /* 16 */ {-1, &dummy_invalid},
    /* 17 */ {-1, &dummy_invalid},
    /* 18 */ {-1, &dummy_invalid},
    /* 19 */ {-1, &dummy_invalid},
    /* 20 */ {-1, &dummy_invalid},
    /* 21 */ {-1, &dummy_invalid},
    /* 22 */ {-1, &dummy_invalid},
    /* 23 */ {-1, &dummy_invalid},
    /* 24 */ {-1, &dummy_invalid},
    /* 25 */ {-1, &dummy_invalid},
    /* 26 */ {-1, &dummy_invalid},
    /* 27 */ {-1, &dummy_invalid},
    /* 28 */ {-1, &dummy_invalid},
    /* 29 */ {-1, &dummy_invalid},
    /* 30 */ {-1, &dummy_invalid},
    /* 31 */ {-1, &dummy_invalid},
    /* 32 */ {0, &translate_add},
    /* 33 */ {-1, &dummy_invalid},
};

#define SIGNAL_EXCEPTION_INTEGER_OVERFLOW 0

static void translate_add(uint8_t **gen, uint8_t *insn) {
    gen_add(gen, 1, GET_PHY_REG(R_rt), GET_PHY_REG(R_rs));
    gen_lsl_i(gen, 2,1, 32);
    gen_cmpgt(gen, 2,0);
    /* +0 */ gen_bt(gen, 2);
    /* +1 */ gen_add(gen, GET_PHY_REG(R_rd), 1, 0);
    /* +2 */ gen_vexit(gen, 0, SIGNAL_EXCEPTION_INTEGER_OVERFLOW);
}

int translate_mips(uint8_t **gen, phy_addr_t pc)
{
    for(;;) {
        uint8_t *target_code = (uint8_t *)pc;
        opcode=target_code[0]&0x3F;
        if(opcode >= 0 && opcode <=63) {
            struct mips_opcode *op = &mips_opcode_table[opcode];
            switch(op->type) {
                case 0:
                    R_sa=((target_code[0]&0xC0)>>6) | ((target_code[1]&0x03)<<3);
                    R_rd=(target_code[1]&0xF8)>>3;
                    R_rt=(target_code[1]&0x1F);
                    R_rs=((target_code[2]&0xE0)>>5) | ((target_code[3]&0x03)<<3);
                    R_func=(target_code[3]&0xFC)>>2;
                    break;
                case 1:
                    break;
                case 2:
                    break;
            }
            (*op->translate_proc)(gen, target_code);
        }
    }
}
