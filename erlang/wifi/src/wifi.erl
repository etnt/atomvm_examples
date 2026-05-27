%
% This file is part of AtomVM.
%
% Copyright 2020 Fred Dushin <fred@dushin.net>
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

-module(wifi).

-export([start/0]).

start() ->
    case verify_platform(atomvm:platform()) of
        ok ->
            start_network();
        Error ->
            Error
    end.

start_network() ->
    Config = [
        {ap, [
            {ap_started, fun ap_started/0},
            {sta_connected, fun sta_connected/1},
            {sta_ip_assigned, fun sta_ip_assigned/1},
            {sta_disconnected, fun sta_disconnected/1}
            | maps:get(ap, config:get())
        ]},
        {sta, [
            {connected, fun connected/0},
            {got_ip, fun got_ip/1},
            {disconnected, fun disconnected/0}
            | maps:get(sta, config:get())
        ]},
        {sntp, [
            {host, "time-d-b.nist.gov"},
            {synchronized, fun sntp_synchronized/1},

            %% This is a POSIX TZ timezone string. Breaking it down:
            %%
            %% CET — Standard time abbreviation (Central European Time)
            %% -1 — UTC offset for standard time (UTC+1; POSIX convention inverts the sign)
            %% CEST — Daylight saving time abbreviation (Central European Summer Time)
            %% ,M3.5.0 — DST starts: Month 3 (March), week 5 (last), day 0 (Sunday) → last Sunday in March
            %% ,M10.5.0/3 — DST ends: Month 10 (October), week 5 (last), day 0 (Sunday), at hour 3 (03:00 local) → last Sunday in October at 3:00
            %% The M rule format is Mm.w.d where:
            %%
            %% m = month (1–12)
            %% w = week (1–5, where 5 = "last")
            %% d = day of week (0 = Sunday)
            %% The /3 after the end rule means the transition happens at 03:00. Start defaults to 02:00 when omitted.
            {timezone, "CET-1CEST,M3.5.0/2,M10.5.0/3"}  % Sweden
        ]}
    ],
    case network:start(Config) of
        {ok, _Pid} ->
            io:format("Network started.~n"),
            timer:sleep(infinity);
        Error ->
            Error
    end.

ap_started() ->
    io:format("AP started.~n").

sta_connected(Mac) ->
    io:format("STA connected with mac ~p~n", [Mac]).

sta_disconnected(Mac) ->
    io:format("STA disconnected with mac ~p~n", [Mac]).

sta_ip_assigned(Address) ->
    io:format("STA assigned address ~p~n", [Address]).

connected() ->
    io:format("STA connected.~n").

got_ip(IpInfo) ->
    io:format("Got IP: ~p.~n", [IpInfo]),
    loop().

disconnected() ->
    io:format("STA disconnected.~n").

sntp_synchronized({TVSec, TVUsec}) ->
    io:format("Synchronized time with SNTP server. TVSec=~p TVUsec=~p~n", [TVSec, TVUsec]),
    UTC = erlang:universaltime(),
    Local = erlang:localtime(),
    io:format("  UTC time:   ~s~n", [format_datetime(UTC)]),
    io:format("  Local time: ~s~n", [format_datetime(Local)]),
    case Local of
        UTC ->
            io:format("  WARNING: localtime == universaltime, timezone may not be configured!~n");
        _ ->
            io:format("  Timezone offset active (local != UTC).~n")
    end.

verify_platform(esp32) ->
    ok;
verify_platform(Platform) ->
    {error, {unsupported_platform, Platform}}.

loop() ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = erlang:localtime(),
    io:format("Local: ~p/~p/~p ~p:~p:~p (~pms)~n", [
        Year, Month, Day, Hour, Minute, Second, erlang:system_time(millisecond)
    ]),
    timer:sleep(5000),
    loop().

format_datetime({{Y, Mo, D}, {H, Mi, S}}) ->
    io_lib:format("~p/~p/~p ~p:~p:~p", [Y, Mo, D, H, Mi, S]).
