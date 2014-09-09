#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <./utils/utils.h>

#include "const-c.inc"

MODULE = Thruk::Utils::XS		PACKAGE = Thruk::Utils::XS		

INCLUDE: const-xs.inc
