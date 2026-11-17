# Ultrasonic Object Tracking System - FPGA integration

## How the modules connect

```
btnU -> debounce -> measurement_fsm x3 (started together)
                         |
                         +-> burst_generator -> frequency_generator -> JB1-JB3 -> PCB Tx
PCB Rx -> JXADC -> xadc_reader -> echo_detect x3 -> echo_valid to each FSM
                                         (or fake_echo_gen when SW14 is on)
3 distances (mm) -> coordinate_unit -> coordinate_computer -> X, Y
                                  -> CORDIC_Angle_Calculator -> angle -> lcd1602_driver
```

- `measurement_fsm` (three copies, one per sensor) controls timing: it fires
  the burst, ignores the receiver while the transducer rings down, waits for
  the echo and converts the time of flight to millimeters.
- Only the first FSM starts the burst; all three transmitters fire together
  and each receiver times its own echo.
- `coordinate_unit` holds the three distances steady for 150 clock cycles
  before reading `coordinate_computer`, because its dividers take longer than
  one 10 ns clock. It then feeds X and Y to `CORDIC_Angle_Calculator` and
  waits 8 cycles for its 8 combinational stages before latching the angle.

## Files

| Folder | Files | Owner |
|---|---|---|
| `RTL/` | `ultrasonic_top.v` (top level) | Jagrati |
| `RTL/tx_controller/` | `burst_generator.v`, `frequency_controller.v` | Zach |
| `RTL/control/` | `measurement_fsm.v`, `debounce.v` | Jagrati |
| `RTL/receive/` | `xadc_reader.v`, `echo_detect.v` | Jagrati |
| `RTL/compute/` | `coordinate_unit.v`, `fake_echo_gen.v` | Jagrati |
| `RTL/` | `Coordinate_Computer.v`, `Square_Root.v`, `CSM_Row.v`, `CSM.v` | Zach |
| `RTL/` | `Cordic_Angle_Calculator.v`, `cordic_iteration.v`, `cordic_angle_rom.v` | Zach |
| `RTL/display/` | `lcd1602_driver.v`, `bin2bcd.v` | Jagrati |
| `Constraints/` | `ultrasonic_top.xdc` | |
| `Sim/integration/` | `tb_ultrasonic_top.v`, `sim_xadc_reader.v` | Jagrati |
| `Sim/tx_controller/` | unit testbenches for the transmit and coordinate modules | Zach |

Every `.v` file under `RTL/` is part of the build.

## Vivado setup

1. New RTL project, part `xc7a35tcpg236-1`.
2. Add every `.v` file under `RTL/` as a design source.
3. Add `Constraints/ultrasonic_top.xdc`.
4. Set `ultrasonic_top` as top.
5. Create the XADC IP (needed for the bitstream, not for simulation):
   IP Catalog -> XADC Wizard, component name `xadc_wiz_0`
   - Basic: DRP interface, Continuous, Channel Sequencer, DCLK 100 MHz, 1000 KSPS
   - ADC Setup: sequencer mode Continuous, no averaging
   - Alarms: all off
   - Channel Sequencer: only VAUXP6/N6, VAUXP7/N7, VAUXP14/N14 (unipolar)
6. Generate Bitstream, then Hardware Manager -> Program Device.

## Simulation

1. Add `Sim/integration/tb_ultrasonic_top.v` and
   `Sim/integration/sim_xadc_reader.v` as simulation sources.
2. Both `xadc_reader.v` and `sim_xadc_reader.v` define the module
   `xadc_reader`, so keep them apart:
   - `RTL/receive/xadc_reader.v`: Source File Properties -> uncheck **Simulation**
   - `Sim/integration/sim_xadc_reader.v`: uncheck **Synthesis** and **Implementation**
3. Set `tb_ultrasonic_top` as the simulation top.
4. Run Behavioral Simulation, then `run all` (about 1 minute in Vivado).

## Pins

