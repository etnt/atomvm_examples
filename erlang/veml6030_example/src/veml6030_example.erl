%% @doc VEML6030 example — reads ambient light every 2 seconds.
%%
%% Wiring (Pico direct to VEML6030 breakout):
%%   Pico GP4  → SDA
%%   Pico GP5  → SCL
%%   Pico 3V3  → VIN/3V3
%%   Pico GND  → GND

-module(veml6030_example).
-export([start/0]).

-define(VEML_ADDR, 16#48).

start() ->
    I2C = i2c:open([{sda, 4}, {scl, 5}, {peripheral, 0}, {clock_speed_hz, 100000}]),
    io:format("Initialising VEML6030 at 0x~2.16.0B...~n", [?VEML_ADDR]),
    Sensor = veml6030:init(I2C, ?VEML_ADDR),
    io:format("Reading ambient light every 2s:~n"),
    loop(Sensor).

loop(Sensor) ->
    {ok, Lux} = veml6030:read_lux(Sensor),
    {ok, White} = veml6030:read_white(Sensor),
    io:format("  ALS: ~.1f lux  |  White: ~.1f lux~n", [Lux, White]),
    timer:sleep(2000),
    loop(Sensor).
