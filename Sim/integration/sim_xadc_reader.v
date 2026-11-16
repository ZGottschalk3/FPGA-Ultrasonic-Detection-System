`timescale 1ns / 1ps
//======================================================================
//  sim_xadc_reader.v   SIMULATION ONLY - use instead of xadc_reader.v
//  Round-robin conversions every 1 us (ch0, ch1, ch2, ...), each channel
//  carries: 0.5 V bias (2048) + noise + transducer ringdown after the
//  burst + a 40 kHz echo at the delay set in tb_ultrasonic_top.
//======================================================================
module xadc_reader (
    input  wire        clk, rst,
    input  wire        vauxp6, vauxn6, vauxp14, vauxn14, vauxp7, vauxn7,
    output reg  [11:0] sample,
    output reg  [1:0]  sample_ch,
    output reg         sample_valid
);
    integer div = 0, v, ch = 0;
    real t, te, s, amp;
    integer dly;
    localparam real TWO_PI = 6.283185307;
    function real envf; input real x;
        if (x < 0) envf = 0; else if (x < 10000) envf = x/10000.0;
        else if (x < 20000) envf = 1.0; else if (x < 35000) envf = 1.0-(x-20000)/15000.0; else envf = 0;
    endfunction
    always @(posedge clk) begin
        sample_valid <= 1'b0;
        if (div == 99) begin
            div <= 0;
            t = tb_ultrasonic_top.now - tb_ultrasonic_top.t0;
            s = 2048.0 + ($random % 21);
            if (t >= 0 && t < 20000) s = s + 1200.0*$sin(TWO_PI*t/2500.0);
            else if (t >= 20000 && t < 110000) s = s + 1200.0*$exp(-(t-20000.0)/15000.0)*$sin(TWO_PI*t/2500.0);
            case (ch) 0: begin dly = tb_ultrasonic_top.dly0; amp = tb_ultrasonic_top.amp0; end
                      1: begin dly = tb_ultrasonic_top.dly1; amp = tb_ultrasonic_top.amp1; end
                      default: begin dly = tb_ultrasonic_top.dly2; amp = tb_ultrasonic_top.amp2; end endcase
            te = t - dly;
            s = s + amp * envf(te) * $sin(TWO_PI*te/2500.0);
            v = $rtoi(s); if (v < 0) v = 0; if (v > 4095) v = 4095;
            sample <= v[11:0]; sample_ch <= ch[1:0]; sample_valid <= 1'b1;
            ch = (ch == 2) ? 0 : ch + 1;
        end else div <= div + 1;
    end
endmodule
