`timescale 1ns / 1ps
//======================================================================
//  debounce.v
//  ECE-3337 : FPGA-Based Ultrasonic Target Detection
//  Owner    : Jagrati Kumari  (Control / System Integration)
//
//  Cleans up a mechanical button/switch and produces a single-cycle
//  pulse the instant a stable press is recognized. Feeds directly into
//  measurement_fsm's `trigger` input.
//
//  Method: sample the raw input every clock, and only accept it as the
//  new stable value once it has held steady for DEBOUNCE_TICKS in a row.
//  At 100 MHz, 1,000,000 ticks = 10 ms, comfortably longer than typical
//  mechanical bounce (usually settles within 1-5 ms).
//======================================================================

module debounce #(
    parameter integer DEBOUNCE_TICKS = 1_000_000   // 10 ms at 100 MHz
)(
    input  wire clk,
    input  wire rst,
    input  wire btn_raw,     // straight from the physical pin, unclean
    output reg  pulse_out    // one-cycle pulse on a confirmed press
);

    reg        btn_sync_0, btn_sync_1;   // two-stage sync, crosses clock domains safely
    reg        btn_stable;               // debounced, level-held value
    reg        btn_stable_prev;          // previous cycle's stable value, for edge detect
    reg [20:0] cnt;                      // counts how long btn_sync_1 has held steady

    // ---- stage 1: synchronize the raw pin into this clock domain ----------
    // A button isn't tied to your clock, so without this, its transitions
    // can arrive mid-clock-edge and cause unpredictable behavior downstream.
    always @(posedge clk) begin
        if (rst) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_raw;
            btn_sync_1 <= btn_sync_0;
        end
    end

    // ---- stage 2: only accept a new value once it's held steady -----------
    always @(posedge clk) begin
        if (rst) begin
            cnt        <= 21'd0;
            btn_stable <= 1'b0;
        end else if (btn_sync_1 != btn_stable) begin
            // input disagrees with what we currently trust: it might be
            // real, might be bounce. Start/continue counting.
            cnt <= cnt + 1'b1;
            if (cnt >= DEBOUNCE_TICKS - 1) begin
                btn_stable <= btn_sync_1;   // held long enough, accept it
                cnt        <= 21'd0;
            end
        end else begin
            cnt <= 21'd0;                  // agrees already, nothing to count
        end
    end

    // ---- stage 3: turn the stable level into a one-cycle pulse ------------
    // measurement_fsm's `trigger` expects a pulse, not a held-high level,
    // otherwise it would keep re-triggering every cycle the button is held.
    always @(posedge clk) begin
        if (rst) begin
            btn_stable_prev <= 1'b0;
            pulse_out       <= 1'b0;
        end else begin
            btn_stable_prev <= btn_stable;
            pulse_out       <= btn_stable & ~btn_stable_prev;  // rising edge only
        end
    end

endmodule
