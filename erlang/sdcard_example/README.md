<!---
  Copyright 2024 <your name>

  SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-->

# `sdcard_example` Application

An AtomVM example demonstrating SD card access via the SDMMC interface on ESP32-S3.

This example mounts a FAT-formatted SD card, writes a file, reads it back, and lists the directory contents — all from Erlang running on the microcontroller.

> **Note:** This example requires a **patched AtomVM firmware** (see below). The upstream AtomVM `esp:mount/4` for SDMMC does not yet support custom pin configuration.

## Hardware Requirements

- ESP32-S3 board with an SD card slot (tested on **Freenove ESP32-S3 WROOM**)
- FAT-formatted SD card (FAT16 or FAT32)
- The board must expose SDMMC-capable GPIO pins to the SD card slot

### Pin Configuration (Freenove ESP32-S3 WROOM)

| Signal | GPIO | Description |
|--------|------|-------------|
| CLK    | 39   | SD clock    |
| CMD    | 38   | SD command  |
| D0     | 40   | SD data 0   |

This board uses **1-bit SDMMC mode** (only D0, no D1–D3). The pin assignments were determined from the board's Arduino SD_MMC example which calls `SD_MMC.setPins(clk=39, cmd=38, d0=40)`.

> For other boards, adjust the `-define` macros in `sdcard_example.erl`.

## Required AtomVM Firmware Patch

The stock AtomVM firmware's `esp:mount("sdmmc", Path, fat, Opts)` uses `SDMMC_SLOT_CONFIG_DEFAULT()` which hard-codes pins for the ESP32's default SDMMC slot. On boards like the Freenove ESP32-S3 where the SD card is wired to non-default GPIOs, the mount will time out.

### What the Patch Does

The patch adds support for the following options in the `Opts` proplist passed to `esp:mount/4`:

| Option    | Type    | Description                                    |
|-----------|---------|------------------------------------------------|
| `clk`     | integer | GPIO pin for SD clock                          |
| `cmd`     | integer | GPIO pin for SD command line                   |
| `d0`      | integer | GPIO pin for data line 0                       |
| `d1`      | integer | GPIO pin for data line 1 (4-bit mode)          |
| `d2`      | integer | GPIO pin for data line 2 (4-bit mode)          |
| `d3`      | integer | GPIO pin for data line 3 (4-bit mode)          |
| `width`   | integer | Bus width: `1` for 1-bit mode, `4` for 4-bit   |

When `width` is set to `1`, the host is configured with `SDMMC_HOST_FLAG_1BIT`.

### Applying the Patch

The patch applies to `src/platforms/esp32/components/avm_builtins/storage_nif.c` in the AtomVM source tree. It was developed against commit `36cb7309` (branch `main`, post-0.7 release).

```diff
--- a/src/platforms/esp32/components/avm_builtins/storage_nif.c
+++ b/src/platforms/esp32/components/avm_builtins/storage_nif.c
@@ -183,6 +183,39 @@ static term nif_esp_mount(Context *ctx, int argc, term argv[])
         sdmmc_host_t host_config = SDMMC_HOST_DEFAULT();
         sdmmc_slot_config_t slot_config = SDMMC_SLOT_CONFIG_DEFAULT();
 
+        term clk_term = interop_kv_get_value_default(
+            opts_term, ATOM_STR("\x3", "clk"), term_invalid_term(), ctx->global);
+        if (term_is_integer(clk_term)) {
+            slot_config.clk = term_to_int32(clk_term);
+        }
+        term cmd_term = interop_kv_get_value_default(
+            opts_term, ATOM_STR("\x3", "cmd"), term_invalid_term(), ctx->global);
+        if (term_is_integer(cmd_term)) {
+            slot_config.cmd = term_to_int32(cmd_term);
+        }
+        term d0_term = interop_kv_get_value_default(
+            opts_term, ATOM_STR("\x2", "d0"), term_invalid_term(), ctx->global);
+        if (term_is_integer(d0_term)) {
+            slot_config.d0 = term_to_int32(d0_term);
+        }
+        term d1_term = interop_kv_get_value_default(
+            opts_term, ATOM_STR("\x2", "d1"), term_invalid_term(), ctx->global);
+        if (term_is_integer(d1_term)) {
+            slot_config.d1 = term_to_int32(d1_term);
+        }
+        term d2_term = interop_kv_get_value_default(
+            opts_term, ATOM_STR("\x2", "d2"), term_invalid_term(), ctx->global);
+        if (term_is_integer(d2_term)) {
+            slot_config.d2 = term_to_int32(d2_term);
+        }
+        term d3_term = interop_kv_get_value_default(
+            opts_term, ATOM_STR("\x2", "d3"), term_invalid_term(), ctx->global);
+        if (term_is_integer(d3_term)) {
+            slot_config.d3 = term_to_int32(d3_term);
+        }
+        term width_term = interop_kv_get_value_default(
+            opts_term, ATOM_STR("\x5", "width"), term_invalid_term(), ctx->global);
+        if (term_is_integer(width_term)) {
+            slot_config.width = term_to_int32(width_term);
+            if (slot_config.width == 1) {
+                host_config.flags = SDMMC_HOST_FLAG_1BIT;
+            }
+        }
+
         mount = enif_alloc_resource(platform->mounted_fs_resource_type, sizeof(struct MountedFS));
```

