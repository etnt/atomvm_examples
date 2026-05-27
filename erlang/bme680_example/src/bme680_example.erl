%% @doc BME680 example — reads environment data every 5 seconds.
%%
%% Demonstrates reading all four BME680 channels (temperature, pressure,
%% humidity, gas resistance) from a Raspberry Pi Pico via I2C.
%%
%% == Wiring ==
%%
%%   Pico GP4 (pin 6)   → SDA  (sensor data line)
%%   Pico GP5 (pin 7)   → SCL  (sensor clock line)
%%   Pico 3V3 (pin 36)  → VIN  (sensor power, 3.3V)
%%   Pico GND (pin 38)  → GND  (common ground)
%%
%% These form I2C peripheral 0 on the Pico. The BME680 breakout board
%% typically includes pull-up resistors on SDA/SCL.
%%
%% == What to expect ==
%%
%%   - First reading may show incorrect values (sensor warm-up)
%%   - Temperature: typically 20–35°C indoors (slightly above ambient
%%     due to self-heating from the gas sensor heater)
%%   - Pressure: ~1013 hPa at sea level (decreases ~12 hPa per 100m altitude)
%%   - Humidity: 30–70% typical indoors
%%   - Gas resistance: starts erratic, stabilises after 5–10 readings.
%%     Higher = cleaner air. Breathe on it to see it drop.

-module(bme680_example).
-export([start/0]).

-define(BME_ADDR, 16#77).  %% Our sensor has SDO pulled high → address 0x77

start() ->
    %% Open I2C bus 0 at 100kHz (standard mode, safe for short wires)
    I2C = i2c:open([{sda, 4}, {scl, 5}, {peripheral, 0}, {clock_speed_hz, 100000}]),
    io:format("Initialising BME680 at 0x~2.16.0B...~n", [?BME_ADDR]),
    case bme680:init(I2C, ?BME_ADDR) of
        {ok, Sensor} ->
            io:format("BME680 ready. Reading every 5s:~n"),
            loop(Sensor);
        {error, Reason} ->
            io:format("BME680 init failed: ~p~n", [Reason])
    end.

loop(Sensor) ->
    %% read_gas/1 triggers a full measurement including the gas heater.
    %% Takes ~200ms per measurement cycle.
    case bme680:read_gas(Sensor) of
        {ok, Temp, Press, Hum, Gas} ->
            io:format("  T: ~.1f C  |  P: ~.1f hPa  |  H: ~.1f %%  |  Gas: ~.0f Ohm~n",
                      [Temp, Press, Hum, Gas]);
        {ok, Temp, Press, Hum} ->
            io:format("  T: ~.1f C  |  P: ~.1f hPa  |  H: ~.1f %%~n",
                      [Temp, Press, Hum])
    end,
    timer:sleep(5000),
    loop(Sensor).
