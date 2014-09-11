#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <./utils/utils.h>

#include "const-c.inc"

MODULE = Thruk::Utils::XS		PACKAGE = Thruk::Utils::XS

INCLUDE: const-xs.inc

SV * socket_pool_do(size, data)
    int     size
    SV    * data

    INIT:
        char ** arg;
        AV * results;
        SSize_t numresults = 0, n;
        int i;
        char ** pool_results;
        int pool_results_nr;
        SvGETMAGIC(data);
        if ((!SvROK(data))
            || (SvTYPE(SvRV(data)) != SVt_PVAV)
            || ((numresults = av_len((AV *)SvRV(data))) < 0))
        {
            XSRETURN_UNDEF;
        }
        numresults++; // increase by one to get the size, not the last index
        results = (AV *)sv_2mortal((SV *)newAV());
        pool_results = malloc(numresults / 4 * sizeof(char*));
    CODE:
        arg = malloc(numresults * sizeof(char*));
        for(n=0; n < numresults; n++) {
            STRLEN l;
            arg[n] = strdup(SvPV(*av_fetch((AV *)SvRV(data), n, 0), l));
        }
        pool_results_nr = socket_pool_work(size, arg, numresults, pool_results);
        free(arg);
        for(n = 0; n < pool_results_nr; n++) {
            HV * rh;
            pool_result_t * result = (pool_result_t*)pool_results[n];
            rh = (HV *)sv_2mortal((SV *)newHV());

            hv_store(rh, "num",     3, newSVnv(result->num),                              0);
            hv_store(rh, "key",     3, newSVpv(result->key, strlen(result->key)),         0);
            hv_store(rh, "success", 7, newSVnv(result->success),                          0);
            hv_store(rh, "result",  6, newSVpv(result->result, strlen(result->result)),   0);

            av_push(results, newRV((SV *)rh));
            free(result->key);
            free(result->result);
            free(result);
        }
        free(pool_results);
        RETVAL = newRV((SV *)results);
    OUTPUT:
        RETVAL
