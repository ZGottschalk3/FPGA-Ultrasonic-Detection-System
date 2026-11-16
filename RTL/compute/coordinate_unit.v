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
//   4. latch X and Y and pulse result_valid
// The constraints file marks the frozen-distance paths as multicycle.
//////////////////////////////////////////////////////////////////////////////////

module coordinate_unit #(
    parameter integer SETTLE_TICKS = 150,   // 1.5 us for the dividers
    parameter integer SQRT_TICKS   = 24     // square_root needs 16 cycles
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               start,         // one-cycle: new distances ready
    input  wire        [12:0] d1_mm, d2_mm, d3_mm,
    output reg  signed [15:0] x_mm,
    output reg         [15:0] y_mm,
    output reg                result_valid
);
    reg [31:0] d1_q, d2_q, d3_q;
    reg        sqrt_start;
    reg [7:0]  cnt;
    reg [1:0]  st;
    localparam S_IDLE = 2'd0, S_SETTLE = 2'd1, S_SQRT = 2'd2;

    wire [15:0] x_raw, y_raw;
    coordinate_computer u_cc (
        .D1(d1_q), .D2(d2_q), .D3(d3_q),
        .clk(clk), .rst(rst), .start(sqrt_start),
        .X_Coordinate(x_raw), .Y_Coordinate(y_raw));

    always @(posedge clk) begin
        sqrt_start   <= 1'b0;
        result_valid <= 1'b0;
        if (rst) begin
            st <= S_IDLE; cnt <= 0; d1_q <= 0; d2_q <= 0; d3_q <= 0;
            x_mm <= 0; y_mm <= 0;
        end else case (st)
            S_IDLE: if (start) begin
                d1_q <= {19'd0, d1_mm}; d2_q <= {19'd0, d2_mm}; d3_q <= {19'd0, d3_mm};
                cnt <= 0; st <= S_SETTLE;
            end
            S_SETTLE: if (cnt == SETTLE_TICKS - 1) begin
                cnt <= 0; sqrt_start <= 1'b1; st <= S_SQRT;
            end else cnt <= cnt + 1'b1;
            S_SQRT: if (cnt == SQRT_TICKS - 1) begin
                x_mm <= x_raw; y_mm <= y_raw; result_valid <= 1'b1; st <= S_IDLE;
            end else cnt <= cnt + 1'b1;
            default: st <= S_IDLE;
        endcase
    end
endmodule
