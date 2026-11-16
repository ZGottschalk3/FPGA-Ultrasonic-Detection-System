`timescale 1ns / 1ps
//======================================================================
//  echo_detect.v
//  ECE-3337 : Ultrasonic Object Tracking System
//
//  Finds the moment a real echo arrives in the digitized receiver signal
//  and pulses echo_valid to the measurement FSM.
//
//  Signal path (one step per new ADC sample, 1 sample per microsecond):
//    1. Baseline : slow average of the signal = its DC level (~0.5 V bias)
//    2. Remove DC: diff = sample - baseline   (the 40 kHz part only)
//    3. Rectify  : |diff|                     (flip negative half-cycles up)
//    4. Envelope : fast average of |diff|     (overall loudness, ripple removed)
//    5. Decide   : after the window opens, first wait for QUIET_SAMPLES of
//                  quiet (so an echo or ringdown already in progress is
//                  ignored), then fire one echo_valid pulse when the
//                  envelope stays above threshold for HOLD_SAMPLES in a row
//
//  Only the first echo in each window is reported, so later reflections
//  (walls, floor) are ignored. peak_env reports the loudest envelope seen
//  in the last window (tracked for POST_SAMPLES after detection so the
//  full echo is captured), which is used to tune the threshold in the lab.
//======================================================================
module echo_detect #(
    parameter integer BASE_SHIFT   = 8,    // baseline averages ~256 samples (256 us)
    parameter integer ENV_SHIFT    = 4,    // envelope averages ~16 samples (16 us)
    parameter integer HOLD_SAMPLES = 10,   // must stay loud for 10 us to count
    parameter integer QUIET_SAMPLES = 20,  // must hear 20 us of quiet before arming
    parameter integer POST_SAMPLES  = 300  // keep measuring peak 300 us after detection
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_valid,  // one-cycle strobe from the ADC reader
    input  wire [11:0] sample,        // 0..4095 (0..1 V on the XADC)
    input  wire        window_open,   // from measurement_fsm
    input  wire        tx_start,      // from measurement_fsm: a new burst is firing
    input  wire [11:0] threshold,     // envelope level that counts as an echo
    output reg         echo_valid,    // one-cycle pulse: echo detected
    output wire [11:0] envelope,      // current envelope (debug)
    output reg  [11:0] peak_env       // loudest envelope in the last window
);
    // ---- 1. baseline (DC level), starts at mid-scale --------------------
    reg  [11+BASE_SHIFT:0] base_acc;
    wire [11:0]            base = base_acc[11+BASE_SHIFT:BASE_SHIFT];

    // ---- 2-3. remove DC and rectify ---------------------------------------
    wire signed [12:0] diff = $signed({1'b0, sample}) - $signed({1'b0, base});
    wire        [11:0] rect = diff[12] ? -diff[11:0] : diff[11:0];

    // ---- 4. envelope ------------------------------------------------------
    reg  [11+ENV_SHIFT:0] env_acc;
    assign envelope = env_acc[11+ENV_SHIFT:ENV_SHIFT];

    always @(posedge clk) begin
        if (rst) begin
            base_acc <= {12'd2048, {BASE_SHIFT{1'b0}}};
            env_acc  <= 0;
        end else if (sample_valid) begin
            // acc = acc - acc/2^N + new  (running average, no divider)
            base_acc <= base_acc - base     + sample;
            env_acc  <= env_acc  - envelope + rect;
        end
    end

    // ---- 5. decision ------------------------------------------------------
    localparam [1:0] D_OFF = 2'd0, D_QUIET = 2'd1, D_ARMED = 2'd2, D_POST = 2'd3;
    reg [1:0]  dstate;
    reg        win_q;          // window_open last cycle (edge detect)
    reg [8:0]  run_cnt;        // consecutive quiet / loud samples, or post count
    reg [11:0] peak_run;       // running peak

    always @(posedge clk) begin
        echo_valid <= 1'b0;
        if (rst) begin
            dstate <= D_OFF; win_q <= 1'b0; run_cnt <= 0; peak_run <= 0; peak_env <= 0;
        end else begin
            win_q <= window_open;
            if (window_open && !win_q) begin                 // window just opened
                dstate <= D_QUIET; run_cnt <= 0; peak_run <= 0;
            end else begin
                if (sample_valid && dstate != D_OFF && envelope > peak_run)
                    peak_run <= envelope;
                case (dstate)
                D_QUIET: if (!window_open) begin dstate <= D_OFF; peak_env <= peak_run; end
                         else if (sample_valid) begin
                             if (envelope > threshold) run_cnt <= 0;       // still loud
                             else if (run_cnt == QUIET_SAMPLES - 1) begin
                                 run_cnt <= 0; dstate <= D_ARMED;          // quiet: arm
                             end else run_cnt <= run_cnt + 1'b1;
                         end
                D_ARMED: if (!window_open) begin dstate <= D_OFF; peak_env <= peak_run; end
                         else if (sample_valid) begin
                             if (envelope > threshold) begin
                                 if (run_cnt == HOLD_SAMPLES - 1) begin
                                     echo_valid <= 1'b1;                   // first echo found
                                     run_cnt    <= 0;
                                     dstate     <= D_POST;                 // ignore later ones
                                 end else run_cnt <= run_cnt + 1'b1;
                             end else run_cnt <= 0;                        // dropped: restart
                         end
                D_POST:  if (tx_start) begin                               // new burst: stop now
                             dstate <= D_OFF; peak_env <= peak_run;
                         end else if (sample_valid) begin                  // finish peak measurement
                             if (run_cnt == POST_SAMPLES - 1) begin
                                 dstate <= D_OFF; peak_env <= peak_run;
                             end else run_cnt <= run_cnt + 1'b1;
                         end
                default: ;
                endcase
            end
        end
    end
endmodule
