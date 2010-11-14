#ifndef SHORTURL_H

#define SHORTURL_H

#include "glib.h"

#define MAX_CODE_LENGTH 6

enum code_order
{
    ASCII_NUMBER,
    ASCII_LOWER,
    ASCII_UPPER,
    ASCII_OTHER
};

struct shorturl {
    gchar code[MAX_CODE_LENGTH + 1];
    gchar* url;
};

gint compare_codes(gchar *a, gchar *b);
gint compare_shorturls(gconstpointer *ptr_a, gconstpointer *ptr_b);
void free_shorturl_data(struct shorturl shorturl);
void free_shorturl(struct shorturl *shorturl);

#endif
