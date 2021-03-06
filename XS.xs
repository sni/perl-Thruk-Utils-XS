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



SV * parse_line(str)
    SV * str

    INIT:
        STRLEN len;
        HV * result = (HV *)sv_2mortal((SV *)newHV());
        const char * line;
        char * _msg;
        char * _dup;
        char * _options;
        char * _text;
        char * _host;
        char * _service;
        char * _plugin_output;
        char * _state;
        char * _hard;
        char * _timeperiod;
        char * _from;
        char * _to;
        char * _contact;
        int    _time;
        int    _utf8;

    CODE:
        line  = SvPV(str, len);
        _msg  = strdup(line);
        _dup  = _msg;
        _utf8 = SvUTF8(str);

        /* trim line */
        while (len > 0 && isspace(_msg[len-1]))
            _msg[--len] = '\0';
        if (len < 13 || _msg[0] != '[' || _msg[11] != ']') {
            free(_dup);
            XSRETURN_UNDEF;
            return;
        }
        /* extract timestamp */
        _msg[11] = 0;
        _time    = atoi(_msg+1);
        hv_store(result, "time", 4, newSVnv(_time), 0);

        _text    = _msg + 13;
        _options = strstr(_text, ": ");
        if(!_options) {
            /* no options founds, could be start/stop */
            SV * _text_sv = newSVpv(_text, strlen(_text)); if(_utf8) { SvUTF8_on(_text_sv); }
            hv_store(result, "type",  4, _text_sv,   0);
            if(strstr(_text, " starting...")) {
                hv_store(result, "proc_start",  10, newSVnv(1),   0);
            }
            else if(strstr(_text, " restarting...")) {
                hv_store(result, "proc_start",  10, newSVnv(2),   0);
            }
            else if(strstr(_text, "shutting down...")) {
                hv_store(result, "proc_start",  10, newSVnv(0),   0);
            }
            else if(strstr(_text, "Bailing out")) {
                hv_store(result, "proc_start",  10, newSVnv(-1),   0);
            }
        } else {
            SV * _text_sv = newSVpv(_text, strlen(_text)-strlen(_options)); if(_utf8) { SvUTF8_on(_text_sv); }
            hv_store(result, "type",  4, _text_sv,   0);
            _options += 2;
            if(   !strncmp(_text, "SERVICE ALERT:", 14)
               || !strncmp(_text, "CURRENT SERVICE STATE:", 22)
               || !strncmp(_text, "INITIAL SERVICE STATE:", 22)
            ) {
                _host          = strsep(&_options, ";");
                _service       = strsep(&_options, ";");
                _state         = strsep(&_options, ";");
                _hard          = strsep(&_options, ";");
                                 strsep(&_options, ";"); /* attempts */
                _plugin_output = strsep(&_options, ";");
                SV * _hst_sv   = newSVpv(_host, strlen(_host));                   if(_utf8) { SvUTF8_on(_hst_sv); }
                SV * _svc_sv   = newSVpv(_service, strlen(_service));             if(_utf8) { SvUTF8_on(_svc_sv); }
                SV * _out_sv   = newSVpv(_plugin_output, strlen(_plugin_output)); if(_utf8) { SvUTF8_on(_out_sv); }
                hv_store(result, "host_name",            9, _hst_sv,   0);
                hv_store(result, "service_description", 19, _svc_sv,   0);
                hv_store(result, "hard",                 4, newSVnv(!strncmp(_hard, "HARD", 4) ? 1:0),   0);
                hv_store(result, "plugin_output",       13, _out_sv,   0);
                if(     !strncmp(_state, "OK",       2)) { hv_store(result, "state",  5, newSVnv(0),   0); }
                else if(!strncmp(_state, "WARNING",  7)) { hv_store(result, "state",  5, newSVnv(1),   0); }
                else if(!strncmp(_state, "CRITICAL", 8)) { hv_store(result, "state",  5, newSVnv(2),   0); }
                else if(!strncmp(_state, "UNKNOWN",  7)) { hv_store(result, "state",  5, newSVnv(3),   0); }
            }
            else
            if(   !strncmp(_text, "HOST ALERT:", 11)
               || !strncmp(_text, "CURRENT HOST STATE:", 19)
               || !strncmp(_text, "INITIAL HOST STATE:", 19)
            ) {
                _host          = strsep(&_options, ";");
                _state         = strsep(&_options, ";");
                _hard          = strsep(&_options, ";");
                                 strsep(&_options, ";"); /* attempts */
                _plugin_output = strsep(&_options, ";");
                SV * _hst_sv   = newSVpv(_host, strlen(_host));                   if(_utf8) { SvUTF8_on(_hst_sv); }
                SV * _out_sv   = newSVpv(_plugin_output, strlen(_plugin_output)); if(_utf8) { SvUTF8_on(_out_sv); }
                hv_store(result, "host_name",      9, _hst_sv,   0);
                hv_store(result, "hard",           4, newSVnv(!strncmp(_hard, "HARD", 4) ? 1:0),   0);
                hv_store(result, "plugin_output", 13, _out_sv,   0);
                if(     !strncmp(_state, "UP",           2)) { hv_store(result, "state",  5, newSVnv(0),   0); }
                else if(!strncmp(_state, "DOWN",         4)) { hv_store(result, "state",  5, newSVnv(1),   0); }
                else if(!strncmp(_state, "UNREACHABLE", 11)) { hv_store(result, "state",  5, newSVnv(2),   0); }
            }
            else
            if(!strncmp(_text, "HOST DOWNTIME ALERT:", 20)) {
                _host          = strsep(&_options, ";");
                _state         = strsep(&_options, ";");
                SV * _hst_sv   = newSVpv(_host, strlen(_host));                   if(_utf8) { SvUTF8_on(_hst_sv); }
                hv_store(result, "host_name",  9, _hst_sv,   0);
                hv_store(result, "start",      5, newSVnv(!strncmp(_state, "STARTED", 7) ? 1:0),   0);
            }
            else
            if(!strncmp(_text, "SERVICE DOWNTIME ALERT:", 23)) {
                _host          = strsep(&_options, ";");
                _service       = strsep(&_options, ";");
                _state         = strsep(&_options, ";");
                SV * _hst_sv   = newSVpv(_host, strlen(_host));                   if(_utf8) { SvUTF8_on(_hst_sv); }
                SV * _svc_sv   = newSVpv(_service, strlen(_service));             if(_utf8) { SvUTF8_on(_svc_sv); }
                hv_store(result, "host_name",             9, _hst_sv,   0);
                hv_store(result, "service_description",  19, _svc_sv,   0);
                hv_store(result, "start",                 5, newSVnv(!strncmp(_state, "STARTED", 7) ? 1:0),   0);
            }
            if(!strncmp(_text, "TIMEPERIOD TRANSITION", 21)) {
                _timeperiod = strsep(&_options, ";");
                _from       = strsep(&_options, ";");
                _to         = strsep(&_options, ";");
                SV * _time_sv  = newSVpv(_timeperiod, strlen(_timeperiod));       if(_utf8) { SvUTF8_on(_time_sv); }
                hv_store(result, "timeperiod",  10, _time_sv,   0);
                hv_store(result, "from",         4, newSVpv(_from, strlen(_from)),   0);
                hv_store(result, "to",           2, newSVpv(_to, strlen(_to)),   0);
            }
            else
            if(!strncmp(_text, "SERVICE NOTIFICATION:", 21)) {
                _contact       = strsep(&_options, ";");
                _host          = strsep(&_options, ";");
                _service       = strsep(&_options, ";");
                                 strsep(&_options, ";");
                                 strsep(&_options, ";");
                _plugin_output = strsep(&_options, ";");
                SV * _hst_sv   = newSVpv(_host, strlen(_host));                   if(_utf8) { SvUTF8_on(_hst_sv); }
                SV * _svc_sv   = newSVpv(_service, strlen(_service));             if(_utf8) { SvUTF8_on(_svc_sv); }
                SV * _con_sv   = newSVpv(_contact, strlen(_contact));             if(_utf8) { SvUTF8_on(_con_sv); }
                SV * _out_sv   = newSVpv(_plugin_output, strlen(_plugin_output)); if(_utf8) { SvUTF8_on(_out_sv); }
                hv_store(result, "host_name",             9, _hst_sv, 0);
                hv_store(result, "service_description",  19, _svc_sv,  0);
                hv_store(result, "contact_name",         12, _con_sv,  0);
                hv_store(result, "plugin_output",        13, _out_sv,  0);
            }
            else
            if(!strncmp(_text, "HOST NOTIFICATION:", 18)) {
                _contact       = strsep(&_options, ";");
                _host          = strsep(&_options, ";");
                                 strsep(&_options, ";");
                                 strsep(&_options, ";");
                _plugin_output = strsep(&_options, ";");
                SV * _hst_sv   = newSVpv(_host, strlen(_host));                   if(_utf8) { SvUTF8_on(_hst_sv); }
                SV * _con_sv   = newSVpv(_contact, strlen(_contact));             if(_utf8) { SvUTF8_on(_con_sv); }
                SV * _out_sv   = newSVpv(_plugin_output, strlen(_plugin_output)); if(_utf8) { SvUTF8_on(_out_sv); }
                hv_store(result, "host_name",       9, _hst_sv, 0);
                hv_store(result, "contact_name",   12, _con_sv, 0);
                hv_store(result, "plugin_output",  13, _out_sv, 0);
            }
        }

        free(_dup);
        RETVAL = newRV((SV *)result);
    OUTPUT:
        RETVAL
