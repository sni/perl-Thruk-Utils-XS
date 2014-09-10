#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <./utils/utils.h>

#include "const-c.inc"

extern char * pool_results[MAX_POOL_SIZE];
extern int pool_results_nr;

MODULE = Thruk::Utils::XS		PACKAGE = Thruk::Utils::XS

INCLUDE: const-xs.inc

SV * socket_pool_do(size, data)
    int     size
    SV    * data

    INIT:
        char * arg[MAX_POOL_SIZE];
        AV * results;
        SSize_t numresults = 0, n;
        int i;
        SvGETMAGIC(data);
        if ((!SvROK(data))
            || (SvTYPE(SvRV(data)) != SVt_PVAV)
            || ((numresults = av_len((AV *)SvRV(data))) < 0))
        {
            XSRETURN_UNDEF;
        }
        results = (AV *)sv_2mortal((SV *)newAV());
    CODE:
        for(n = 0; n <= numresults; n++) {
            STRLEN l;
            arg[n] = strdup(SvPV(*av_fetch((AV *)SvRV(data), n, 0), l));
        }
        pool_work(size, arg, numresults);
        for(n = 0; n < pool_results_nr; n++) {
            av_push(results, newSVpv(pool_results[n], strlen(pool_results[n])));
            free(pool_results[n]);
        }
        RETVAL = newRV((SV *)results);
    OUTPUT:
        RETVAL

