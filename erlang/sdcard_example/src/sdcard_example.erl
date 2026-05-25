%
% This file is part of AtomVM.
%
% Copyright 2024 <your name>
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%    http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%

%%-----------------------------------------------------------------------------
%% @doc SD Card example for AtomVM.
%%
%% Demonstrates mounting an SD card via the SDMMC interface and performing
%% basic file operations (write, read, list directory) on the mounted
%% filesystem.
%%
%% This example requires a patched AtomVM firmware that supports SDMMC pin
%% configuration options. See the README for details.
%% @end
%%-----------------------------------------------------------------------------
-module(sdcard_example).

-export([start/0]).

%% SDMMC pin configuration for Freenove ESP32-S3 WROOM board.
%% Adjust these for your specific board.
-define(SDMMC_CLK, 39).
-define(SDMMC_CMD, 38).
-define(SDMMC_D0, 40).

%% Mount point for the SD card
-define(MOUNT_POINT, "/sdcard").

%%-----------------------------------------------------------------------------
%% @doc Entry point. Mounts the SD card, performs file I/O, then exits.
%% @end
%%-----------------------------------------------------------------------------
start() ->
    io:format("~n=== AtomVM SD Card Example ===~n~n"),

    %% Mount the SD card using 1-bit SDMMC mode
    io:format("Mounting SD card via SDMMC (1-bit mode)...~n"),
    io:format("  CLK=GPIO~B, CMD=GPIO~B, D0=GPIO~B~n",
              [?SDMMC_CLK, ?SDMMC_CMD, ?SDMMC_D0]),

    Opts = [{clk, ?SDMMC_CLK}, {cmd, ?SDMMC_CMD}, {d0, ?SDMMC_D0}, {width, 1}],
    case esp:mount("sdmmc", ?MOUNT_POINT, fat, Opts) of
        {ok, MountRef} ->
            io:format("  Mount successful!~n~n"),
            try
                demo_stat(),
                demo_write_file(),
                demo_read_file(),
                demo_list_directory()
            after
                %% IMPORTANT: The mount reference must stay alive for the
                %% duration of filesystem use. If it is garbage collected,
                %% the filesystem is automatically unmounted.
                io:format("~nUnmounting SD card...~n"),
                esp:umount(MountRef),
                io:format("Done.~n")
            end;
        {error, Reason} ->
            io:format("  Mount FAILED: ~p~n", [Reason]),
            io:format("~nTroubleshooting:~n"),
            io:format("  - Check that an SD card is inserted~n"),
            io:format("  - Verify GPIO pin assignments match your board~n"),
            io:format("  - Ensure AtomVM firmware has SDMMC pin config patch~n")
    end.

%%-----------------------------------------------------------------------------
%% @doc Demonstrate stat on the mount point.
%% @end
%%-----------------------------------------------------------------------------
demo_stat() ->
    io:format("--- stat ~s ---~n", [?MOUNT_POINT]),
    case atomvm:posix_stat(?MOUNT_POINT) of
        {ok, Info} ->
            io:format("  Type: directory~n"),
            io:format("  Mode: ~.8B~n", [maps:get(st_mode, Info) band 8#7777]),
            io:format("  Size: ~B bytes~n~n", [maps:get(st_size, Info)]);
        {error, Err} ->
            io:format("  ERROR: ~p~n~n", [Err])
    end.

%%-----------------------------------------------------------------------------
%% @doc Write a test file to the SD card.
%% @end
%%-----------------------------------------------------------------------------
demo_write_file() ->
    Path = ?MOUNT_POINT ++ "/hello.txt",
    io:format("--- Writing ~s ---~n", [Path]),
    Content = <<"Hello from AtomVM!\nSD card access is working.\n">>,
    case atomvm:posix_open(Path, [o_wronly, o_creat, o_trunc], 8#666) of
        {ok, Fd} ->
            case atomvm:posix_write(Fd, Content) of
                {ok, Written} ->
                    io:format("  Wrote ~B bytes~n~n", [Written]);
                {error, WErr} ->
                    io:format("  Write error: ~p~n~n", [WErr])
            end,
            atomvm:posix_close(Fd);
        {error, OpenErr} ->
            io:format("  Open error: ~p~n~n", [OpenErr])
    end.

%%-----------------------------------------------------------------------------
%% @doc Read back the test file from the SD card.
%% @end
%%-----------------------------------------------------------------------------
demo_read_file() ->
    Path = ?MOUNT_POINT ++ "/hello.txt",
    io:format("--- Reading ~s ---~n", [Path]),
    case atomvm:posix_open(Path, [o_rdonly]) of
        {ok, Fd} ->
            case atomvm:posix_read(Fd, 256) of
                {ok, Data} ->
                    io:format("  Content: ~s~n", [Data]);
                eof ->
                    io:format("  (empty file)~n");
                {error, RErr} ->
                    io:format("  Read error: ~p~n", [RErr])
            end,
            atomvm:posix_close(Fd);
        {error, OpenErr} ->
            io:format("  Open error: ~p~n~n", [OpenErr])
    end.

%%-----------------------------------------------------------------------------
%% @doc List files in the SD card root directory.
%% @end
%%-----------------------------------------------------------------------------
demo_list_directory() ->
    io:format("~n--- Directory listing: ~s ---~n", [?MOUNT_POINT]),
    case atomvm:posix_opendir(?MOUNT_POINT) of
        {ok, Dir} ->
            list_entries(Dir),
            atomvm:posix_closedir(Dir);
        {error, Err} ->
            io:format("  opendir error: ~p~n", [Err])
    end.

list_entries(Dir) ->
    case atomvm:posix_readdir(Dir) of
        {ok, {dirent, _Type, Name}} ->
            io:format("  ~s~n", [Name]),
            list_entries(Dir);
        eof ->
            ok;
        {error, _} ->
            ok
    end.
