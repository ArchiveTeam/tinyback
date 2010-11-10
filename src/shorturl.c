#include <string.h>

#include "shorturl.h"

gint compare_codes(gchar *a, gchar *b)
{
    if(strlen(a) != strlen(b))
        return strlen(a) - strlen(b);

    guint i;
    gint diff;
    for(i = 0; i < strlen(a); i++)
    {
        diff = (gint)(g_ascii_isdigit(b[i])) - (gint)(g_ascii_isdigit(a[i]));
        if(diff)
            return diff;
        diff = a[i] - b[i];
        if(diff)
            return diff;

        diff = (gint)(g_ascii_islower(b[i])) - (gint)(g_ascii_islower(a[i]));
        if(diff)
            return diff;
        diff = a[i] - b[i];
        if(diff)
            return diff;

        diff = (gint)(g_ascii_isupper(b[i])) - (gint)(g_ascii_isupper(a[i]));
        if(diff)
            return diff;
        diff = a[i] - b[i];
        if(diff)
            return diff;
    }

    return 0;
}

gint compare_shorturls(gconstpointer *ptr_a, gconstpointer *ptr_b)
{
    gchar *a, *b;

    a = ((struct shorturl *)ptr_a)->code;
    b = ((struct shorturl *)ptr_b)->code;

    return compare_codes(a, b);
}
