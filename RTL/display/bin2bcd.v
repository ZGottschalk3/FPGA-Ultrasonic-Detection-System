`timescale 1ns / 1ps
//======================================================================
//  bin2bcd.v
//  Converts a binary number (0..9999) into 4 decimal digits so the LCD
//  can print it. Uses the "double dabble" method: 14 clock cycles.
//  Output: bcd[15:12] = thousands, [11:8] = hundreds, [7:4] = tens,
//          [3:0] = ones.
//======================================================================
module bin2bcd (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [13:0] bin,       // must be 0..9999
    output reg  [15:0] bcd
);
    reg        busy;
    reg [13:0] sh;
    reg [15:0] acc;
    reg [3:0]  n;

    wire [3:0] a3 = acc[15:12], a2 = acc[11:8], a1 = acc[7:4], a0 = acc[3:0];
    wire [15:0] adj = { (a3 >= 4'd5) ? a3 + 4'd3 : a3,
                        (a2 >= 4'd5) ? a2 + 4'd3 : a2,
                        (a1 >= 4'd5) ? a1 + 4'd3 : a1,
                        (a0 >= 4'd5) ? a0 + 4'd3 : a0 };

    always @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0; bcd <= 16'd0; acc <= 16'd0; sh <= 14'd0; n <= 4'd0;
        end else if (!busy) begin
            if (start) begin
                sh <= bin; acc <= 16'd0; n <= 4'd0; busy <= 1'b1;
            end
        end else begin
            acc <= {adj[14:0], sh[13]};
            sh  <= {sh[12:0], 1'b0};
            n   <= n + 1'b1;
            if (n == 4'd13) begin
                busy <= 1'b0;
                bcd  <= {adj[14:0], sh[13]};
            end
        end
    end
endmodule
