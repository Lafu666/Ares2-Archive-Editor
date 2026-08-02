//  minizip.c
//  Ares2ToolBox
//  iOS ZIP 操作实现（基于 zlib deflate/inflate + crc32）
//

#include "minizip.h"
#include <zlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>
#include <time.h>

// ============================================================================
// ZIP 格式常量
// ============================================================================
#define LOCAL_FILE_HEADER_SIG       0x04034b50
#define CENTRAL_DIR_HEADER_SIG      0x02014b50
#define END_OF_CENTRAL_DIR_SIG      0x06054b50
#define LOCAL_FILE_HEADER_SIZE      30
#define CENTRAL_DIR_HEADER_SIZE     46
#define END_OF_CENTRAL_DIR_SIZE     22
#define COMPRESSION_STORE           0
#define COMPRESSION_DEFLATE         8

// ============================================================================
// 小端序读写
// ============================================================================
static uint32_t read_u32(const uint8_t *buf) {
    return (uint32_t)buf[0] | ((uint32_t)buf[1] << 8) |
           ((uint32_t)buf[2] << 16) | ((uint32_t)buf[3] << 24);
}

static uint16_t read_u16(const uint8_t *buf) {
    return (uint16_t)buf[0] | ((uint16_t)buf[1] << 8);
}

static void write_u32(uint8_t *buf, uint32_t val) {
    buf[0] = val & 0xFF; buf[1] = (val >> 8) & 0xFF;
    buf[2] = (val >> 16) & 0xFF; buf[3] = (val >> 24) & 0xFF;
}

static void write_u16(uint8_t *buf, uint16_t val) {
    buf[0] = val & 0xFF; buf[1] = (val >> 8) & 0xFF;
}

// ============================================================================
// 辅助函数
// ============================================================================
static bool ensure_dir(const char *path) {
    char tmp[4096];
    strncpy(tmp, path, sizeof(tmp) - 1);
    tmp[sizeof(tmp) - 1] = '\0';
    size_t len = strlen(tmp);
    if (len > 0 && tmp[len - 1] == '/') tmp[len - 1] = '\0';

    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(tmp, 0755);
            *p = '/';
        }
    }
    mkdir(tmp, 0755);
    return true;
}

static bool is_directory(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return false;
    return S_ISDIR(st.st_mode);
}

static uint8_t *read_file_data(const char *path, size_t *out_len) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    if (len <= 0) { fclose(f); return NULL; }
    fseek(f, 0, SEEK_SET);
    uint8_t *data = (uint8_t *)malloc(len);
    if (!data) { fclose(f); return NULL; }
    size_t rd = fread(data, 1, len, f);
    fclose(f);
    if (rd != (size_t)len) { free(data); return NULL; }
    *out_len = len;
    return data;
}

static bool write_file_data(const char *path, const uint8_t *data, size_t len) {
    FILE *f = fopen(path, "wb");
    if (!f) return false;
    size_t wr = fwrite(data, 1, len, f);
    fclose(f);
    return wr == len;
}

