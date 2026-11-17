
`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Texas Tech University Department of Electrical and Computer Engineering
// 
// Design Name: CORDIC Angle Calculator
// Module Name: cordic_top
// Project Name: Ultrasonic_Object_Tracking System
//
// Description:
// Top-level CORDIC module connecting eight CORDIC iterations
// with an angle ROM to calculate the angle of an input vector.
//
// Inputs:
// x_in      - 16-bit signed X coordinate
// y_in      - 16-bit signed Y coordinate
//
// Outputs:
// angle_out - 32-bit signed angle in Q16.16 degrees
//
// Notes:
// - Uses vectoring-mode CORDIC
// - Eight combinational iterations
// - Assumes positive X for the initial implementation
//
//////////////////////////////////////////////////////////////////////////////////

module CORDIC_Angle_Calculator (

    input wire signed [15:0] x_in,
    input wire signed [15:0] y_in,

    output wire signed [31:0] angle_out

);

    // Internal X, Y, and Z signals
    wire signed [15:0] x_stage [0:8];
    wire signed [15:0] y_stage [0:8];

    wire signed [31:0] z_stage [0:8];

    // Angle ROM outputs
    wire signed [31:0] angle_const [0:7];

    // Initial conditions
    assign x_stage[0] = x_in;
    assign y_stage[0] = y_in;
    assign z_stage[0] = 32'sd0;

    genvar i;

    generate

        for (i = 0; i < 8; i = i + 1) begin : CORDIC_STAGES

            cordic_angle_rom angle_rom (

                .iteration(i),
                .angle(angle_const[i])

            );
            cordic_iteration #(
                .ITERATION(i)
            ) iteration_stage (

                .x_in(x_stage[i]),
                .y_in(y_stage[i]),
                .z_in(z_stage[i]),

                .angle_const(angle_const[i]),

                .x_out(x_stage[i+1]),
                .y_out(y_stage[i+1]),
                .z_out(z_stage[i+1])
            );
        end
    endgenerate
    assign angle_out = z_stage[8];
endmodule
