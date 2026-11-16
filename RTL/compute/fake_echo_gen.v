`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Texas Tech University Department of Electrical and Computer Engineering
// Jagrati Kumari
//
// Module Name: fake_echo_gen
//
// Demo / test stand-in for the three receivers (SW14 = 1). After each burst
// it fires echo_valid on each channel at the exact time a real echo from a
// known target would arrive, so the full chain (FSMs -> coordinate math ->
// LCD) can be tested and demonstrated without the PCB.
//
// Sensors at x = 0, 1500, 3000 mm (y = 0). Delays = distance x 583.09 ticks/mm.
//   pt 0: (1500, 1000) -> 1803, 1000, 1803 mm
//   pt 1: ( 500,  800) ->  943, 1281, 2625 mm
//   pt 2: (2000, 1500) -> 2500, 1581, 1803 mm
//   pt 3: (1000, 2000) -> 2236, 2062, 2828 mm
// latency_ticks is added so the result matches what the FSM subtracts for
// the real echo detector's hold time.
//////////////////////////////////////////////////////////////////////////////////

module fake_echo_gen (
    input  wire        clk,
    input  wire        rst,
    input  wire        tx_start,
    input  wire [1:0]  demo_pt,
    input  wire [21:0] latency_ticks,
    output reg  [2:0]  echo_valid
);
    reg [21:0] t0, t1, t2;
    always @* begin
        case (demo_pt)
            2'd0: begin t0 = 22'd1051181; t1 = 22'd583090;  t2 = 22'd1051181; end
            2'd1: begin t0 = 22'd550086;  t1 = 22'd746720;  t2 = 22'd1530543; end
            2'd2: begin t0 = 22'd1457726; t1 = 22'd921947;  t2 = 22'd1051181; end
            default: begin t0 = 22'd1303830; t1 = 22'd1202072; t2 = 22'd1649229; end
        endcase
    end

    reg [21:0] cnt, e0, e1, e2;
    reg        run;
    reg [2:0]  fired;
    always @(posedge clk) begin
        echo_valid <= 3'b000;
        if (rst) begin run <= 0; cnt <= 0; fired <= 0; e0 <= 0; e1 <= 0; e2 <= 0; end
        else if (tx_start) begin
            run <= 1; cnt <= 22'd1; fired <= 0;
            e0 <= t0 + latency_ticks; e1 <= t1 + latency_ticks; e2 <= t2 + latency_ticks;
        end else if (run) begin
            cnt <= cnt + 1'b1;
            if (!fired[0] && cnt >= e0) begin echo_valid[0] <= 1; fired[0] <= 1; end
            if (!fired[1] && cnt >= e1) begin echo_valid[1] <= 1; fired[1] <= 1; end
            if (!fired[2] && cnt >= e2) begin echo_valid[2] <= 1; fired[2] <= 1; end
            if (fired == 3'b111) run <= 0;
        end
    end
endmodule