// ============================================================================
// 解压 ZIP
// ============================================================================
bool minizip_unzip(const char *zip_path, const char *dest_dir) {
    size_t zip_len = 0;
    uint8_t *zip_data = read_file_data(zip_path, &zip_len);
    if (!zip_data || zip_len < END_OF_CENTRAL_DIR_SIZE) return false;

    // 查找 EOCD
    int64_t eocd_offset = -1;
    for (int64_t i = (int64_t)zip_len - END_OF_CENTRAL_DIR_SIZE; i >= 0; i--) {
        if (read_u32(zip_data + i) == END_OF_CENTRAL_DIR_SIG) {
            eocd_offset = i;
            break;
        }
    }
    if (eocd_offset < 0) { free(zip_data); return false; }

    uint16_t total_entries = read_u16(zip_data + eocd_offset + 10);
    uint32_t cd_offset = read_u32(zip_data + eocd_offset + 16);

    ensure_dir(dest_dir);

    // 遍历 Central Directory
    uint32_t cd_pos = cd_offset;
    for (uint16_t e = 0; e < total_entries; e++) {
        if (cd_pos + CENTRAL_DIR_HEADER_SIZE > zip_len) break;
        if (read_u32(zip_data + cd_pos) != CENTRAL_DIR_HEADER_SIG) break;

        uint16_t comp_method = read_u16(zip_data + cd_pos + 10);
        uint32_t crc32_val = read_u32(zip_data + cd_pos + 16);
        uint32_t comp_size = read_u32(zip_data + cd_pos + 20);
        uint32_t uncomp_size = read_u32(zip_data + cd_pos + 24);
        uint16_t name_len = read_u16(zip_data + cd_pos + 28);
        uint16_t extra_len = read_u16(zip_data + cd_pos + 30);
        uint32_t local_offset = read_u32(zip_data + cd_pos + 42);

        // 读取文件名
        char filename[1024];
        if (name_len >= sizeof(filename)) { free(zip_data); return false; }
        memcpy(filename, zip_data + cd_pos + CENTRAL_DIR_HEADER_SIZE, name_len);
        filename[name_len] = '\0';

        // 跳过目录
        if (filename[name_len - 1] == '/') {
            char dir_path[4096];
            snprintf(dir_path, sizeof(dir_path), "%s/%s", dest_dir, filename);
            ensure_dir(dir_path);
            cd_pos += CENTRAL_DIR_HEADER_SIZE + name_len + extra_len;
            continue;
        }

        // 定位 Local File Header
        if (local_offset + LOCAL_FILE_HEADER_SIZE > zip_len) { free(zip_data); return false; }
        uint16_t local_name_len = read_u16(zip_data + local_offset + 26);
        uint16_t local_extra_len = read_u16(zip_data + local_offset + 28);
        uint32_t data_offset = local_offset + LOCAL_FILE_HEADER_SIZE + local_name_len + local_extra_len;

        if (data_offset + comp_size > zip_len) { free(zip_data); return false; }
        const uint8_t *comp_data = zip_data + data_offset;

        // 写出文件路径
        char out_path[4096];
        snprintf(out_path, sizeof(out_path), "%s/%s", dest_dir, filename);

        // 确保父目录存在
        char *last_slash = strrchr(out_path, '/');
        if (last_slash) {
            *last_slash = '\0';
            ensure_dir(out_path);
            *last_slash = '/';
        }

        bool ok = false;
        if (comp_method == COMPRESSION_STORE) {
            ok = write_file_data(out_path, comp_data, comp_size);
        } else if (comp_method == COMPRESSION_DEFLATE) {
            // 使用 zlib inflate
            uint8_t *uncomp = (uint8_t *)malloc(uncomp_size);
            if (uncomp) {
                z_stream strm;
                memset(&strm, 0, sizeof(strm));
                strm.next_in = (Bytef *)comp_data;
                strm.avail_in = (uInt)comp_size;
                strm.next_out = uncomp;
                strm.avail_out = (uInt)uncomp_size;

                if (inflateInit2(&strm, -MAX_WBITS) == Z_OK) {
                    int ret = inflate(&strm, Z_FINISH);
                    if (ret == Z_STREAM_END) {
                        ok = write_file_data(out_path, uncomp, uncomp_size);
                    }
                    inflateEnd(&strm);
                }
                free(uncomp);
            }
        }

        if (!ok) { free(zip_data); return false; }
        cd_pos += CENTRAL_DIR_HEADER_SIZE + name_len + extra_len;
    }

    free(zip_data);
    return true;
}

// ============================================================================
// 压缩 ZIP
// ============================================================================

typedef struct {
    char *name;
    uint8_t *data;
    size_t len;
    uint32_t crc;
    bool is_dir;
} zip_entry_t;

