#ifndef LIST_H_
#define LIST_H_

struct list
{
	struct list *next;
};

#define list_entry(node, type, member) \
	container_of(node, type, member)

#define list_init(node) \
	do \
	{ \
		(node)->next = NULL; \
	} while(0)

#define list_empty(node) \
	((node)->next == NULL)

#define list_next(node) \
	(node)->next

#define list_next_entry(node, type, member) \
	list_entry(list_next(node), type, member)

#define list_add(prev, node) \
	do \
	{ \
		(node)->next = (prev)->next; \
		(prev)->next = (node); \
	} while(0)

#define list_remove(prev, node) \
	do \
	{ \
		(prev)->next = (node)->next; \
	} while(0)

#define list_iterate(list, prev, cur) \
	for (struct list *prev = (list), *cur = list_next(prev); \
		cur; \
		prev = cur, cur = list_next(cur))

#endif /* LIST_H_ */
