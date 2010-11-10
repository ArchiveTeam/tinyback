#include <stdio.h>
#include <string.h>

#include "glib.h"
#include "shorturl.h"

#define MAX_DISTANCE 2000000

#define G_SORT_ERROR g_sort_error_quark()

GQuark g_sort_error_quark(void)
{
    return g_quark_from_static_string("g-sort-error-quark");
}

#define G_SORT_ERROR_FAILED 1 << 0
#define G_SORT_ERROR_PARSE 1 << 1
#define G_SORT_ERROR_UNSORTED 1 << 2

guint read_shorturls(GIOChannel *in, GArray *data, guint count, GError **error_ptr)
{
    GError *error = NULL;
    guint read;
    gboolean eof;
    GString *buffer;
    gchar** split;
    struct shorturl shorturl;

    buffer = g_string_new("");
    eof = FALSE;

    for(read = 0; read < count && !eof && error == NULL; read++)
    {
        switch(g_io_channel_read_line_string(in, buffer, NULL, &error))
        {
            case G_IO_STATUS_NORMAL:
                split = g_strsplit(buffer->str, "|", 2);
                if(g_strv_length(split) != 2 || strlen(split[0]) > MAX_CODE_LENGTH)
                {
                    g_set_error(&error, G_SORT_ERROR, G_SORT_ERROR_PARSE, "No separator or code too long");
                    g_strfreev(split);
                    break;
                }

                strncpy(shorturl.code, split[0], MAX_CODE_LENGTH);
                shorturl.url = g_strndup(split[1], strlen(split[1]) - 1);

                g_strfreev(split);

                g_array_append_val(data, shorturl);
                break;
            case G_IO_STATUS_EOF:
                eof = TRUE;
            case G_IO_STATUS_ERROR:
            case G_IO_STATUS_AGAIN:
                read--;
                break;
        }
    }

    if(error != NULL)
        g_propagate_error(error_ptr, error);

    g_string_free(buffer, TRUE);

    return read;
}

GArray *write_file(GIOChannel *out, GArray *data, guint count, gchar *last_code, GError **error_ptr)
{
    GError *error = NULL;
    guint written;
    struct shorturl shorturl;
    GString *buffer;
    gsize bytes_written;

    buffer = g_string_new("");

    shorturl = g_array_index(data, struct shorturl, 0);
    if(compare_codes(last_code, shorturl.code) > 0)
        g_set_error(&error, G_SORT_ERROR, G_SORT_ERROR_UNSORTED, "The max distance value is too small");

    for(written = 0; written < count && written < data->len && error == NULL; written++)
    {
        shorturl = g_array_index(data, struct shorturl, written);
        g_string_sprintf(buffer, "%s|%s\n", shorturl.code, shorturl.url);
        switch(g_io_channel_write_chars(out, buffer->str, -1, &bytes_written, &error))
        {
            case G_IO_STATUS_NORMAL:
                g_free(shorturl.url);
                break;
            case G_IO_STATUS_EOF:
            case G_IO_STATUS_ERROR:
                if(error == NULL)
                    g_set_error(&error, G_SORT_ERROR, G_SORT_ERROR_FAILED, "Error writing to file");
                break;
            case G_IO_STATUS_AGAIN:
                written--;
                break;
        }
    }
    g_strlcpy(last_code, shorturl.code, MAX_CODE_LENGTH + 1);

    if(error != NULL)
        g_propagate_error(error_ptr, error);

    g_string_free(buffer, TRUE);

    return g_array_remove_range(data, 0, written);
}

GIOChannel *open_file(gchar* name, gchar* mode, GError **error_ptr)
{
    GIOChannel *io_channel;
    GError *error = NULL;

    io_channel = g_io_channel_new_file(name, mode, &error);
    if(error != NULL)
    {
        g_propagate_error(error_ptr, error);
        return NULL;
    }

    g_io_channel_set_encoding(io_channel, NULL, &error);
    if(error != NULL)
    {
        g_propagate_error(error_ptr, error);
        return NULL;
    }
    g_io_channel_set_line_term(io_channel, "\n", -1);

    return io_channel;
}

int main(int argc, char* argv[])
{
    GError *error = NULL;
    GIOChannel *in, *out;
    GArray *data;
    guint read;
    gchar last_code[MAX_CODE_LENGTH + 1];

    if(argc != 3)
    {
        printf("%s: <in-file> <out-file>\n", argv[0]);
        return 2;
    }
    if(!g_file_test(argv[1], G_FILE_TEST_IS_REGULAR|G_FILE_TEST_EXISTS))
    {
        printf("Could not open in-file \"%s\"\n", argv[1]);
        return 1;
    }
    if(g_file_test(argv[2], G_FILE_TEST_EXISTS))
    {
        printf("Out-file already exists \"%s\"\n", argv[2]);
        return 1;
    }

    in = open_file(argv[1], "r", &error);
    if(error != NULL)
    {
        fprintf(stderr, "Unable to open file: %s\n", error->message);
        return 1;
    }

    data = g_array_new(FALSE, FALSE, sizeof(struct shorturl));

    read = read_shorturls(in, data, MAX_DISTANCE, &error);
    if(error != NULL)
    {
        g_io_channel_unref(in);
        fprintf(stderr, "Unable to read shorturls: %s\n", error->message);
        return 1;
    }
    if(read == 0)
    {
        g_io_channel_unref(in);
        fprintf(stderr, "No data in input file\n");
        return 1;
    }

    out = open_file(argv[2], "w", &error);
    if(error != NULL)
    {
        fprintf(stderr, "Unable to open file: %s\n", error->message);
        return 1;
    }

    last_code[0] = '\0';
    do
    {
        read = read_shorturls(in, data, MAX_DISTANCE, &error);
        if(error != NULL)
        {
            g_io_channel_unref(in);
            g_io_channel_unref(out);
            fprintf(stderr, "Unable to read shorturls: %s\n", error->message);
            return 1;
        }

        g_array_sort(data, (GCompareFunc)&compare_shorturls);

        if(data->len > MAX_DISTANCE)
        {
            data = write_file(out, data, data->len - MAX_DISTANCE, last_code, &error);
            if(error != NULL)
            {
                g_io_channel_unref(in);
                g_io_channel_unref(out);
                fprintf(stderr, "Unable to write shorturls: %s\n", error->message);
                return 1;
            }
        }
        printf("Loop: %i\n", read);
    } while(read > 0);

    data = write_file(out, data, data->len, last_code, &error);
    if(error != NULL)
    {
        g_io_channel_unref(out);
        fprintf(stderr, "Unable to write shorturls: %s\n", error->message);
        return 1;
    }

    g_io_channel_unref(out);
    g_array_free(data, TRUE);

    return 0;
}
