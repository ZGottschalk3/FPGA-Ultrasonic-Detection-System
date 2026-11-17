`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Texas Tech University Department of Electrical and Computer Engineering
// Jagrati Kumari (integration)
//
// Module Name: ultrasonic_top
// Project Name: Ultrasonic_Object_Tracking System
//
// Complete system in ONE bitstream. Every test is selected with switches,
// so the same build is used in the lab and on demo day.
//
//   btnU -> debounce -> 3x measurement_fsm (lockstep)
//        -> burst_generator -> frequency_generator -> JB1..JB3 -> PCB Tx
//   PCB Rx -> JXADC -> xadc_reader -> 3x echo_detect -> echo_valid per FSM
//   3 distances -> coordinate_unit (Zach's coordinate_computer + CORDIC angle) -> LCD
//
// SWITCHES
//   SW0..SW2   enable Tx channel 1..3
//   SW3..SW9   echo threshold = value x 4 (ADC codes)
//   SW10..SW11 demo target for fake echoes (0..3, see table below)
//   SW12..SW13 LCD page: 0 distances, 1 X/Y, 2 echo levels, 3 Tx check
//   SW14       echo source: 0 = real receivers, 1 = fake echoes (no PCB needed)
//   SW15       auto mode, 10 measurements per second
// BUTTONS
//   btnU measure once, btnC reset
// LEDS
//   LED0..2 got echo on channel 1..3, LED13 fake mode, LED14 auto mode,
//   LED15 toggles per measurement
//
// Fake-echo demo targets (sensors at x = 0, 1500, 3000 mm, y = 0)
//   0: (1500, 1000)   1: (500, 800)   2: (2000, 1500)   3: (1000, 2000)
//////////////////////////////////////////////////////////////////////////////////

module ultrasonic_top #(
    parameter integer FAST_SIM = 0
)(
    input  wire        clk,
    input  wire        btnC,
    input  wire        btnU,
    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [2:0]  tx_out,          // JB1..JB3 -> PCB Tx drivers
    output wire        tx_enable_out,   // JB4 scope trigger
    input  wire        vauxp6,  vauxn6, // JXADC 1/7  Rx1
    input  wire        vauxp14, vauxn14,// JXADC 2/8  Rx2
    input  wire        vauxp7,  vauxn7, // JXADC 3/9  Rx3
    output wire        lcd_rs,
    output wire        lcd_e,
    output wire [3:0]  lcd_d
);
    wire rst = btnC;

    localparam integer UPDATE_TICKS   = FAST_SIM ? 1_000 : 10_000_000;
    localparam integer DEBOUNCE_TICKS = FAST_SIM ? 1_000 : 1_000_000;
    localparam integer LCD_DIV        = FAST_SIM ? 100   : 1;

    // receive timing: ~333 kSPS per channel = one sample every 300 ticks
    localparam integer HOLD_SAMPLES   = 4;
    localparam integer ECHO_LATENCY   = (HOLD_SAMPLES - 1) * 300 + 2;

    // ---- switches -------------------------------------------------------------
    wire [2:0]  ch_en     = sw[2:0];
    wire [11:0] threshold = {3'b000, sw[9:3], 2'b00};
    wire [1:0]  demo_pt   = sw[11:10];
    wire [1:0]  page      = sw[13:12];
    wire        fake_mode = sw[14];
    wire        auto_mode = sw[15];

    // ---- 10 Hz tick -------------------------------------------------------------
    reg [23:0] upd_cnt; reg upd;
    always @(posedge clk) begin
        if (rst) begin upd_cnt <= 0; upd <= 1'b0; end
        else if (upd_cnt == UPDATE_TICKS - 1) begin upd_cnt <= 0; upd <= 1'b1; end
        else begin upd_cnt <= upd_cnt + 1'b1; upd <= 1'b0; end
    end

    // ---- trigger ------------------------------------------------------------------
    wire btn_pulse;
    debounce #(.DEBOUNCE_TICKS(DEBOUNCE_TICKS)) u_debounce (
        .clk(clk), .rst(rst), .btn_raw(btnU), .pulse_out(btn_pulse));

    wire [2:0] st0, st1, st2;
    wire       busy_coord;
    wire       all_idle = (st0 == 3'd0) && (st1 == 3'd0) && (st2 == 3'd0) && !busy_coord;
    wire       trigger  = (btn_pulse | (auto_mode & upd)) & all_idle;

    // ---- three measurement FSMs, started together ---------------------------------
    wire        tx_start0, tx_start1, tx_start2, tx_done;
    wire [2:0]  window_open, result_valid, timeout;
    wire [2:0]  echo_valid;
    wire [21:0] tof0, tof1, tof2;
    wire [12:0] dist0, dist1, dist2;

    measurement_fsm #(.ECHO_LATENCY_TICKS(ECHO_LATENCY)) u_fsm0 (
        .clk(clk), .rst(rst), .trigger(trigger), .tx_done(tx_done), .echo_valid(echo_valid[0]),
        .tx_start(tx_start0), .window_open(window_open[0]), .tof_ticks(tof0),
        .distance_mm(dist0), .result_valid(result_valid[0]), .timeout(timeout[0]), .state_out(st0));
    measurement_fsm #(.ECHO_LATENCY_TICKS(ECHO_LATENCY)) u_fsm1 (
        .clk(clk), .rst(rst), .trigger(trigger), .tx_done(tx_done), .echo_valid(echo_valid[1]),
        .tx_start(tx_start1), .window_open(window_open[1]), .tof_ticks(tof1),
        .distance_mm(dist1), .result_valid(result_valid[1]), .timeout(timeout[1]), .state_out(st1));
    measurement_fsm #(.ECHO_LATENCY_TICKS(ECHO_LATENCY)) u_fsm2 (
        .clk(clk), .rst(rst), .trigger(trigger), .tx_done(tx_done), .echo_valid(echo_valid[2]),
        .tx_start(tx_start2), .window_open(window_open[2]), .tof_ticks(tof2),
        .distance_mm(dist2), .result_valid(result_valid[2]), .timeout(timeout[2]), .state_out(st2));

    // ---- transmit (Zach) ------------------------------------------------------------
    wire burst_enable, tx_wave;
    burst_generator u_burst (
        .clk(clk), .reset(rst), .start(tx_start0), .enable(burst_enable), .done(tx_done));
    frequency_generator u_freq (
        .clk(clk), .reset(rst), .enable(burst_enable), .tx(tx_wave));
    assign tx_out        = {3{tx_wave}} & ch_en;
    assign tx_enable_out = burst_enable;

    // ---- receive: 3 channels from the XADC --------------------------------------------
    wire [11:0] sample;
    wire [1:0]  sample_ch;
    wire        sample_valid;
    xadc_reader u_adc (
        .clk(clk), .rst(rst),
        .vauxp6(vauxp6), .vauxn6(vauxn6), .vauxp14(vauxp14), .vauxn14(vauxn14),
        .vauxp7(vauxp7), .vauxn7(vauxn7),
        .sample(sample), .sample_ch(sample_ch), .sample_valid(sample_valid));

    wire [2:0]  real_echo;
    wire [11:0] env0, env1, env2, peak0, peak1, peak2;
    echo_detect #(.BASE_SHIFT(6), .ENV_SHIFT(3), .HOLD_SAMPLES(HOLD_SAMPLES),
                  .QUIET_SAMPLES(8), .POST_SAMPLES(100)) u_echo0 (
        .clk(clk), .rst(rst), .sample_valid(sample_valid && sample_ch == 2'd0), .sample(sample),
        .window_open(window_open[0]), .tx_start(tx_start0), .threshold(threshold),
        .echo_valid(real_echo[0]), .envelope(env0), .peak_env(peak0));
    echo_detect #(.BASE_SHIFT(6), .ENV_SHIFT(3), .HOLD_SAMPLES(HOLD_SAMPLES),
                  .QUIET_SAMPLES(8), .POST_SAMPLES(100)) u_echo1 (
        .clk(clk), .rst(rst), .sample_valid(sample_valid && sample_ch == 2'd1), .sample(sample),
        .window_open(window_open[1]), .tx_start(tx_start0), .threshold(threshold),
        .echo_valid(real_echo[1]), .envelope(env1), .peak_env(peak1));
    echo_detect #(.BASE_SHIFT(6), .ENV_SHIFT(3), .HOLD_SAMPLES(HOLD_SAMPLES),
                  .QUIET_SAMPLES(8), .POST_SAMPLES(100)) u_echo2 (
        .clk(clk), .rst(rst), .sample_valid(sample_valid && sample_ch == 2'd2), .sample(sample),
        .window_open(window_open[2]), .tx_start(tx_start0), .threshold(threshold),
        .echo_valid(real_echo[2]), .envelope(env2), .peak_env(peak2));

    // ---- fake echoes: known demo positions, no PCB needed --------------------------------
    wire [2:0] fake_echo;
    fake_echo_gen u_fake (
        .clk(clk), .rst(rst), .tx_start(tx_start0), .demo_pt(demo_pt),
        .echo_valid(fake_echo), .latency_ticks(ECHO_LATENCY[21:0]));

    assign echo_valid = fake_mode ? fake_echo : real_echo;

    // ---- collect the three distances, then compute X / Y --------------------------------
    reg  [2:0]  got, to;
    reg  [12:0] d0_q, d1_q, d2_q;
    reg         coord_start, counted, fix_ok, coord_pending, meas_led;
    reg  [13:0] meas_count;
    wire signed [15:0] x_mm;
    wire        [15:0] y_mm;
    wire signed [31:0] angle_q16;
    wire        angle_valid;
    wire        coord_valid;

    always @(posedge clk) begin
        coord_start <= 1'b0;
        if (rst) begin
            got <= 0; to <= 0; d0_q <= 0; d1_q <= 0; d2_q <= 0; counted <= 0;
            fix_ok <= 0; coord_pending <= 0; meas_count <= 0; meas_led <= 0;
        end else if (trigger) begin
            got <= 0; to <= 0; counted <= 0;
        end else begin
            if (result_valid[0]) begin got[0] <= 1; to[0] <= timeout[0]; d0_q <= dist0; end
            if (result_valid[1]) begin got[1] <= 1; to[1] <= timeout[1]; d1_q <= dist1; end
            if (result_valid[2]) begin got[2] <= 1; to[2] <= timeout[2]; d2_q <= dist2; end

            // all three channels finished: count it once, then compute if all saw an echo
            if (got == 3'b111 && !counted) begin
                counted    <= 1'b1;
                meas_count <= (meas_count == 14'd9999) ? 14'd0 : meas_count + 1'b1;
                meas_led   <= ~meas_led;
                if (to == 3'b000) begin coord_start <= 1'b1; coord_pending <= 1'b1; end
                else fix_ok <= 1'b0;
            end
            if (coord_valid) begin coord_pending <= 1'b0; fix_ok <= 1'b1; end
        end
    end
    assign busy_coord = coord_pending;

    coordinate_unit u_coord (
        .clk(clk), .rst(rst), .start(coord_start),
        .d1_mm(d0_q), .d2_mm(d1_q), .d3_mm(d2_q),
        .x_mm(x_mm), .y_mm(y_mm), .angle_q16(angle_q16), .angle_valid(angle_valid),
        .result_valid(coord_valid));

    // angle in tenths of a degree for the LCD (e.g. 33.7 deg -> 337)
    wire [31:0] ang_pos    = angle_q16[31] ? 32'd0 : angle_q16;
    wire [35:0] ang_x10    = ang_pos * 4'd10;
    wire [15:0] ang_tenths = ang_x10[31:16];

    // ---- Tx self-check: count 40 kHz cycles per burst -------------------------------------
    reg wave_q; reg [7:0] cyc_run, cyc_last;
    always @(posedge clk) begin
        if (rst) begin wave_q <= 0; cyc_run <= 0; cyc_last <= 0; end
        else begin
            wave_q <= tx_wave;
            if (tx_start0) cyc_run <= 0;
            else if (tx_wave && !wave_q) cyc_run <= cyc_run + 1'b1;
            if (tx_done) cyc_last <= cyc_run;
        end
    end

    // ---- LCD ---------------------------------------------------------------------------------
    function [13:0] cap; input [15:0] v; cap = (v > 16'd9999) ? 14'd9999 : v[13:0]; endfunction
    function [7:0]  dch; input [3:0] g;  dch = 8'h30 + {4'h0, g}; endfunction
    function [31:0] d4;  input [15:0] b; d4 = {dch(b[15:12]), dch(b[11:8]), dch(b[7:4]), dch(b[3:0])}; endfunction

    wire [15:0] x_abs = x_mm[15] ? -x_mm : x_mm;
    wire [15:0] b_d0, b_d1, b_d2, b_x, b_y, b_p0, b_p1, b_p2, b_th, b_n, b_cy;
    bin2bcd c0 (.clk(clk), .rst(rst), .start(upd), .bin(cap({3'd0, d0_q})),  .bcd(b_d0));
    bin2bcd c1 (.clk(clk), .rst(rst), .start(upd), .bin(cap({3'd0, d1_q})),  .bcd(b_d1));
    bin2bcd c2 (.clk(clk), .rst(rst), .start(upd), .bin(cap({3'd0, d2_q})),  .bcd(b_d2));
    bin2bcd c3 (.clk(clk), .rst(rst), .start(upd), .bin(cap(x_abs)),         .bcd(b_x));
    bin2bcd c4 (.clk(clk), .rst(rst), .start(upd), .bin(cap(y_mm)),          .bcd(b_y));
    bin2bcd c5 (.clk(clk), .rst(rst), .start(upd), .bin(cap({4'd0, peak0})), .bcd(b_p0));
    bin2bcd c6 (.clk(clk), .rst(rst), .start(upd), .bin(cap({4'd0, peak1})), .bcd(b_p1));
    bin2bcd c7 (.clk(clk), .rst(rst), .start(upd), .bin(cap({4'd0, peak2})), .bcd(b_p2));
    bin2bcd c8 (.clk(clk), .rst(rst), .start(upd), .bin(cap({4'd0, threshold})), .bcd(b_th));
    bin2bcd c9 (.clk(clk), .rst(rst), .start(upd), .bin(meas_count),        .bcd(b_n));
    bin2bcd ca (.clk(clk), .rst(rst), .start(upd), .bin({6'd0, cyc_last}),   .bcd(b_cy));
    wire [15:0] b_ang;
    bin2bcd cb (.clk(clk), .rst(rst), .start(upd), .bin(cap(ang_tenths)),    .bcd(b_ang));

    // freeze flags with the digits so text and numbers always match
    reg [2:0] to_q, en_q; reg fix_q, none_q, xneg_q, ang_ok_q;
    always @(posedge clk) begin
        if (rst) begin to_q <= 0; en_q <= 0; fix_q <= 0; none_q <= 1; xneg_q <= 0; ang_ok_q <= 0; end
        else if (upd) begin
            to_q <= to; en_q <= ch_en; fix_q <= fix_ok; none_q <= (meas_count == 0); xneg_q <= x_mm[15];
            ang_ok_q <= angle_valid;
        end
    end

    wire [31:0] t0 = to_q[0] ? "----" : d4(b_d0);
    wire [31:0] t1 = to_q[1] ? "----" : d4(b_d1);
    wire [31:0] t2 = to_q[2] ? "----" : d4(b_d2);
    wire [39:0] cnt_txt = {"#", d4(b_n)};

    reg [127:0] line1, line2;
    always @* begin
        case (page)
            2'd0: begin                                   // distances
                line1 = {"D1:", t0, " D2:", t1, " "};
                line2 = {"D3:", t2, "    ", cnt_txt};
            end
            2'd1: begin                                   // position
                line1 = fix_q ? {"X:", xneg_q ? "-" : "+", d4(b_x), " Y:", d4(b_y), "  "}
                              : "X:----- Y:----  ";
                line2 = !fix_q    ? {"No fix     ", cnt_txt} :
                        !ang_ok_q ? {"Ang:--.-   ", cnt_txt} :
                                    {"Ang:", dch(b_ang[11:8]), dch(b_ang[7:4]), ".",
                                     dch(b_ang[3:0]), "   ", cnt_txt};
            end
            2'd2: begin                                   // echo levels for tuning
                line1 = {"P1:", d4(b_p0), " P2:", d4(b_p1), " "};
                line2 = {"P3:", d4(b_p2), " Th:", d4(b_th), " "};
            end
            default: begin                                // transmit check
                line1 = {"TX ", en_q[0] ? "1" : "-", en_q[1] ? "2" : "-", en_q[2] ? "3" : "-",
                         "  ", cnt_txt, "   "};
                line2 = {"Cycles:", dch(b_cy[7:4]), dch(b_cy[3:0]),
                         (b_cy == 16'h0008) ? "  OK   " : "  BAD  "};
            end
        endcase
        if (none_q && page != 2'd2) line2 = "Press btnU      ";
    end

    lcd1602_driver #(.DIV(LCD_DIV)) u_lcd (
        .clk(clk), .rst(rst), .line1(line1), .line2(line2),
        .lcd_rs(lcd_rs), .lcd_e(lcd_e), .lcd_d(lcd_d));

    assign led = {meas_led, auto_mode, fake_mode, 10'd0, got & ~to};
endmodule
