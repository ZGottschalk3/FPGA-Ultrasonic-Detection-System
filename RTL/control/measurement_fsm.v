`timescale 1ns / 1ps
//======================================================================
//  measurement_fsm.v
//  ECE-3337 : FPGA-Based Ultrasonic Target Detection
//  Owner    : Jagrati Kumari  (Control / System Integration / Timing)
//
//  Sequences one complete ultrasonic range measurement:
//
//     IDLE -> TX -> BLANK -> LISTEN -> CALC -> DONE -> IDLE
//
//  Interfaces to the rest of the system:
//     tx_start   -> burst generator      (Zach)
//     tx_done    <- burst generator      (Zach)
//     window_open-> sample acquisition   (Zach)
//     echo_valid <- peak detector        (Zach)
//     distance_mm-> display / UART
//
//  Timing basis: 100 MHz Basys 3 clock  ->  10 ns per tick
//                343 m/s speed of sound ->  1.715 um of range per tick
//======================================================================

module measurement_fsm #(
    // ---- timing parameters (all in 100 MHz clock ticks) ----------------
    parameter integer BURST_TICKS  = 20_000,    // 200 us burst  (Zach's spec)
    parameter integer BLANK_TICKS  = 100_000,   // 1 ms ringdown (window opens at 205 mm)
    parameter integer WINDOW_TICKS = 3_000_000, // 30 ms window  -> 5.15 m max range

    // ---- fixed-point distance conversion -------------------------------
    //   distance_mm = (tof_ticks * MM_SCALE + half) >> MM_SHIFT
    //   28773 / 2^24 = 0.0017150018 mm per tick
    //   true value   = 0.001715      mm per tick   (error 0.0001%, ~5 um at 5 m)
    parameter integer MM_SCALE     = 28_773,
    parameter integer MM_SHIFT     = 24,

    // ---- echo detection latency compensation ----------------------------
    //   echo_valid arrives a fixed number of ticks after the echo actually
    //   crossed the threshold (the detector's hold time). That many ticks
    //   are subtracted from the measured time. 0 = no compensation.
    parameter integer ECHO_LATENCY_TICKS = 0
)(
    input  wire        clk,
    input  wire        rst,          // synchronous, active high

    input  wire        trigger,      // start one measurement (button or auto-repeat)
    input  wire        tx_done,      // burst generator finished transmitting
    input  wire        echo_valid,   // peak detector found the echo

    output reg         tx_start,     // one-cycle pulse: fire the burst
    output reg         window_open,  // acquisition window / ADC capture enable
    output reg  [21:0] tof_ticks,    // raw time-of-flight in clock ticks
    output reg  [12:0] distance_mm,  // converted range, 0..5145 mm
    output reg         result_valid, // one-cycle pulse: distance_mm is fresh
    output reg         timeout,      // sticky: no echo found in this window
    output wire [2:0]  state_out     // exposed for simulation waveforms
);

    // ---- state encoding --------------------------------------------------
    localparam [2:0] S_IDLE   = 3'd0,
                     S_TX     = 3'd1,
                     S_BLANK  = 3'd2,
                     S_LISTEN = 3'd3,
                     S_CALC   = 3'd4,
                     S_DONE   = 3'd5,
                     S_CALC2  = 3'd6;

    reg [2:0]  state;
    reg [21:0] cnt;               // ticks since the burst started

    assign state_out = state;

    // window opens once burst + ringdown have passed
    localparam integer WINDOW_START = BURST_TICKS + BLANK_TICKS;

    // ---- fixed-point multiply (infers one DSP48 slice) -------------------
    //   22-bit tof x 15-bit scale = 37-bit product (max 8.63e10)
    localparam [14:0] SCALE = MM_SCALE[14:0];
    wire [37:0] prod = tof_ticks * SCALE;
    reg  [37:0] prod_q;           // product stored between the two calc steps

    // round half up instead of truncating: add 0.5 LSB before the shift.
    // Without this every result reads ~1 mm low.
    // Done one clock AFTER the multiply so each step fits in 10 ns on hardware.
    wire [37:0] prod_rnd = prod_q + (38'd1 << (MM_SHIFT - 1));

    always @(posedge clk) begin
        if (rst) begin
            state        <= S_IDLE;
            cnt          <= 22'd0;
            tx_start     <= 1'b0;
            window_open  <= 1'b0;
            tof_ticks    <= 22'd0;
            distance_mm  <= 13'd0;
            result_valid <= 1'b0;
            timeout      <= 1'b0;
            prod_q       <= 38'd0;
        end else begin
            // defaults: single-cycle pulses self-clear
            tx_start     <= 1'b0;
            result_valid <= 1'b0;

            case (state)

            //--------------------------------------------------------------
            S_IDLE: begin
                cnt         <= 22'd0;
                window_open <= 1'b0;
                if (trigger) begin
                    tx_start <= 1'b1;   // kick Zach's burst generator
                    timeout  <= 1'b0;
                    state    <= S_TX;
                end
            end

            //--------------------------------------------------------------
            // Burst is in the air. Counting starts here because the echo's
            // leading edge lines up with the burst's leading edge.
            S_TX: begin
                cnt <= cnt + 1'b1;
                if (tx_done)
                    state <= S_BLANK;
            end

            //--------------------------------------------------------------
            // Transducer is still ringing down. Receiver is deaf, so stay
            // shut to avoid latching our own transmission as an echo.
            S_BLANK: begin
                cnt <= cnt + 1'b1;
                if (cnt >= WINDOW_START - 1) begin
                    window_open <= 1'b1;
                    state       <= S_LISTEN;
                end
            end

            //--------------------------------------------------------------
            // Acquisition window. First valid peak wins.
            S_LISTEN: begin
                cnt <= cnt + 1'b1;
                if (echo_valid) begin
                    tof_ticks   <= cnt - ECHO_LATENCY_TICKS;
                    window_open <= 1'b0;
                    state       <= S_CALC;
                end else if (cnt >= WINDOW_TICKS - 1) begin
                    window_open <= 1'b0;
                    timeout     <= 1'b1;
                    state       <= S_DONE;
                end
            end

            //--------------------------------------------------------------
            // Two short steps instead of one long one, so the math meets
            // the 10 ns clock period on real hardware.
            S_CALC: begin                 // step 1: multiply
                prod_q <= prod;
                state  <= S_CALC2;
            end

            S_CALC2: begin                // step 2: round and shift
                distance_mm <= prod_rnd[37:MM_SHIFT];
                state       <= S_DONE;
            end

            //--------------------------------------------------------------
            S_DONE: begin
                result_valid <= 1'b1;   // one-cycle strobe for display / UART
                state        <= S_IDLE;
            end

            //--------------------------------------------------------------
            default: state <= S_IDLE;

            endcase
        end
    end

endmodule
