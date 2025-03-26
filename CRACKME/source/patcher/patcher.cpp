#include <stdio.h>
#include <string.h>

#include "patcher.h"

const int OFFSET        = 0x3d;
const int FIRST_BYTE    = 0xeb;
const int SECOND_BYTE   = 0x11;

static void ReplaceFileBytes(FILE* file_ptr);


static void ReplaceFileBytes(FILE* file_ptr)
{
    fseek(file_ptr, OFFSET, SEEK_SET);
    fputc(FIRST_BYTE, file_ptr);
    fputc(SECOND_BYTE, file_ptr);
}


PatchResultType FilePatch(const char* file_name)
{
    if (strcmp(file_name, KNOWN_FILE_NAME) != 0)
        return UNKNOWN_FILE_NAME;

    FILE* file_to_crack = fopen(file_name, "r+b");
    if (file_to_crack == NULL)
        return UNKNOWN_FILE_NAME;

    ReplaceFileBytes(file_to_crack);
    return SUCCESS_CRACK;
}
