# FPGA Ultrasonic Object Tracking System

ECE 3337 FPGA Project Lab, Texas Tech University, Fall 2026
Team: Zachary Gottschalk, Jagrati Kumari, Andrew Hejnar

A Basys 3 FPGA uses three 40 kHz ultrasonic transmitter/receiver pairs to
locate an object in front of them. Each pair measures distance from the
time an echo takes to return, and the three distances are combined
(trilateration) to compute the object's X and Y position, shown live on a
16x2 LCD. All analog hardware (transmit drivers, receive amplifiers and
filters) is on a custom PCB.

## How it works

1. A button press (or the auto timer) starts a measurement.
2. The FPGA sends an 8-cycle, 40 kHz burst (200 us) to all three transmitters.
3. Each receiver signal is amplified and filtered on the PCB, then digitized
   by the Basys 3 XADC (about 333,000 samples per second per channel).
4. Echo detection finds when each echo arrives.
5. The time of flight becomes a distance in millimeters:
   `distance = speed of sound x round-trip time / 2`
6. The three distances go into the coordinate computer, which solves for X
   and Y.
7. The LCD shows distances, position, echo levels or a transmit check.

```
btnU -> debounce -> measurement_fsm x3 -> burst_generator -> frequency_generator -> JB1-3 -> PCB Tx
PCB Rx -> JXADC -> xadc_reader -> echo_detect x3 -> measurement_fsm x3 -> coordinate_unit -> LCD
```

Sensors are assumed to sit in a straight line at x = 0, 1500 and 3000 mm,
facing the same direction. Measurable range is about 205 mm to 5.1 m.

## Repository layout

| Path | Contents | Owner |
|---|---|---|
| `RTL/ultrasonic_top.v` | Top level: connects every module, switch controls, LCD pages | Jagrati |
| `RTL/tx_controller/burst_generator.v` | 200 us burst enable | Zach |
| `RTL/tx_controller/frequency_controller.v` | 40 kHz square wave (`frequency_generator`) | Zach |
| `RTL/control/measurement_fsm.v` | Measurement timing, blind zone, time of flight to mm | Jagrati |
| `RTL/control/debounce.v` | Clean single pulse from a push button | Jagrati |
| `RTL/receive/xadc_reader.v` | Reads 3 receiver channels from the XADC | Jagrati |
| `RTL/receive/echo_detect.v` | Envelope + threshold echo detection | Jagrati |
| `RTL/Coordinate_Computer.v` | Trilateration: 3 distances to X, Y | Zach |
| `RTL/Square_Root.v`, `RTL/CSM_Row.v`, `RTL/CSM.v` | Hardware square root | Zach |
| `RTL/compute/coordinate_unit.v` | Safe timing wrapper for the coordinate computer | Jagrati |
| `RTL/compute/fake_echo_gen.v` | Fake echoes from known positions, for testing without the PCB | Jagrati |
| `RTL/display/lcd1602_driver.v` | 1602A LCD driver, 4-bit mode | Jagrati |
| `RTL/display/bin2bcd.v` | Binary to decimal digits | Jagrati |
| `Constraints/ultrasonic_top.xdc` | Basys 3 pin assignments and timing | |
| `Sim/integration/tb_ultrasonic_top.v` | Full-system testbench | Jagrati |
| `Sim/integration/sim_xadc_reader.v` | Simulated receivers (simulation only) | Jagrati |
| `Sim/tx_controller/` | Unit testbenches for Zach's modules | Zach |
| `INTEGRATION.md` | Integration notes and detailed test plan | |

## Build in Vivado

Tested with Vivado 2026.1, part `xc7a35tcpg236-1` (Basys 3).

1. Create an RTL project for `xc7a35tcpg236-1`.
2. Add as design sources: `RTL/ultrasonic_top.v`, everything in
   `RTL/control`, `RTL/receive`, `RTL/compute`, `RTL/display`,
   `RTL/tx_controller`, plus `Coordinate_Computer.v`, `Square_Root.v`,
   `CSM_Row.v`, `CSM.v`.
3. Add `Constraints/ultrasonic_top.xdc`.
4. Create the XADC IP: IP Catalog -> XADC Wizard, component name `xadc_wiz_0`
   - Basic: DRP, Continuous, Channel Sequencer, DCLK 100 MHz, 1000 KSPS
   - ADC Setup: sequencer Continuous, no averaging
   - Alarms: all off
   - Channel Sequencer: only VAUXP6/N6, VAUXP7/N7, VAUXP14/N14 (unipolar)
5. Generate Bitstream, then Hardware Manager -> Program Device.

## Simulate

1. Add `Sim/integration/tb_ultrasonic_top.v` and
   `Sim/integration/sim_xadc_reader.v` as simulation sources, and set
   `tb_ultrasonic_top` as the simulation top.
2. Exclude the real reader from simulation: right-click
   `RTL/receive/xadc_reader.v` -> Source File Properties -> uncheck
   Simulation. Do the opposite for `sim_xadc_reader.v` (uncheck Synthesis
   and Implementation).
3. Run Behavioral Simulation, then `run all` in the Tcl console
   (about 1 minute).

Expected result:

