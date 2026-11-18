# Board test guide - Ultrasonic Object Tracking System

One bitstream does everything. You choose what to test with switches and
read the result on the LCD. Tests 1-8 need **no PCB**: only the Basys 3 and
the LCD on port JA.

## Before you start

1. Unzip, open Vivado, **Tools -> Run Tcl Script -> `create_project.tcl`**.
2. **Generate Bitstream**, then **Open Hardware Manager -> Open Target ->
   Auto Connect -> Program Device**.
3. Set **all switches off** and press **btnC** (center button) to reset.

## Buttons and switches

| Control | What it does |
|---|---|
| **btnU** (top) | Take one measurement |
| **btnC** (center) | Reset everything, count goes back to 0 |
| **SW0, SW1, SW2** | Turn transmitter 1, 2, 3 on |
| **SW3 to SW9** | Echo threshold. The value of these 7 switches x 4 (SW3 = 1, SW4 = 2, SW5 = 4 ... SW9 = 64) |
| **SW10, SW11** | Which fake target (table below) |
| **SW12, SW13** | Which LCD screen (table below) |
| **SW14** | On = fake echoes (no PCB needed). Off = real receivers |
| **SW15** | Auto mode: measures by itself 10 times per second |

### LCD screens (SW12, SW13)

| SW13 | SW12 | Screen |
|---|---|---|
| off | off | **Distances** |
| off | on | **Position + angle** |
| on | off | **Echo levels** |
| on | on | **Transmit check** |

### Fake targets (SW10, SW11)

The fake echoes pretend an object sits at a known spot. Sensors are in a line
at x = 0, 1500 and 3000 mm.

| SW11 | SW10 | Target | Object at (mm) |
|---|---|---|---|
| off | off | 0 | X 1500, Y 1000 |
| off | on | 1 | X 500, Y 800 |
| on | off | 2 | X 2000, Y 1500 |
| on | on | 3 | X 1000, Y 2000 |

### LEDs

| LED | Meaning |
|---|---|
| LED0, LED1, LED2 | Sensor 1, 2, 3 heard an echo in the last measurement |
| LED13 | Fake-echo mode is on (SW14) |
| LED14 | Auto mode is on (SW15) |
| LED15 | Flips on/off every time a measurement finishes |

## What each screen means

**Distances** (SW13 off, SW12 off)
```
|D1:1803 D2:1000 |   distance from sensor 1 and sensor 2, in mm
|D3:1803    #0001|   distance from sensor 3, measurement count
```
`----` instead of a number means that sensor heard no echo.

**Position + angle** (SW13 off, SW12 on)
```
|X:+1499 Y:1000  |   object position in mm (sensor 1 is X = 0)
|Ang:33.8   #0001|   angle in degrees, measurement count
```
- Angle = direction of the object seen from sensor 1, measured from the line
  of sensors (0 degrees = along the sensors, 90 = straight out).
- `X:----- Y:----` and `No fix` = at least one sensor missed its echo, so no
  position can be computed.
- `Ang:--.-` = position found, but X is 0 or negative, so no angle.

**Echo levels** (SW13 on, SW12 off)
```
|P1:0215 P2:0198 |   loudest signal each receiver heard (ADC units)
|P3:0230 Th:0060 |   receiver 3, and the threshold set by SW3-SW9
```
A receiver counts an echo only when its level goes above `Th`. Used to tune
the threshold once the PCB is connected.

**Transmit check** (SW13 on, SW12 on)
```
|TX 123  #0001   |   which transmitters are on (- = off), count
|Cycles:08  OK   |   40 kHz cycles sent in the last burst (must be 8)
```
`BAD` instead of `OK` means the burst was the wrong length.

**`Press btnU`** on the second line means no measurement has been taken yet
since reset.

## Tests without the PCB

### Test 1: Power on and reset
- **Set:** all switches off, press btnC.
- **Expect:** LCD line 1 `D1:0000 D2:0000`, line 2 `Press btnU`.
  All LEDs off.
- **Proves:** the FPGA is programmed and the LCD works.

### Test 2: Transmit check
- **Set:** SW0, SW1, SW2 on. SW12 and SW13 on. Press btnU.
- **Expect:**
  ```
  |TX 123  #0001   |
  |Cycles:08  OK   |
  ```
  LED15 changes state.
- **Then:** turn SW1 off, press btnU -> `TX 1-3  #0002`, still `Cycles:08  OK`.
- **Optional scope:** trigger on JB4, probe JB1. You should see 8 square
  waves at 40 kHz (25 us each), 200 us in total, once per press.
- **Proves:** Zach's burst and frequency generators and the transmit outputs.

### Test 3: Position and angle with fake echoes
- **Set:** SW14 on (LED13 lights). SW12 on, SW13 off. SW10 and SW11 off.
  Press btnU.
- **Expect** (target 0):
  ```
  |X:+1499 Y:1000  |
  |Ang:33.8   #0001|
  ```
  LED0, LED1, LED2 light up.
