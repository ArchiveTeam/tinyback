#include <stdio.h>
#include <string.h>

#include "glib.h"
#include "shorturl.h"

#define G_VERIFY_ERROR g_verify_error_quark()

GQuark g_verify_error_quark(void)
{
    return g_quark_from_static_string("g-verify-error-quark");
}

#define G_VERIFY_ERROR_FAILED 1 << 0
#define G_VERIFY_ERROR_PARSE 1 << 1
#define G_VERIFY_ERROR_UNSORTED 1 << 2

void verify_file(GIOChannel *in, GError **error_ptr)
{
    GError *error = NULL;
    gboolean eof;
    GString *buffer;
    gchar** split;
    gchar last_code[MAX_CODE_LENGTH + 1];

    buffer = g_string_new("");
    eof = FALSE;
    last_code[0] = '\0';

    while(!eof && error == NULL)
    {
        switch(g_io_channel_read_line_string(in, buffer, NULL, &error))
        {
            case G_IO_STATUS_NORMAL:
                split = g_strsplit(buffer->str, "|", 2);
                if(g_strv_length(split) != 2 || strlen(split[0]) > MAX_CODE_LENGTH)
                {
                    g_set_error(&error, G_VERIFY_ERROR, G_VERIFY_ERROR_PARSE, "No separator or code too long");
                    g_strfreev(split);
                    break;
                }

                if(compare_codes(last_code, split[0]) > 0)
                {
                    g_set_error(&error, G_VERIFY_ERROR, G_VERIFY_ERROR_UNSORTED, "Code %s after code %s", split[0], last_code);
                    g_strfreev(split);
                    break;
                }

                strncpy(last_code, split[0], MAX_CODE_LENGTH);
                g_strfreev(split);
                break;
            case G_IO_STATUS_EOF:
                eof = TRUE;
            case G_IO_STATUS_ERROR:
            case G_IO_STATUS_AGAIN:
                break;
        }
    }

    if(error != NULL)
        g_propagate_error(error_ptr, error);

    g_string_free(buffer, TRUE);
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
    GIOChannel *in;

    if(argc != 2)
    {
        printf("%s: <in-file>\n", argv[0]);
        return 2;
    }
    if(!g_file_test(argv[1], G_FILE_TEST_IS_REGULAR|G_FILE_TEST_EXISTS))
    {
        printf("Could not open in-file \"%s\"\n", argv[1]);
        return 1;
    }

    in = open_file(argv[1], "r", &error);
    if(error != NULL)
    {
        fprintf(stderr, "Unable to open file: %s\n", error->message);
        return 1;
    }

    verify_file(in, &error);
    if(error != NULL)
    {
        fprintf(stderr, "Unable to verify file: %s\n", error->message);
        g_io_channel_unref(in);
        return 1;
    }

    g_io_channel_unref(in);
    return 0;
}
