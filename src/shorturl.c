#include <string.h>
#include <stdio.h>

#include "shorturl.h"

static enum code_order determine_code_order(gchar c)
{
    if('0' <= c && c <= '9')
        return ASCII_NUMBER;
    else if('a' <= c && c <= 'z')
        return ASCII_LOWER;
    else if('A' <= c && c <= 'Z')
        return ASCII_UPPER;
    return ASCII_OTHER;
}

gint compare_codes(gchar *a, gchar *b)
{
    if(strlen(a) != strlen(b))
        return strlen(a) - strlen(b);

    guint i;
    for(i = 0; i < strlen(a); i++)
    {
        if(a[i] == b[i])
            continue;

        enum code_order code_order_a, code_order_b;

        code_order_a = determine_code_order(a[i]);
        code_order_b = determine_code_order(b[i]);

        if(code_order_a < code_order_b)
            return -1;
        else if(code_order_a > code_order_b)
            return 1;
        else
            return a[i] - b[i];
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

void free_shorturl_data(struct shorturl shorturl)
{
    g_free(shorturl.url);
}

void free_shorturl(struct shorturl *shorturl)
{
    free_shorturl_data(*shorturl);
    g_free(shorturl);
}
