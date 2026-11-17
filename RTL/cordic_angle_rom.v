`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Texas Tech University Department of Electrical and Computer Engineering
// Zachary Gottschalk
//
// Create Date: 09/27/2026
// Design Name: CORDIC Angle Calculator 
// Module Name: cordic_angle_rom
// Project Name: Ultrasonic_Object_Tracking System
//////////////////////////////////////////////////////////////////////////////////


module cordic_angle_rom(
    input  wire [2:0] iteration,
    output reg  [31:0] angle
);

always @(*) begin
    case(iteration)
        3'd0: angle = 32'h002D0000; // 45.0000
        3'd1: angle = 32'h001A90E5; // 26.5651
        3'd2: angle = 32'h000E0943; // 14.0362
        3'd3: angle = 32'h00072000; // 7.1250
        3'd4: angle = 32'h00039388; // 3.5763
        3'd5: angle = 32'h0001CA35; // 1.7899
        3'd6: angle = 32'h0000E52B; // 0.8952
        3'd7: angle = 32'h00007296; // 0.4476
        default: angle = 32'h00000000;
    endcase
end
endmodule