### Building the Patched Firmware

Prerequisites: [ESP-IDF v5.x](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/get-started/) installed and sourced.

```bash
# Clone AtomVM and apply the patch
git clone https://github.com/atomvm/AtomVM.git
cd AtomVM
# Apply the patch (or manually edit storage_nif.c as shown above)

# Build for ESP32-S3
export IDF_PATH=~/esp/esp-idf
source $IDF_PATH/export.sh
cd src/platforms/esp32
idf.py set-target esp32s3
idf.py build

# Flash (adjust port for your system)
idf.py -p /dev/cu.usbmodem5B414826621 flash
```

## Important: Mount Reference Lifetime

The `esp:mount/4` function returns `{ok, MountRef}` where `MountRef` is a resource reference. **The filesystem remains mounted only as long as this reference is alive.** When the reference is garbage collected, the destructor automatically unmounts the filesystem.

This means:

```erlang
%% BAD: _Ref may be GC'd before file operations execute!
{ok, _Ref} = esp:mount("sdmmc", "/sdcard", fat, Opts),
atomvm:posix_stat("/sdcard").  %% -> {error, enoent}

%% GOOD: Keep the reference alive
{ok, MountRef} = esp:mount("sdmmc", "/sdcard", fat, Opts),
%% ... do file operations ...
esp:umount(MountRef).  %% explicit unmount when done
```

If you see `{error, enoent}` from file operations immediately after a successful mount, this is almost certainly the cause.

## Building and Flashing This Example

```bash
cd erlang/sdcard_example

# Build the .avm file
rebar3 atomvm packbeam

# Flash to the main.avm partition (offset 0x250000)
esptool.py --chip auto --port /dev/cu.usbmodem5B414826621 \
    --baud 115200 --before default_reset --after hard_reset \
    write_flash -u --flash_mode keep --flash_freq keep --flash_size detect \
    0x250000 _build/default/lib/sdcard_example.avm
```

## Expected Output

```
=== AtomVM SD Card Example ===

Mounting SD card via SDMMC (1-bit mode)...
  CLK=GPIO39, CMD=GPIO38, D0=GPIO40
  Mount successful!

--- stat /sdcard ---
  Type: directory
  Mode: 7777
  Size: 0 bytes

--- Writing /sdcard/hello.txt ---
  Wrote 47 bytes

--- Reading /sdcard/hello.txt ---
  Content: Hello from AtomVM!
SD card access is working.

--- Directory listing: /sdcard ---
  hello.txt

Unmounting SD card...
Done.
```

## POSIX File API Reference

AtomVM provides the following POSIX-like file operations:

| Function | Description |
|----------|-------------|
| `atomvm:posix_open(Path, Flags)` | Open a file (read-only) |
| `atomvm:posix_open(Path, Flags, Mode)` | Open/create a file with permissions |
| `atomvm:posix_read(Fd, MaxBytes)` | Read up to N bytes |
| `atomvm:posix_write(Fd, Data)` | Write binary data |
| `atomvm:posix_close(Fd)` | Close file descriptor |
| `atomvm:posix_stat(Path)` | Get file/directory info |
| `atomvm:posix_opendir(Path)` | Open directory for listing |
| `atomvm:posix_readdir(Dir)` | Read next directory entry |
| `atomvm:posix_closedir(Dir)` | Close directory |

### Open Flags

`o_rdonly`, `o_wronly`, `o_rdwr`, `o_creat`, `o_trunc`, `o_append`, `o_excl`

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Mount returns `{error, timeout}` | Wrong GPIO pins | Check pin defines match your board |
| Mount returns `{error, timeout}` | No SD card inserted | Insert a FAT-formatted card |
| Mount OK but stat returns `{error, enoent}` | Mount ref was GC'd | Keep `MountRef` variable alive (see above) |
| `posix_open` returns `{error, badarg}` | Wrong flag atoms | Use `o_wronly` not `write`, etc. |

## License

Apache-2.0 OR LGPL-2.1-or-later (same as AtomVM)

For general information about building and executing Erlang AtomVM example programs, see the Erlang example program [README](../README.md).