```
 Tx: ch1 8, ch2 8, ch3 8 rising edges, counter 8
 demo target 0 (1500,1000)  D=1803 1000 1803  X= 1499 Y=1000  PASS
 demo target 1 (500,800)    D= 943 1281 2625  X=  499 Y= 798  PASS
 demo target 2 (2000,1500)  D=2500 1581 1803  X= 1999 Y=1500  PASS
 demo target 3 (1000,2000)  D=2236 2062 2828  X= 1000 Y=1999  PASS
 target (500,800)           D= 951 1290 2637  X=  491 Y= 809  PASS
 target (1500,1000)         D=1813 1008 1812  X= 1500 Y=1014  PASS
 receiver 3 silent          to=100 fix=0                       PASS
 RESULT: PASS
```

## Controls

One bitstream covers every test; choose with switches.

| Control | Function |
|---|---|
| btnU | Take one measurement |
| btnC | Reset |
| SW0-SW2 | Enable transmitter 1, 2, 3 |
| SW3-SW9 | Echo threshold (switch value x 4, in ADC codes) |
| SW10-SW11 | Fake-echo target 0-3 |
| SW12-SW13 | LCD page (see below) |
| SW14 | 1 = fake echoes (no PCB needed), 0 = real receivers |
| SW15 | Auto mode, 10 measurements per second |

| SW13 | SW12 | LCD page |
|---|---|---|
| off | off | Distances: `D1:1803 D2:1000` / `D3:1803  #0007` |
| off | on | Position: `X:+1499 Y:1000` / `Fix OK  #0007` |
| on | off | Echo levels: `P1 P2 P3` and threshold `Th` |
| on | on | Transmit check: `Cycles:08  OK` |

Fake-echo targets (mm): 0 = (1500, 1000), 1 = (500, 800),
2 = (2000, 1500), 3 = (1000, 2000).

LEDs: LED0-2 = echo received on channel 1-3, LED13 = fake mode,
LED14 = auto mode, LED15 toggles every measurement.

## Wiring

| Basys 3 | Connects to |
|---|---|
| JA1-JA4 | LCD D4-D7 (pins 11-14) |
| JA7 / JA8 | LCD RS (pin 4) / E (pin 6) |
| JA GND | LCD pins 1, 3 (contrast), 5 (RW), 16 |
| JA 3.3 V or a separate 5 V supply | LCD pins 2, 15 (5 V gives a brighter screen) |
| JB1-JB3 | PCB Tx driver inputs, channels 1-3 |
| JB4 | Scope trigger (burst enable, 200 us high) |
| JXADC 1 / 7 | Rx channel 1 output / ground |
| JXADC 2 / 8 | Rx channel 2 output / ground |
| JXADC 3 / 9 | Rx channel 3 output / ground |
| GND | Shared with the PCB |

Safety:
- JXADC inputs accept only **0 to 1 V**. Receiver outputs should idle near
  0.5 V.
- Never connect the PCB's 12 V or any 5 V supply to a Basys 3 pin; share
  ground only.
- Keep LCD pin 5 (RW) on ground so the LCD never drives the FPGA pins.

### PCB connections

| From | To |
|---|---|
| 12 V battery / supply | PCB power input (Tx drivers only, never the Basys 3) |
| Transmitters 1-3 (MA40S4S) | PCB Tx driver outputs 1-3 |
| Receivers 1-3 (MA40S4R) | PCB Rx amplifier inputs 1-3 |
| PCB ground | Basys 3 GND (JB pin 5 and JXADC pin 5) |

Mount the three transducer pairs in a straight line at x = 0, 1500 and
3000 mm, all facing the same direction, to match `Coordinate_Computer.v`.

**Check the receiver voltage before connecting JXADC.** With the PCB powered
and the JXADC wires disconnected, measure each Rx output against PCB ground:
- With a multimeter (DC volts): about 0.5 V with no echo.
- With a scope, while firing bursts (SW15 on): the signal must stay between
  0 V and 1 V at all times, including right after the burst.

If any output goes above 1 V or below 0 V, add a resistor divider or level
shift on that channel before connecting it.

Wire and test one channel at a time (transmitter, receiver, then distance)
before adding the next.

## Testing on hardware

Same bitstream for every step.

1. **Transmit check (no PCB):** SW0-2, SW12, SW13 on, press btnU ->
   `Cycles:08  OK`. On a scope, trigger on JB4 and probe JB1-3 for
   8 cycles at 40 kHz.
2. **Math check (no PCB):** SW14 on, SW12 on, press btnU -> `X:+1499 Y:1000`.
   Change SW10-11 for the other targets.
3. **Echo levels:** connect the PCB, SW14 off, SW13 on, nothing in front.
   Note P1-P3 (noise) and set the threshold (SW3-9) to 2-3 times that.
4. **Distances:** both page switches off, flat object at a tape-measured
   distance. Start with one sensor (SW0 only).
5. **Position:** SW12 on, object in front of all three sensors, SW15 on for
   live tracking.

## Status

| Part | Status |
|---|---|
| Transmit logic | Done, simulated |
| Measurement FSM and distance math | Done, tested on hardware with fake echoes |
| Debounce | Done, tested on hardware |
| LCD display | Done, tested on hardware |
| Echo detection | Done, simulated |
| Coordinate computer and square root | Done, simulated |
| Full system integration | Done, simulated (`RESULT: PASS`), bitstream builds |
| PCB (Tx drivers, Rx amplifiers and filters) | Built, awaiting integration |
| Velocity and direction | Not started |

## Known issues

- Echo detection reads slightly late on weak echoes (about 7-19 mm), which
  can be calibrated against a tape measure.
- Speed of sound changes about 0.6 m/s per degree C; room temperature
  shifts all distances by up to about 1 percent.
