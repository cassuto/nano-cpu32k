/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include "symtable.hh"

Symtable::Symtable()
    : sym_list(nullptr)
{
}

Symtable::~Symtable()
{
    struct sym_node *node = sym_list, *tnode;
    while (node)
    {
        tnode = node;
        node = node->next;
        delete tnode;
    }
}

/**
 * @brief Load a symbol table file.
 * @param symfile Symbol table file path;
 * @return status code.
 */
int Symtable::load(const char *symfile)
{
    sym_node node;
    char vm_addr[16];
    FILE *fp = fopen(symfile, "r");
    if (!fp)
        return -EM_FAULT;
    while (fscanf(fp, "%s%s%s", vm_addr, node.sym_type, node.symbol) != EOF)
    {
        sym_node *nd = new sym_node;
        *nd = node;
        nd->vm_addr = strtol(vm_addr, NULL, 16);
        nd->next = sym_list;
        sym_list = nd;
    }
    fclose(fp);
    return 0;
}

/**
 * Find a symbol by its virtual address.
 * @param addr Start address of target symbol.
 * @retval pointer to struct sym_node if succeeded.
 * @retval NULL if no matched.
 */
const Symtable::sym_node *Symtable::find(vm_addr_t addr)
{
    struct sym_node *node = sym_list;
    while (node)
    {
        if (node->vm_addr == addr)
        {
            return node;
        }
        node = node->next;
    }
    return NULL;
}
