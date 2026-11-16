# Ultrasonic Object Tracking System - FPGA build

## Files

| Folder | Files | Owner |
|---|---|---|
| `RTL/` | `ultrasonic_top.v` (top level) | Jagrati |
| `RTL/tx_controller/` | `burst_generator.v`, `frequency_controller.v` | Zach |
| `RTL/control/` | `measurement_fsm.v`, `debounce.v` | Jagrati |
| `RTL/receive/` | `xadc_reader.v`, `echo_detect.v` | Jagrati |
| `RTL/compute/` | `coordinate_unit.v`, `fake_echo_gen.v` | Jagrati |
| `RTL/` | `Coordinate_Computer.v`, `Square_Root.v`, `CSM_Row.v`, `CSM.v` | Zach |
| `RTL/display/` | `lcd1602_driver.v`, `bin2bcd.v` | Jagrati |
| `Constraints/` | `ultrasonic_top.xdc` | |
| `Sim/integration/` | `tb_ultrasonic_top.v`, `sim_xadc_reader.v` | |

Not used in the build: `distance_calculator.v` and `Sensor_Localization_System.v`
(temporary test files), and the empty placeholders `adc_controller.v`,
`filter.v`, `correlator.v`, `peak_detector.v`, `sample_buffer.v`,
`tof_calculator.v`, `waveform_generator.v`, `clock_divider.v`.

## Vivado setup

1. New RTL project, part `xc7a35tcpg236-1`.
2. Add every `.v` file in the table above (all of `RTL/` except the unused ones).
3. Add `Constraints/ultrasonic_top.xdc`.
4. IP Catalog -> XADC Wizard, component name `xadc_wiz_0`:
   - Basic: DRP interface, Continuous, Channel Sequencer, DCLK 100 MHz, 1000 KSPS
   - ADC Setup: sequencer mode Continuous, no averaging
   - Alarms: all off
   - Channel Sequencer: VAUXP6/N6, VAUXP7/N7, VAUXP14/N14 (unipolar), nothing else
5. Set `ultrasonic_top` as top, Generate Bitstream, program.

Simulation: add `Sim/integration/tb_ultrasonic_top.v` and
`Sim/integration/sim_xadc_reader.v` as simulation sources, and **disable**
`RTL/receive/xadc_reader.v` for simulation (right-click -> Properties ->
uncheck "Simulation"). Run all; it ends with `RESULT: PASS`.

## Pins

| Pin | Signal |
|---|---|
| JB1, JB2, JB3 | Tx channel 1, 2, 3 -> PCB Tx drivers |
| JB4 | Burst enable, 200 us high (scope trigger) |
| JXADC 1 / 7 | Rx1 + / - |
| JXADC 2 / 8 | Rx2 + / - |
| JXADC 3 / 9 | Rx3 + / - |
| JA | LCD |
| GND | shared with the PCB |

Receiver outputs must stay between 0 and 1 V, idling near 0.5 V.

## Controls

| Control | Function |
|---|---|
| btnU / btnC | measure once / reset |
| SW0-SW2 | enable Tx channel 1-3 |
| SW3-SW9 | echo threshold (value x 4) |
| SW10-SW11 | fake-echo target 0-3 |
| SW12-SW13 | LCD page: 0 distances, 1 X/Y, 2 echo levels, 3 Tx check |
| SW14 | 1 = fake echoes (no PCB), 0 = real receivers |
| SW15 | auto mode, 10 measurements/s |

Fake-echo targets (sensors at x = 0, 1500, 3000 mm):
0 = (1500, 1000), 1 = (500, 800), 2 = (2000, 1500), 3 = (1000, 2000).

## Test order (same bitstream every time)

1. **Tx check.** SW0-2 on, SW12-13 = 3, press btnU. LCD: `Cycles:08 OK`.
   Scope: trigger on JB4, probe JB1-3, expect 8 cycles at 40 kHz.
2. **Math check, no PCB.** SW14 on, SW12-13 = 1, pick a target with
   SW10-11, press btnU. LCD shows that target's X and Y.
3. **Echo levels.** Connect the PCB, SW14 off, SW12-13 = 2, nothing in front.
   Note P1-P3 (noise). Set the threshold (SW3-9) to 2-3x that.
4. **Distances.** SW12-13 = 0, flat object at a tape-measured distance.
5. **Position.** SW12-13 = 1, object in front of all three sensors, SW15 on.

Demo day: start with step 2 (always works), then show steps 4 and 5 live.

## Simulation results

```
Tx: 8 rising edges on each channel
fake target (1500,1000) -> X 1499, Y 1000
fake target (500,800)   -> X  499, Y  798
fake target (2000,1500) -> X 1999, Y 1500
fake target (1000,2000) -> X 1000, Y 1999
simulated receivers (500,800)   -> X 491,  Y 809
simulated receivers (1500,1000) -> X 1499, Y 1013
receiver 3 silent -> "No fix"
RESULT: PASS
```
