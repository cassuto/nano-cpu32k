#ifndef TRANSLATE_H_
#define TRANSLATE_H_

#define N_LOCAL_REGS 16
#define GET_PHY_REG(n) (n+N_LOCAL_REGS)


int mips_translate(uint8_t **gen, phy_addr_t pc);

static inline void emit_byte(uint8_t **gen, uint8_t dat) {
    *((*gen)++) = dat;
}

static inline void gen_venter(uint8_t **gen, uint8_t pc) {
}
static inline void gen_vexit(uint8_t **gen, uint8_t reg, uint16_t code) {
}

static inline void gen_add(uint8_t **gen, uint8_t rd, uint8_t rs1, uint8_t rs2) {
}
static inline void gen_lsl_i(uint8_t **gen, uint8_t rd, uint8_t rs1, uint16_t imm16) {
}
static inline void gen_cmpgt(uint8_t **gen, uint8_t rd, uint8_t rs1) {
}
static inline void gen_bt(uint8_t **gen, uint32_t rel) {
}


#endif /* TRANSLATE_H_ */
