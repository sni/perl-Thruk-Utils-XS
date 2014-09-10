#include "./utils.h"

threadpool_t *threadpool;
char * pool_results[MAX_POOL_SIZE];
int pool_results_nr;

/* open local socket connection */
int open_local_socket(char *socket_path) {
    struct sockaddr_un address;
    struct stat st;
    struct timeval tv;
    int input_socket;
    tv.tv_sec  = 5;  /* 5 seconds timeout should be enough for local sockets */
    tv.tv_usec = 0;

    if (0 != stat(socket_path, &st)) {
        printf("no unix socket %s existing\n", socket_path);
        return(-1);
    }

    if((input_socket=socket (PF_LOCAL, SOCK_STREAM, 0)) <= 0) {
        printf("creating socket failed: %s\n", strerror(errno));
        return(-1);
    }

    memset(&address, 0, sizeof(address));
    address.sun_family = AF_LOCAL;
    strcpy(address.sun_path, socket_path);
    setsockopt(input_socket, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(input_socket, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    if(!connect(input_socket, (struct sockaddr *) &address, sizeof (address)) == 0) {
        printf("connecting socket failed: %s\n", strerror(errno));
        close(input_socket);
        return(-1);
    }
    return(input_socket);
}

void main_func(void *s) {
    pool_results[pool_results_nr] = s;
    pool_results_nr++;
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
    pool_data_t * data = (pool_data_t*)raw;
    char *send_header = "ResponseHeader: fixed16\nOutputFormat: wrapped_json\n\n"; /* dataset sep, column sep, list sep, host/svc list sep */

    /* get data from socket */
    input_socket = open_local_socket(data->socket);
    if(input_socket == -1) { return; }
    size = send(input_socket, data->text, strlen(data->text), 0);
    if( size <= 0) {
        printf("sending to socket failed : %s\n", strerror(errno));
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
        printf("reading socket failed (%d bytes read): %s\n", size, strerror(errno));
        if(size > 0)
            printf("got header: '%s'\n", header);
        close(input_socket);
        input_socket = -1;
        return;
    }
    header[size] = '\0';
    strncpy(buffer, header, 3);
    buffer[3] = '\0';
    return_code = atoi(buffer);
    if( return_code != 200) {
        printf("query failed: %d\nquery:\n---\n%s\n---\n", return_code, data->text);
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
        printf("reading socket failed (%d bytes read, expected %d): %s\n", total_read, result_size, strerror(errno));
        free(result_string);
        close(input_socket);
        input_socket = -1;
        return;
    }
    result_string[total_read] = '\0';
    close(input_socket);

    struct timeval tv = {0, 1000};
    select(0, NULL, NULL, NULL, &tv);
    threadpool_schedule_back(threadpool, main_func, result_string);
    free(data->socket);
    free(data->text);
    free(data);
}

void wakeup(void *pp) {
    int *p = (int*)pp;
    if(write(p[1], "a", 1) == -1)
        perror("write");
}

int pool_work(int poolsize, char ** data, int numdata) {
    int i, rc;
    int p[2];
    int done;
    rc = pipe(p);
    if(rc < 0) {
        perror("pipe");
        exit(1);
    }
    threadpool = threadpool_create(poolsize, wakeup, (void*)p);
    if(threadpool == NULL) {
        perror("threadpool_create");
        exit(1);
    }

    pool_results_nr = 0;
    for(i = 1; i <= numdata; i=i+2) {
        pool_data_t *pool_data;
        pool_data = malloc(sizeof(pool_data_t));
        pool_data->socket = data[i-1];
        pool_data->text   = data[i];
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
    return 0;
}