- **Then** change SW10/SW11 and press btnU each time:

  | SW11 | SW10 | LCD line 1 | LCD line 2 | True value |
  |---|---|---|---|---|
  | off | off | `X:+1499 Y:1000` | `Ang:33.8` | (1500, 1000), 33.7 deg |
  | off | on | `X:+0499 Y:0798` | `Ang:57.9` | (500, 800), 58.0 deg |
  | on | off | `X:+1999 Y:1500` | `Ang:36.5` | (2000, 1500), 36.9 deg |
  | on | on | `X:+1000 Y:1999` | `Ang:63.3` | (1000, 2000), 63.4 deg |

  A difference of 1-2 mm and under 0.5 degrees is normal rounding.
- **Proves:** the measurement FSMs, distance math, Zach's coordinate computer
  and his CORDIC angle calculator all work together on the real chip.

### Test 4: Distances with fake echoes
- **Set:** same as Test 3, but SW12 off (SW13 off). Press btnU.
- **Expect:**

  | SW11 | SW10 | LCD |
  |---|---|---|
  | off | off | `D1:1803 D2:1000` / `D3:1803` |
  | off | on | `D1:0943 D2:1281` / `D3:2625` |
  | on | off | `D1:2500 D2:1581` / `D3:1803` |
  | on | on | `D1:2236 D2:2062` / `D3:2828` |

- **Proves:** each of the three distance channels on its own.

### Test 5: Button debounce
- **Set:** any screen, note the `#` count.
- **Do:** press btnU 5 times, quickly.
- **Expect:** the count goes up by exactly 5.
- **Do:** hold btnU down for 3 seconds.
- **Expect:** the count goes up by exactly 1.
- **Proves:** one press = one measurement, no double-triggering.

### Test 6: Auto mode
- **Set:** SW14 on, position screen (SW12 on, SW13 off), SW15 on (LED14 on).
- **Expect:** the count climbs about 10 per second without pressing anything,
  and LED15 flickers. Flip SW10/SW11 and the X, Y, angle change within a
  fraction of a second.
- **Proves:** continuous tracking works. Turn SW15 off when done.

### Test 7: No receivers connected
- **Set:** SW14 **off** (LED13 off, real receivers, but no PCB connected).
  Position screen. Press btnU.
- **Expect:** `X:----- Y:----` and `No fix`. Distances screen shows `----`
  for sensors that heard nothing. LED0-2 stay off (some may light at random,
  since the unconnected inputs pick up noise).
- **Proves:** the system reports a missed echo instead of a wrong position.

### Test 8: Threshold display
- **Set:** echo levels screen (SW13 on, SW12 off). Flip SW3 to SW9.
- **Expect:** `Th:` changes: SW3 only = `0004`, SW4 only = `0008`,
  SW3 + SW4 + SW5 + SW6 = `0060`, all of SW3-SW9 = `0508`.
- **Proves:** the threshold control works. P1-P3 show random noise values
  while no PCB is connected.

## Tests with the PCB (later)

Wire and test **one channel at a time**. See README.md for the wiring and the
0-1 V check you must do before connecting JXADC.

### Test 9: Transmitters
- **Connect:** JB1 + GND to PCB Tx driver 1, transducer 1 on the PCB.
- **Set:** SW0 only, transmit check screen, press btnU.
- **Expect:** scope on the transducer shows the 12 V burst; LCD `TX 1--`,
  `Cycles:08  OK`. Then add JB2/SW1 and JB3/SW2.

### Test 10: Echo levels and threshold
- **Connect:** Rx 1 output to JXADC 1, its ground to JXADC 7 (after the
  0-1 V check).
- **Set:** SW14 off, SW0 on, echo levels screen, SW15 on, nothing in front.
- **Read:** `P1` = noise level. Set SW3-SW9 so `Th` is 2-3 times that.
- **Then:** hold a book about 0.5 m in front. `P1` should jump well above `Th`.

### Test 11: Real distance
- **Set:** distances screen, book at a tape-measured distance (start at 1 m).
- **Expect:** `D1` within about 2 cm of the real distance. Try 0.5, 1, 2 m.
  Repeat for sensors 2 and 3.
- Closer than about 205 mm always shows `----` (blind zone).

### Test 12: Real position and angle
- **Set:** all three channels connected, sensors in a line 1.5 m apart, all
  of SW0-SW2 on, position screen, SW15 on.
- **Do:** place an object in front, then move it slowly.
- **Expect:** X, Y and the angle follow the object.

## Demo day

1. Show **Test 2** (transmit check) and **Test 3** (all four fake targets);
   these work every time, even if the sensors misbehave. Say clearly that
   SW14 uses simulated echoes.
2. Then switch SW14 off and show **Test 11** and **Test 12** live with the
   real sensors.

## If something looks wrong

| You see | Likely cause |
|---|---|
| LCD blank but backlight on | Contrast: LCD pin 3 to GND, or power the LCD from 5 V |
| Top row of solid boxes | LCD not getting commands: check JA1-4, JA7, JA8, press btnC |
| Nothing changes when pressing btnU | Board not programmed, or a measurement is still running in auto mode |
| `Cycles:` not `08` | Rebuild the bitstream; tell Zach |
| Fake targets show wrong X/Y | Check SW14 is on and SW10/SW11 match the table |
| Always `No fix` with the PCB | Threshold too high (lower SW3-SW9), or check JXADC wiring and ground |
| Distances jump around with the PCB | Threshold too low, or echoes from walls; raise SW3-SW9 |
