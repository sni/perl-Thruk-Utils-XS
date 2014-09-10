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

#define MAX_POOL_SIZE 1000

typedef struct pool_data_struct {
    char * socket;
    char * text;
} pool_data_t;
