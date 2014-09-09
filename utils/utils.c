#include "./utils.h"

threadpool_t *threadpool;
char * pool_results[MAX_POOL_SIZE];
int pool_results_nr;

void main_func(void *s) {
    pool_results[pool_results_nr] = s;
    pool_results_nr++;
    //free(s);
}

void thread_func(void *raw) {
    char *r;
    time_t t;
    int wait;
    pool_data_t * data = (pool_data_t*)raw;

    //sleep(1);
    usleep(30000);
    asprintf(&r, "thread return text %s, plus waited 1", data->socket);


    struct timeval tv = {0, 1000};
    select(0, NULL, NULL, NULL, &tv);
    threadpool_schedule_back(threadpool, main_func, r);
    free(data->socket);
    free(data->text);
    free(data);
}

void wakeup(void *pp) {
    int *p = (int*)pp;
    write(p[1], "a", 1);
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
            read(p[0], buf, 10);
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
