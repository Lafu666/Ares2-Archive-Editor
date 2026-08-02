//  minizip.h
//  Ares2ToolBox
//  iOS ZIP 操作封装（基于 zlib）
//

#ifndef MINIZIP_H
#define MINIZIP_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

bool minizip_unzip(const char *zip_path, const char *dest_dir);
bool minizip_zip_folder(const char *folder_path, const char *zip_path);

#ifdef __cplusplus
}
#endif

#endif