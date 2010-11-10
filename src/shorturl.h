#ifndef SHORTURL_H

#include "glib.h"

#define MAX_CODE_LENGTH 6

struct shorturl {
    gchar code[MAX_CODE_LENGTH + 1];
    gchar* url;
};

gint compare_codes(gchar *a, gchar *b);
gint compare_shorturls(gconstpointer *ptr_a, gconstpointer *ptr_b);

#endif