| Pin | Signal |
|---|---|
| JA1-JA4 | LCD D4-D7 |
| JA7 / JA8 | LCD RS / E |
| JB1, JB2, JB3 | Tx channel 1, 2, 3 -> PCB Tx drivers |
| JB4 | Burst enable, 200 us high (scope trigger) |
| JXADC 1 / 7 | Rx1 + / - |
| JXADC 2 / 8 | Rx2 + / - |
| JXADC 3 / 9 | Rx3 + / - |
| GND | shared with the PCB |

Receiver outputs must stay between 0 and 1 V, idling near 0.5 V. Never
connect the PCB's 12 V to any Basys 3 pin; share ground only.

## Controls

| Control | Function |
|---|---|
| btnU / btnC | measure once / reset |
| SW0-SW2 | enable Tx channel 1-3 |
| SW3-SW9 | echo threshold (value x 4) |
| SW10-SW11 | fake-echo target 0-3 |
| SW12-SW13 | LCD page (table below) |
| SW14 | 1 = fake echoes (no PCB), 0 = real receivers |
| SW15 | auto mode, 10 measurements/s |

| SW13 | SW12 | LCD page |
|---|---|---|
| off | off | Distances D1, D2, D3 |
| off | on | Position X, Y and angle |
| on | off | Echo levels P1-P3 and threshold |
| on | on | Transmit check |

Fake-echo targets (sensors at x = 0, 1500, 3000 mm, facing the same way):
0 = (1500, 1000), 1 = (500, 800), 2 = (2000, 1500), 3 = (1000, 2000).

## Test order (same bitstream every time)

1. **Tx check (no PCB).** SW0-SW2 on, SW12 and SW13 on, press btnU.
   LCD: `Cycles:08  OK`. Scope: trigger on JB4, probe JB1-JB3, expect
   8 cycles at 40 kHz.
2. **Math check (no PCB).** SW14 on, SW12 on, SW13 off, pick a target with
   SW10-SW11, press btnU. LCD shows that target's X and Y
   (target 0: `X:+1499 Y:1000`, `Ang:33.8`).
3. **Transmitters.** Connect JB1-JB3 and GND to the PCB. Start with SW0 only
   and check the 12 V burst on transmitter 1 with a scope, then add SW1, SW2.
4. **Echo levels.** Connect JXADC to the PCB (after confirming 0-1 V),
   SW14 off, SW13 on, SW12 off, nothing in front. Note P1-P3 (noise) and set
   the threshold (SW3-SW9) to 2-3 times that.
5. **Distances.** SW12 and SW13 off, flat object at a tape-measured distance.
   Check one sensor first, then all three.
6. **Position.** SW12 on, object in front of all three sensors, SW15 on for
   live tracking.

## Results so far

Simulation (Icarus Verilog and Vivado XSim, same results):

```
Tx: 8 rising edges on each channel
fake target (1500,1000) -> X 1499, Y 1000, angle 33.8 (true 33.7)
fake target (500,800)   -> X  499, Y  798, angle 57.9 (true 58.0)
fake target (2000,1500) -> X 1999, Y 1500, angle 36.5 (true 36.9)
fake target (1000,2000) -> X 1000, Y 1999, angle 63.3 (true 63.4)
simulated receivers (500,800)   -> X  491, Y  809, angle 58.8
simulated receivers (1500,1000) -> X 1499, Y 1013, angle 33.8
receiver 3 silent -> "No fix"
RESULT: PASS
```

Hardware build: synthesis, implementation and bitstream complete. The XADC
IP is generated correctly.

## Open items

- **Sensor mounting:** the coordinate math assumes sensors in a straight line
  at 0, 1500 and 3000 mm. Update `Coordinate_Computer.v` if the mounting
  differs.
- **Receiver voltage:** confirm the PCB receiver outputs stay within 0-1 V
  before connecting JXADC.
- **Three-sensor interference:** all transmitters currently fire together.
  If receivers pick up each other's pulses, fire them one at a time using
  SW0-SW2.
