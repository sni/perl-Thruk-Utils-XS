#include "./utils.h"

threadpool_t *threadpool;
char ** pool_results_list;
int pool_results_nr;

/* store result of threads */
void main_func(void *s) {
    pool_results_list[pool_results_nr] = s;
    pool_results_nr++;
}

/* open local socket connection */
int open_local_socket(pool_data_t * pool_data, pool_result_t * pool_result) {
    struct sockaddr_un address;
    struct stat st;
    struct timeval tv;
    int input_socket;
    tv.tv_sec  = 5;  /* 5 seconds timeout should be enough for local sockets */
    tv.tv_usec = 0;

    if (0 != stat(pool_data->socket, &st)) {
        if(asprintf(&pool_result->result, "unix socket %s does not exist\n", pool_data->socket) == -1)
            croak("cannot allocate memory!");
        threadpool_schedule_back(threadpool, main_func, pool_result);
        return(-1);
    }

    if((input_socket=socket (PF_LOCAL, SOCK_STREAM, 0)) <= 0) {
        if(asprintf(&pool_result->result, "creating socket failed: %s\n", strerror(errno)) == -1)
            croak("cannot allocate memory!");
        threadpool_schedule_back(threadpool, main_func, pool_result);
        return(-1);
    }

    memset(&address, 0, sizeof(address));
    address.sun_family = AF_LOCAL;
    strcpy(address.sun_path, pool_data->socket);
    setsockopt(input_socket, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(input_socket, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    if(!connect(input_socket, (struct sockaddr *) &address, sizeof (address)) == 0) {
        if(asprintf(&pool_result->result, "connecting socket failed: %s\n", strerror(errno)) == -1)
            croak("cannot allocate memory!");
        threadpool_schedule_back(threadpool, main_func, pool_result);
        close(input_socket);
        return(-1);
    }
    return(input_socket);
}

void thread_func(void *raw) {
    char *r;
    time_t t;
    int wait;
    int input_socket;
    int size;
    int return_code;
    char buffer[14];
    char header[17];
    int result_size;
    int total_read;
    char *result_string;
    char *error_string;
    pool_data_t * data = (pool_data_t*)raw;
    pool_result_t *pool_result;
    char *send_header = "ResponseHeader: fixed16\nOutputFormat: wrapped_json\n\n"; /* dataset sep, column sep, list sep, host/svc list sep */

    pool_result = malloc(sizeof(pool_result_t));
    pool_result->key     = data->key;
    pool_result->num     = data->num;
    pool_result->success = FALSE;

    /* get data from socket */
    input_socket = open_local_socket(data, pool_result);
    if(input_socket == -1) { return; }
    size = send(input_socket, data->text, strlen(data->text), 0);
    if( size <= 0) {
        if(asprintf(&pool_result->result, "sending to socket failed : %s\n", strerror(errno)) == -1)
            croak("cannot allocate memory!");
        threadpool_schedule_back(threadpool, main_func, pool_result);
        close(input_socket);
        input_socket = -1;
        return;
    }
    if(data->text[strlen(data->text)-1] != '\n') {
        send(input_socket, "\n", 1, 0);
    }
    size = send(input_socket, send_header, strlen(send_header), 0);

    size = read(input_socket, header, 16);
    if( size < 16) {
        if(asprintf(&pool_result->result, "reading socket failed (%d bytes read): %s\n", size, strerror(errno)) == -1)
            croak("cannot allocate memory!");
        threadpool_schedule_back(threadpool, main_func, pool_result);
        close(input_socket);
        input_socket = -1;
        return;
    }
    if(size < 16 && size > 0) {
        if(asprintf(&pool_result->result, "got header: '%s'\n", header) == -1)
            croak("cannot allocate memory!");
        threadpool_schedule_back(threadpool, main_func, pool_result);
        close(input_socket);
        input_socket = -1;
        return;
    }
    header[size] = '\0';
    strncpy(buffer, header, 3);
    buffer[3] = '\0';
    return_code = atoi(buffer);
    if( return_code != 200) {
        if(asprintf(&pool_result->result, "query failed: %d\nquery:\n---\n%s\n---\n", return_code, data->text) == -1)
            croak("cannot allocate memory!");
        threadpool_schedule_back(threadpool, main_func, pool_result);
        close(input_socket);
        input_socket = -1;
        return;
    }

    strncpy(buffer, header+3, 13);
    result_size = atoi(buffer);
    if(result_size == 0) {
        return;
    }

    result_string   = malloc(sizeof(char*)*result_size+1);
    total_read      = 0;
    size            = 0;
    while(total_read < result_size) {
        size = read(input_socket, result_string+total_read, (result_size - total_read));
        total_read += size;
        if(size == 0)
            break;
    }
    if( size <= 0 || total_read != result_size) {
        if(asprintf(&pool_result->result, "reading socket failed (%d bytes read, expected %d): %s\n", total_read, result_size, strerror(errno)) == -1)
            croak("cannot allocate memory!");
        threadpool_schedule_back(threadpool, main_func, pool_result);
        free(result_string);
        close(input_socket);
        input_socket = -1;
        return;
    }
    result_string[total_read] = '\0';
    close(input_socket);

    struct timeval tv = {0, 1000};
    select(0, NULL, NULL, NULL, &tv);
    pool_result->result  = result_string;
    pool_result->success = TRUE;
    threadpool_schedule_back(threadpool, main_func, pool_result);
    free(data->socket);
    free(data->text);
    free(data);
}

void wakeup(void *pp) {
    int *p = (int*)pp;
    if(write(p[1], "a", 1) == -1)
        perror("write");
}

int socket_pool_work(int poolsize, char ** data, int numdata, char ** pool_results) {
    int i, rc;
    int p[2];
    int done;
    rc = pipe(p);
    if(rc < 0) {
        perror("pipe");
        exit(1);
    }
    pool_results_list = pool_results;
    threadpool = threadpool_create(poolsize, wakeup, (void*)p);
    if(threadpool == NULL) {
        perror("threadpool_create");
        exit(1);
    }

    pool_results_nr = 0;
    for(i = 0; i < numdata; i=i+4) {
        pool_data_t *pool_data;
        pool_data = malloc(sizeof(pool_data_t));
        pool_data->num    = atoi(data[i]);
        pool_data->key    = data[i+1];
        pool_data->socket = data[i+2];
        pool_data->text   = data[i+3];
        fd_set fdset;
        char buf[10];
        struct timeval tv = {0, 100};
        FD_ZERO(&fdset);
        FD_SET(p[0], &fdset);
        rc = threadpool_schedule(threadpool, thread_func, (void*)pool_data);
        if(rc < 0) {
            perror("threadpool_schedule");
            exit(1);
        }
        rc = select(p[0] + 1, &fdset, NULL, NULL, &tv);
        if(rc < 0) {
            perror("select");
            exit(1);
        }
        if(rc > 0) {
            if(read(p[0], buf, 10) == -1)
                perror("read");
            threadpool_run_callbacks(threadpool);
        }
    }
    do {
        done = threadpool_die(threadpool, 1);
        threadpool_run_callbacks(threadpool);
    } while(!done);

    rc = threadpool_destroy(threadpool);
    if(rc < 0)
        abort();
    close(p[0]);
    close(p[1]);
    return pool_results_nr;
}
