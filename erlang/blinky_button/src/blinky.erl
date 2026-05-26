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

%% @doc Two-LED alternating blinky with push-button toggle.
%%
%% == Wiring (Raspberry Pi Pico / RP2040) ==
%%
%%   GP15 ──[1kΩ]──|>|── GND      (LED 1, anode to resistor)
%%   GP16 ──[1kΩ]──|>|── GND      (LED 2, anode to resistor)
%%
%%   3.3V ── button ── GP14
%%                      │
%%                     [10kΩ]
%%                      │
%%                     GND
%%
%%   The button uses an external 10kΩ pull-down resistor.
%%   When released, GP14 reads low; when pressed, GP14 reads high.
%%
%% == Behaviour ==
%%
%%   - On start the LEDs are off (idle state).
%%   - Press the button → LEDs alternate at 500ms intervals.
%%   - Press the button again → LEDs turn off (back to idle).
%%   - Edge detection: triggers on a rising edge (low → high).
%%   - Button is polled every 50ms for responsive detection.

-module(blinky).
-export([start/0]).

-define(PIN, 15).       % First LED (GP15)
-define(PIN2, 16).      % Second LED (GP16)
-define(BUTTON, 14).    % Tactile push-button (GP14, external pull-down)

%% @doc Initialise GPIO pins and enter the idle (off) state.
start() ->
    gpio:init(?PIN),
    gpio:set_pin_mode(?PIN, output),
    gpio:init(?PIN2),
    gpio:set_pin_mode(?PIN2, output),
    gpio:init(?BUTTON),
    gpio:set_pin_mode(?BUTTON, input),
    io:format("Ready. Press button on GP~p to toggle LEDs.~n", [?BUTTON]),
    loop_off(gpio:digital_read(?BUTTON)).

%% @doc Idle state – both LEDs off, poll for a rising edge on the button.
loop_off(PrevButton) ->
    CurButton = gpio:digital_read(?BUTTON),
    case {PrevButton, CurButton} of
        {low, high} ->
            %% Rising edge detected → start blinking
            io:format("Button pressed! Blinking~n"),
            loop_blink(low, high);
        _ ->
            timer:sleep(50),
            loop_off(CurButton)
    end.

%% @doc Blink state – alternate LEDs every 500ms.
%% Between toggles, wait_or_press/2 polls the button so a press
%% is detected within ~50ms rather than waiting the full interval.
loop_blink(Level, PrevButton) ->
    gpio:digital_write(?PIN, Level),
    gpio:digital_write(?PIN2, toggle(Level)),
    case wait_or_press(500, PrevButton) of
        {pressed, Prev} ->
            %% Rising edge detected → turn off both LEDs and go idle
            io:format("Button pressed! Off~n"),
            gpio:digital_write(?PIN, low),
            gpio:digital_write(?PIN2, low),
            loop_off(Prev);
        {timeout, Prev} ->
            %% 500ms elapsed without press → flip LEDs and repeat
            loop_blink(toggle(Level), Prev)
    end.

%% @doc Subdivide a wait into 50ms slices, checking for a button press
%% on each slice. Returns {pressed, LastReading} or {timeout, LastReading}.
wait_or_press(Remaining, PrevButton) when Remaining =< 0 ->
    {timeout, PrevButton};
wait_or_press(Remaining, PrevButton) ->
    CurButton = gpio:digital_read(?BUTTON),
    case {PrevButton, CurButton} of
        {low, high} ->
            {pressed, high};
        _ ->
            timer:sleep(50),
            wait_or_press(Remaining - 50, CurButton)
    end.

%% @doc Flip a pin level between high and low.
toggle(high) -> low;
toggle(low) -> high.
