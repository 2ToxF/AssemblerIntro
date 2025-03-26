#ifndef PATCHER_H
#define PATCHER_H

enum PatchResultType
{
    SUCCESS_CRACK = 0,
    UNKNOWN_FILE_NAME,
};

const char* const KNOWN_FILE_NAME = "CrackPassword/CRACKME.COM";

PatchResultType FilePatch(const char* file_name);

#endif //PATCHER_H
