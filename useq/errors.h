#ifndef ERRORS_H_
#define ERRORS_H_

#define N_SUCCESS(rc) (rc>=0)
#define N_FAIL(rc) (!N_SUCCESS(rc))

#define ERR_MPOOL_ALLOC 1

#endif /* ERRORS_H_ */
