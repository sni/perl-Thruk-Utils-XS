#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "threadpool.h"

#if !defined TRUE
#define TRUE   1
#endif

#if !defined FALSE
#define FALSE  0
#endif

typedef struct pool_data_struct {
    int    num;
    char * key;
    char * socket;
    char * text;
} pool_data_t;

typedef struct pool_result_struct {
    int    num;
    char * key;
    int    success;
    char * result;
} pool_result_t;
