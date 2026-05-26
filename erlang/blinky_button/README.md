<!---
  SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-->

# `blinky_button` Application

An AtomVM example for the Raspberry Pi Pico (RP2040) that alternates two external LEDs, toggled on and off by a push-button.

> Note. This example runs on the `pico` platform.

## Behaviour

- On start both LEDs are off (idle state).
- Press the button → LEDs alternate at 500 ms intervals.
- Press the button again → LEDs turn off (back to idle).
- Edge detection triggers on a rising edge (low → high), polled every 50 ms for responsive detection.

## Wiring

```
    Raspberry Pi Pico
    +----------------+
    |                |
    |          GP15  o───[1kΩ]───|>|───GND   (LED 1)
    |                |
    |          GP16  o───[1kΩ]───|>|───GND   (LED 2)
    |                |
    |          GP14  o───────────┐
    |                |           │
    |         3.3V   o──button───┘
    |                |           │
    |          GND   o──[10kΩ]───┘
    +----------------+
```

| Pin  | Function | Notes |
|------|----------|-------|
| GP15 | LED 1 output | 1 kΩ series resistor to LED anode, cathode to GND |
| GP16 | LED 2 output | 1 kΩ series resistor to LED anode, cathode to GND |
| GP14 | Button input | External 10 kΩ pull-down to GND; button connects GP14 to 3.3 V |

The pull-down resistor keeps GP14 low when the button is released and allows it to go high when pressed.

## Build and Flash

Build the UF2:

```sh
rebar3 atomvm packbeam && rebar3 atomvm uf2create
```

Flash with `picotool` (no BOOTSEL button needed):

```sh
picotool reboot -f -u && \
picotool load _build/default/lib/blinky_button.uf2 -f && \
picotool reboot
```

Monitor serial output:

```sh
minicom -D /dev/cu.usbmodem11101 -b 115200
```

## References

- [AtomVM Programmers Guide](https://doc.atomvm.org/latest/programmers-guide.html)
- [Erlang examples README](../README.md)
