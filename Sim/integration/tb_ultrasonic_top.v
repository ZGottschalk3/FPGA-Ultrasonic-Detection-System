`timescale 1ns / 1ps
//======================================================================
//  tb_ultrasonic_top.v  -  full-system test of the single bitstream
//  Compile with sim_xadc_reader.v INSTEAD of RTL/receive/xadc_reader.v.
//    1. transmit: 8 cycles of 40 kHz per burst on every enabled channel
//    2. fake-echo mode (SW14=1): all 4 demo targets -> distances and X/Y
//    3. real-receiver mode: simulated echoes on 3 ADC channels -> X/Y
//    4. one receiver silent -> "No fix"
//    5. LCD text on the distance and position pages
//======================================================================
module tb_ultrasonic_top;
    reg clk = 0, btnC = 1, btnU = 0;
    reg [15:0] sw = 0;
    wire [15:0] led; wire [2:0] tx; wire txen; wire rs, e; wire [3:0] d;

    ultrasonic_top #(.FAST_SIM(1)) dut (
        .clk(clk), .btnC(btnC), .btnU(btnU), .sw(sw), .led(led),
        .tx_out(tx), .tx_enable_out(txen),
        .vauxp6(1'b0), .vauxn6(1'b0), .vauxp14(1'b0), .vauxn14(1'b0), .vauxp7(1'b0), .vauxn7(1'b0),
        .lcd_rs(rs), .lcd_e(e), .lcd_d(d));
    always #5 clk = ~clk;

    integer now = 0, t0 = -100000000;
    always @(posedge clk) now <= now + 1;
    always @(posedge clk) if (dut.tx_start0) t0 = now;
    integer dly0 = 0, dly1 = 0, dly2 = 0; real amp0 = 0, amp1 = 0, amp2 = 0;

    integer edges [0:2], k;
    always @(posedge tx[0]) edges[0] = edges[0] + 1;
    always @(posedge tx[1]) edges[1] = edges[1] + 1;
    always @(posedge tx[2]) edges[2] = edges[2] + 1;

    // virtual LCD
    reg [7:0] mem [0:127]; reg [6:0] addr = 0; integer ec = 0; reg hv = 0; reg [3:0] hi; reg [7:0] b;
    reg [127:0] l1, l2;
    always @(negedge e) if (!btnC) begin
        ec = ec + 1;
        if (ec > 4) begin
            if (!hv) begin hi = d; hv = 1; end
            else begin b = {hi, d}; hv = 0;
                if (!rs) begin if (b[7]) addr = b[6:0]; end
                else begin mem[addr] = b; addr = addr + 1; end
            end
        end
    end
    task screen;
        begin
            repeat (300_000) @(posedge clk);
            l1 = 0; l2 = 0;
            for (k = 0;  k < 16; k = k + 1) l1 = {l1[119:0], mem[k]};
            for (k = 64; k < 80; k = k + 1) l2 = {l2[119:0], mem[k]};
            $display("     LCD |%s|", l1);
            $display("         |%s|", l2);
        end
    endtask

    integer fails = 0, ex, ey, n0;
    task measure;
        begin
            for (k = 0; k < 3; k = k + 1) edges[k] = 0;
            n0 = dut.meas_count;
            btnU = 1; repeat (150) @(posedge clk); btnU = 0; repeat (90) @(posedge clk);
            btnU = 1; repeat (3000) @(posedge clk); btnU = 0;
            wait (dut.meas_count != n0);
            repeat (400) @(posedge clk);
        end
    endtask
    task check_xy; input integer wx, wy, tol; input [8*30-1:0] label;
        begin
            ex = dut.x_mm - wx; ey = dut.y_mm - wy;
            $write(" %-30s D=%4d %4d %4d  X=%5d Y=%4d", label, dut.d0_q, dut.d1_q, dut.d2_q, dut.x_mm, dut.y_mm);
            if (dut.fix_ok && ex >= -tol && ex <= tol && ey >= -tol && ey <= tol) $display("  PASS");
            else begin $display("  FAIL (want %0d,%0d)", wx, wy); fails = fails + 1; end
        end
    endtask

    initial begin
        for (k = 0; k < 128; k = k + 1) mem[k] = " ";
        $display("==========================================================================");
        $display(" ultrasonic_top full system (one bitstream)");
        $display("==========================================================================");
        repeat (10) @(posedge clk); btnC = 0; repeat (50) @(posedge clk);

        // 1. transmit check (also uses fake mode so the measurement completes)
        sw = 16'b0100_0000_0000_0111;            // fake mode, all Tx on
        sw[9:3] = 7'd15;                         // threshold 60
        measure;
        $display(" Tx: ch1 %0d, ch2 %0d, ch3 %0d rising edges, counter %0d",
                 edges[0], edges[1], edges[2], dut.cyc_last);
        if (edges[0] != 8 || edges[1] != 8 || edges[2] != 8 || dut.cyc_last != 8) fails = fails + 1;

        // 2. fake-echo demo targets
        $display(" -- fake echoes (SW14 = 1) --");
        sw[11:10] = 0; measure; check_xy(1500, 1000, 5, "demo target 0 (1500,1000)");
        sw[11:10] = 1; measure; check_xy( 500,  800, 5, "demo target 1 (500,800)");
        sw[11:10] = 2; measure; check_xy(2000, 1500, 5, "demo target 2 (2000,1500)");
        sw[11:10] = 3; measure; check_xy(1000, 2000, 5, "demo target 3 (1000,2000)");
        sw[13:12] = 0; screen;
        if (l1 !== "D1:2236 D2:2062 ") fails = fails + 1;
        sw[13:12] = 1; screen;
        if (l1[127:48] !== "X:+1000 Y:" || l2[127:80] !== "Fix OK") fails = fails + 1;

        // 3. real receivers (simulated analog echoes)
        $display(" -- real receiver path (SW14 = 0), simulated echoes --");
        sw[14] = 0;
        dly0 = 550086;  dly1 = 746720; dly2 = 1530543; amp0 = 400; amp1 = 350; amp2 = 250;
        measure; check_xy(500, 800, 40, "target (500,800)");
        dly0 = 1051181; dly1 = 583090; dly2 = 1051181; amp0 = 300; amp1 = 400; amp2 = 300;
        measure; check_xy(1500, 1000, 40, "target (1500,1000)");

        // 4. one receiver hears nothing
        amp2 = 0; measure;
        $write(" %-30s to=%b fix=%b", "receiver 3 silent", dut.to, dut.fix_ok);
        if (dut.to == 3'b100 && !dut.fix_ok) $display("  PASS"); else begin $display("  FAIL"); fails = fails + 1; end
        sw[13:12] = 1; screen;
        if (l2[127:80] !== "No fix" || l1 !== "X:----- Y:----  ") fails = fails + 1;

        $display("--------------------------------------------------------------------------");
        if (fails == 0) $display(" RESULT: PASS"); else $display(" RESULT: FAIL (%0d)", fails);
        $finish;
    end
endmodule
