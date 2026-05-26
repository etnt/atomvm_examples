%
% This file is part of AtomVM.
%
% Copyright 2018-2020 Davide Bettio <davide@uninstall.it>
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

-module(blinky).
-export([start/0]).

% External LED on pin 2 will work with all pico devices.
% -define(PIN, 2).
% Uncomment the following line to use pico-w onboard LED.
% -define(PIN, {wl, 0}).
% Standard Pico onboard LED is on pin 25.
%-define(PIN, 25).
-define(PIN, 15).
-define(PIN2, 16).


start() ->
    Pin1 = ?PIN,
    Pin2 = ?PIN2,
    gpio:init(Pin1),
    gpio:set_pin_mode(Pin1, output),
    gpio:init(Pin2),
    gpio:set_pin_mode(Pin2, output),
    loop(Pin1, Pin2, low).

loop(Pin1, Pin2, Level) ->
    io:format("Pin ~p ~p, Pin ~p ~p~n", [Pin1, Level, Pin2, toggle(Level)]),
    gpio:digital_write(Pin1, Level),
    gpio:digital_write(Pin2, toggle(Level)),
    timer:sleep(1000),
    loop(Pin1, Pin2, toggle(Level)).

toggle(high) ->
    low;
toggle(low) ->
    high.
