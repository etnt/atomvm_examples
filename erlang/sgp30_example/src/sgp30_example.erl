%% @doc SGP30 example — reads eCO2 and TVOC every second.
%%
%% Demonstrates the SGP30 air quality sensor on a Raspberry Pi Pico.
%% The sensor's baseline algorithm requires measurements exactly once
%% per second, so unlike the BME680 example we use a 1-second loop.
%%
%% == Wiring ==
%%
%%   Pico GP4 (pin 6)   → SDA  (sensor data line)
%%   Pico GP5 (pin 7)   → SCL  (sensor clock line)
%%   Pico 3V3 (pin 36)  → VIN  (sensor power, 3.3V)
%%   Pico GND (pin 38)  → GND  (common ground)
%%
%% == What to expect ==
%%
%%   - First 15 seconds: eCO2=400, TVOC=0 (sensor warm-up / calibrating)
%%   - After warm-up: eCO2 rises above 400 if air is stale
%%   - Breathe on it: eCO2 jumps to 1000+ ppm, TVOC spikes
%%   - Fresh air: values return towards 400/0

-module(sgp30_example).
-export([start/0]).

start() ->
    %% Same I2C bus as other sensors (GP4/GP5, peripheral 0)
    I2C = i2c:open([{sda, 4}, {scl, 5}, {peripheral, 0}, {clock_speed_hz, 100000}]),
    io:format("Initialising SGP30...~n"),
    case sgp30:init(I2C) of
        {ok, Sensor} ->
            io:format("SGP30 ready. Reading every 1s (warm-up takes ~~15s):~n"),
            loop(Sensor, 0);
        {error, Reason} ->
            io:format("SGP30 init failed: ~p~n", [Reason])
    end.

loop(Sensor, Count) ->
    case sgp30:measure(Sensor) of
        {ok, ECO2, TVOC} ->
            io:format("  [~3.B] eCO2: ~B ppm  |  TVOC: ~B ppb~n",
                      [Count, ECO2, TVOC]);
        {error, Reason} ->
            io:format("  [~3.B] Read error: ~p~n", [Count, Reason])
    end,
    timer:sleep(1000),
    loop(Sensor, Count + 1).
