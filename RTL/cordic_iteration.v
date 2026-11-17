`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Texas Tech University Department of Electrical and Computer Engineering
// Zachary Gottschalk
//
// Design Name: CORDIC Angle Calculator
// Module Name: cordic_iteration
// Project Name: Ultrasonic_Object_Tracking System
//
// Description:
// Individual CORDIC vectoring iteration.
// Calculates updated X, Y, and angle values.
//
// Angle representation: Q16.16 (degrees)
// Operating Mode: Vectoring
//////////////////////////////////////////////////////////////////////////////////

module cordic_iteration #(
    parameter integer ITERATION = 0
)(
    input  wire signed [15:0] x_in,
    input  wire signed [15:0] y_in,

    input  wire signed [31:0] z_in,
    input  wire signed [31:0] angle_const,

    output wire signed [15:0] x_out,
    output wire signed [15:0] y_out,
    output wire signed [31:0] z_out
);

    wire direction;

    assign direction = y_in[15];

    wire signed [15:0] x_shift;
    wire signed [15:0] y_shift;

    assign x_shift = x_in >>> ITERATION;
    assign y_shift = y_in >>> ITERATION;

    assign x_out = (y_in == 0) ? x_in :
                   direction ? x_in - y_shift :
                               x_in + y_shift;

    assign y_out = (y_in == 0) ? y_in :
                   direction ? y_in + x_shift :
                               y_in - x_shift;

    assign z_out = (y_in == 0) ? z_in :
                   direction ? z_in - angle_const :
                               z_in + angle_const;

endmodule
