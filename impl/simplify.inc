#ifndef SIMPLIFY_INC
#define SIMPLIFY_INC

#define ENTRY(symbol)	\
	.align 4	;\
	.global symbol	;\
	.type	symbol, @function ;\
symbol:

#endif