static bool collect_files(const char *base_path, const char *rel_path,
                          zip_entry_t **entries, int *count, int *cap) {
    char full_path[4096];
    snprintf(full_path, sizeof(full_path), "%s/%s", base_path, rel_path);

    DIR *dir = opendir(full_path);
    if (!dir) return false;

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;

        char child_rel[4096];
        if (rel_path[0] == '\0') {
            snprintf(child_rel, sizeof(child_rel), "%s", entry->d_name);
        } else {
            snprintf(child_rel, sizeof(child_rel), "%s/%s", rel_path, entry->d_name);
        }

        char child_full[4096];
        snprintf(child_full, sizeof(child_full), "%s/%s", full_path, entry->d_name);

        if (is_directory(child_full)) {
            char dir_name[4096];
            snprintf(dir_name, sizeof(dir_name), "%s/", child_rel);

            if (*count >= *cap) {
                *cap = *cap ? *cap * 2 : 32;
                *entries = (zip_entry_t *)realloc(*entries, *cap * sizeof(zip_entry_t));
            }
            zip_entry_t *e = &(*entries)[*count];
            e->name = strdup(dir_name);
            e->data = NULL;
            e->len = 0;
            e->crc = 0;
            e->is_dir = true;
            (*count)++;

            collect_files(base_path, child_rel, entries, count, cap);
        } else {
            size_t data_len = 0;
            uint8_t *data = read_file_data(child_full, &data_len);
            if (!data) continue;

            if (*count >= *cap) {
                *cap = *cap ? *cap * 2 : 32;
                *entries = (zip_entry_t *)realloc(*entries, *cap * sizeof(zip_entry_t));
            }
            zip_entry_t *e = &(*entries)[*count];
            e->name = strdup(child_rel);
            e->data = data;
            e->len = data_len;
            e->crc = (uint32_t)crc32(0, data, (uInt)data_len);
            e->is_dir = false;
            (*count)++;
        }
    }
    closedir(dir);
    return true;
}

static bool deflate_data(const uint8_t *input, size_t input_len,
                         uint8_t **output, size_t *output_len) {
    uLongf bound = compressBound((uLongf)input_len);
    uint8_t *buf = (uint8_t *)malloc(bound);
    if (!buf) return false;

    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    strm.next_in = (Bytef *)input;
    strm.avail_in = (uInt)input_len;
    strm.next_out = buf;
    strm.avail_out = (uInt)bound;

    if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS,
                     MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY) != Z_OK) {
        free(buf);
        return false;
    }

    int ret = deflate(&strm, Z_FINISH);
    if (ret != Z_STREAM_END) {
        deflateEnd(&strm);
        free(buf);
        return false;
    }

    *output_len = strm.total_out;
    *output = (uint8_t *)realloc(buf, *output_len);
    if (!*output) *output = buf;
    deflateEnd(&strm);
    return true;
}

