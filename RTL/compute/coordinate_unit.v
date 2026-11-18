`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Texas Tech University Department of Electrical and Computer Engineering
// Jagrati Kumari (integration wrapper around Zach's coordinate_computer)
//
// Module Name: coordinate_unit
//
// coordinate_computer computes X with large dividers that take far longer
// than one 10 ns clock. This wrapper makes that safe on hardware:
//   1. freeze the three distances in registers
//   2. wait SETTLE_TICKS so the combinational math finishes
//   3. pulse start to the square root, wait for it to finish
//   4. latch X and Y
//   5. feed X, Y to Zach's CORDIC_Angle_Calculator, wait ANGLE_TICKS for
//      its 8 combinational stages, latch the angle, pulse result_valid
//
// angle_q16 = atan2(Y, X) in degrees, Q16.16, i.e. the bearing of the
// object seen from sensor 1, measured from the line of sensors.
// angle_valid = 0 when X <= 0 (outside the CORDIC's range).
// The constraints file marks the frozen-distance paths as multicycle.
//////////////////////////////////////////////////////////////////////////////////

module coordinate_unit #(
    parameter integer SETTLE_TICKS = 150,   // 1.5 us for the dividers
    parameter integer SQRT_TICKS   = 24,    // square_root needs 16 cycles
    parameter integer ANGLE_TICKS  = 8      // CORDIC chain settles within 8 cycles
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               start,         // one-cycle: new distances ready
    input  wire        [12:0] d1_mm, d2_mm, d3_mm,
    output reg  signed [15:0] x_mm,
    output reg         [15:0] y_mm,
    output reg  signed [31:0] angle_q16,
    output reg                angle_valid,
    output reg                result_valid
);
    reg [31:0] d1_q, d2_q, d3_q;
    reg        sqrt_start;
    reg [7:0]  cnt;
    reg [1:0]  st;
    localparam S_IDLE = 2'd0, S_SETTLE = 2'd1, S_SQRT = 2'd2, S_ANGLE = 2'd3;

    wire [15:0] x_raw, y_raw;
    coordinate_computer u_cc (
        .D1(d1_q), .D2(d2_q), .D3(d3_q),
        .clk(clk), .rst(rst), .start(sqrt_start),
        .X_Coordinate(x_raw), .Y_Coordinate(y_raw));

    wire signed [31:0] angle_raw;
    CORDIC_Angle_Calculator u_angle (
        .x_in(x_mm), .y_in(y_mm), .angle_out(angle_raw));

    always @(posedge clk) begin
        sqrt_start   <= 1'b0;
        result_valid <= 1'b0;
        if (rst) begin
            st <= S_IDLE; cnt <= 0; d1_q <= 0; d2_q <= 0; d3_q <= 0;
            x_mm <= 0; y_mm <= 0; angle_q16 <= 0; angle_valid <= 0;
        end else case (st)
            S_IDLE: if (start) begin
                d1_q <= {19'd0, d1_mm}; d2_q <= {19'd0, d2_mm}; d3_q <= {19'd0, d3_mm};
                cnt <= 0; st <= S_SETTLE;
            end
            S_SETTLE: if (cnt == SETTLE_TICKS - 1) begin
                cnt <= 0; sqrt_start <= 1'b1; st <= S_SQRT;
            end else cnt <= cnt + 1'b1;
            S_SQRT: if (cnt == SQRT_TICKS - 1) begin
                x_mm <= x_raw; y_mm <= y_raw; cnt <= 0; st <= S_ANGLE;
            end else cnt <= cnt + 1'b1;
            S_ANGLE: if (cnt == ANGLE_TICKS - 1) begin
                angle_q16    <= angle_raw;
                angle_valid  <= (x_mm > 0);
                result_valid <= 1'b1;
                st <= S_IDLE;
            end else cnt <= cnt + 1'b1;
            default: st <= S_IDLE;
        endcase
    end
endmodule
