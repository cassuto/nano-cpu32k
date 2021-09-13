#ifndef SYMTABLE_H_
#define SYMTABLE_H_

#include "common.hh"

class Symtable
{
public:
    Symtable();
    ~Symtable();

    struct sym_node
    {
        vm_addr_t vm_addr;
        char sym_type[8];
        char symbol[2048];
        sym_node *next;
    };

    int load(const char *symfile);
    const sym_node *find(vm_addr_t addr);

private:
    sym_node *sym_list;
};

#endif /* PARSE_SYMTABLE_H_ */