bool minizip_zip_folder(const char *folder_path, const char *zip_path) {
    zip_entry_t *entries = NULL;
    int count = 0, cap = 0;

    if (!collect_files(folder_path, "", &entries, &count, &cap)) {
        for (int i = 0; i < count; i++) { free(entries[i].name); free(entries[i].data); }
        free(entries);
        return false;
    }

    FILE *out = fopen(zip_path, "wb");
    if (!out) {
        for (int i = 0; i < count; i++) { free(entries[i].name); free(entries[i].data); }
        free(entries);
        return false;
    }

    // 时间戳：MS-DOS 格式
    time_t now = time(NULL);
    struct tm *tm_now = localtime(&now);
    uint16_t dos_time = (uint16_t)((tm_now->tm_hour << 11) | (tm_now->tm_min << 5) | (tm_now->tm_sec / 2));
    uint16_t dos_date = (uint16_t)(((tm_now->tm_year + 1900 - 1980) << 9) |
                                   ((tm_now->tm_mon + 1) << 5) | tm_now->tm_mday);

    // 写入每个文件，同时记录压缩后的大小用于 Central Directory
    uint32_t *local_offsets = (uint32_t *)malloc(count * sizeof(uint32_t));
    uint16_t *cd_comp_methods = (uint16_t *)malloc(count * sizeof(uint16_t));
    uint32_t *cd_comp_sizes = (uint32_t *)malloc(count * sizeof(uint32_t));
    uint32_t *cd_crc32s = (uint32_t *)malloc(count * sizeof(uint32_t));

    for (int i = 0; i < count; i++) {
        zip_entry_t *e = &entries[i];
        uint16_t name_len = (uint16_t)strlen(e->name);
        local_offsets[i] = (uint32_t)ftell(out);

        uint32_t comp_size = 0;
        uint32_t uncomp_size = 0;
        uint32_t crc32_val = 0;
        uint16_t comp_method = COMPRESSION_STORE;
        uint8_t *comp_data = NULL;

        if (e->is_dir) {
            uncomp_size = 0;
            comp_size = 0;
            crc32_val = 0;
        } else {
            uncomp_size = (uint32_t)e->len;
            crc32_val = e->crc;

            if (e->len > 0) {
                size_t deflated_len = 0;
                if (deflate_data(e->data, e->len, &comp_data, &deflated_len)) {
                    if (deflated_len < e->len) {
                        comp_method = COMPRESSION_DEFLATE;
                        comp_size = (uint32_t)deflated_len;
                    } else {
                        free(comp_data);
                        comp_data = NULL;
                    }
                }
            }
            if (!comp_data) {
                comp_method = COMPRESSION_STORE;
                comp_size = uncomp_size;
                comp_data = (uint8_t *)malloc(comp_size);
                if (comp_data) memcpy(comp_data, e->data, comp_size);
            }
        }

        // 记录 Central Directory 需要的元数据
        cd_comp_methods[i] = comp_method;
        cd_comp_sizes[i] = comp_size;
        cd_crc32s[i] = crc32_val;

        // Local File Header
        uint8_t lh[LOCAL_FILE_HEADER_SIZE];
        memset(lh, 0, LOCAL_FILE_HEADER_SIZE);
        write_u32(lh, LOCAL_FILE_HEADER_SIG);
        write_u16(lh + 4, 20);              // version needed
        write_u16(lh + 6, 0);               // flags
        write_u16(lh + 8, comp_method);
        write_u16(lh + 10, dos_time);
        write_u16(lh + 12, dos_date);
        write_u32(lh + 14, crc32_val);
        write_u32(lh + 18, comp_size);
        write_u32(lh + 22, uncomp_size);
        write_u16(lh + 26, name_len);
        write_u16(lh + 28, 0);              // extra field length

        fwrite(lh, 1, LOCAL_FILE_HEADER_SIZE, out);
        fwrite(e->name, 1, name_len, out);
        if (comp_data && comp_size > 0) {
            fwrite(comp_data, 1, comp_size, out);
        }

        free(comp_data);
    }

    // Central Directory
    uint32_t cd_start = (uint32_t)ftell(out);
    for (int i = 0; i < count; i++) {
        zip_entry_t *e = &entries[i];
        uint16_t name_len = (uint16_t)strlen(e->name);

        uint16_t comp_method = cd_comp_methods[i];
        uint32_t comp_size = cd_comp_sizes[i];
        uint32_t uncomp_size = e->is_dir ? 0 : (uint32_t)e->len;
        uint32_t crc32_val = cd_crc32s[i];

        uint8_t cd[46];
        memset(cd, 0, 46);
        write_u32(cd, CENTRAL_DIR_HEADER_SIG);
        write_u16(cd + 4, 20);              // version made by
        write_u16(cd + 6, 20);              // version needed
        write_u16(cd + 8, 0);               // flags
        write_u16(cd + 10, comp_method);
        write_u16(cd + 12, dos_time);
        write_u16(cd + 14, dos_date);
        write_u32(cd + 16, crc32_val);
        write_u32(cd + 20, comp_size);
        write_u32(cd + 24, uncomp_size);
        write_u16(cd + 28, name_len);
        write_u16(cd + 30, 0);              // extra field length
        write_u16(cd + 32, 0);              // file comment length
        write_u16(cd + 34, 0);              // disk number start
        write_u16(cd + 36, 0);              // internal file attributes
        write_u32(cd + 38, e->is_dir ? 0x10 : 0); // external file attributes
        write_u32(cd + 42, local_offsets[i]);

        fwrite(cd, 1, 46, out);
        fwrite(e->name, 1, name_len, out);
    }

    // EOCD
    uint32_t cd_end = (uint32_t)ftell(out);
    uint32_t cd_size = cd_end - cd_start;

    uint8_t eocd[22];
    memset(eocd, 0, 22);
    write_u32(eocd, END_OF_CENTRAL_DIR_SIG);
    write_u16(eocd + 4, 0);                 // disk number
    write_u16(eocd + 6, 0);                 // disk with CD
    write_u16(eocd + 8, (uint16_t)count);   // entries on disk
    write_u16(eocd + 10, (uint16_t)count);  // total entries
    write_u32(eocd + 12, cd_size);
    write_u32(eocd + 16, cd_start);
    write_u16(eocd + 20, 0);                // comment length

    fwrite(eocd, 1, 22, out);
    fclose(out);

    free(local_offsets);
    free(cd_comp_methods);
    free(cd_comp_sizes);
    free(cd_crc32s);
    for (int i = 0; i < count; i++) { free(entries[i].name); free(entries[i].data); }
    free(entries);
    return true;
}