`timescale 1ns / 1ps
//======================================================================
//  lcd1602_driver.v
//  Drives a 16x2 character LCD (QAPASS 1602A / HD44780) in 4-bit mode.
//
//  You give it two lines of 16 ASCII characters; it initializes the
//  screen once, then redraws both lines every 50 ms forever.
//
//  Signals to the LCD:
//    lcd_rs : 0 = command, 1 = character
//    lcd_e  : "enable" pulse; LCD reads data on its falling edge
//    lcd_d  : LCD pins D4..D7 (4-bit mode, each byte sent as 2 halves)
//  LCD pin RW must be wired to GND (we only ever write to the LCD).
//
//  DIV speeds up all delays for simulation only (leave at 1 on hardware).
//======================================================================
module lcd1602_driver #(
    parameter integer DIV = 1
)(
    input  wire         clk,          // 100 MHz
    input  wire         rst,
    input  wire [127:0] line1,        // 16 chars, leftmost char in bits [127:120]
    input  wire [127:0] line2,
    output reg          lcd_rs,
    output reg          lcd_e,
    output reg  [3:0]   lcd_d
);
    // ---- delays in clock ticks (100 MHz -> 10 ns per tick) --------------
    localparam integer T_POWER   = 5_000_000 / DIV;   // 50 ms after power-up
    localparam integer T_5MS     =   500_000 / DIV;
    localparam integer T_200US   =    20_000 / DIV;
    localparam integer T_2MS     =   200_000 / DIV;   // clear-screen time
    localparam integer T_50US    =     5_000 / DIV;   // normal command/char time
    localparam integer T_REFRESH = 5_000_000 / DIV;   // 50 ms between redraws
    localparam integer T_1US     = (100 / DIV) < 1 ? 1 : (100 / DIV);

    // ---- step list ----------------------------------------------------
    //  0-3   : wake-up nibbles (put LCD into 4-bit mode)
    //  4-7   : settings: 2 lines, display on, cursor off, auto-advance, clear
    //  8     : go to line 1
    //  9-24  : 16 characters of line 1
    //  25    : go to line 2
    //  26-41 : 16 characters of line 2, then wait and jump back to step 8
    reg  [5:0]   step;
    reg  [127:0] l1, l2;          // copy of the text, frozen for each redraw

    reg          op_nib;          // 1 = send only the upper half (wake-up steps)
    reg          op_rs;
    reg  [7:0]   op_data;
    reg  [23:0]  op_delay;

    always @* begin
        op_nib   = 1'b0;
        op_rs    = 1'b0;
        op_data  = 8'h00;
        op_delay = T_50US;
        if (step == 6'd0)                      begin op_nib = 1'b1; op_data = 8'h30; op_delay = T_5MS;   end
        else if (step == 6'd1 || step == 6'd2) begin op_nib = 1'b1; op_data = 8'h30; op_delay = T_200US; end
        else if (step == 6'd3)                 begin op_nib = 1'b1; op_data = 8'h20; op_delay = T_200US; end
        else if (step == 6'd4)  op_data = 8'h28;   // 4-bit, 2 lines, 5x8 font
        else if (step == 6'd5)  op_data = 8'h0C;   // display on, cursor off
        else if (step == 6'd6)  op_data = 8'h06;   // move right after each char
        else if (step == 6'd7)  begin op_data = 8'h01; op_delay = T_2MS; end  // clear
        else if (step == 6'd8)  op_data = 8'h80;   // cursor to line 1, column 0
        else if (step <= 6'd24) begin op_rs = 1'b1; op_data = l1[127 - 8*(step - 9) -: 8]; end
        else if (step == 6'd25) op_data = 8'hC0;   // cursor to line 2, column 0
        else begin
            op_rs   = 1'b1;
            op_data = l2[127 - 8*(step - 26) -: 8];
            if (step == 6'd41) op_delay = T_REFRESH;
        end
    end

    // ---- executor: turns each step into E pulses with correct timing ------
    localparam [2:0] E_POWER = 3'd0, E_LOAD = 3'd1, E_SETUP = 3'd2,
                     E_HIGH  = 3'd3, E_HOLD = 3'd4, E_DELAY = 3'd5;

    reg [2:0]  st;
    reg [23:0] cnt;
    reg        second;            // 0 = sending upper half, 1 = lower half
    reg        cur_nib;
    reg [7:0]  cur_byte;
    reg [23:0] cur_delay;

    always @(posedge clk) begin
        if (rst) begin
            st     <= E_POWER;
            cnt    <= 24'd0;
            step   <= 6'd0;
            second <= 1'b0;
            lcd_rs <= 1'b0;
            lcd_e  <= 1'b0;
            lcd_d  <= 4'h0;
            l1     <= {16{8'h20}};
            l2     <= {16{8'h20}};
            cur_nib <= 1'b0; cur_byte <= 8'h00; cur_delay <= 24'd0;
        end else begin
            case (st)
            E_POWER: begin                        // let the LCD power up
                if (cnt == T_POWER - 1) begin cnt <= 0; st <= E_LOAD; end
                else cnt <= cnt + 1'b1;
            end
            E_LOAD: begin
                if (step == 6'd8) begin           // freeze text for this redraw
                    l1 <= line1;
                    l2 <= line2;
                end
                cur_nib   <= op_nib;
                cur_byte  <= op_data;
                cur_delay <= op_delay;
                lcd_rs    <= op_rs;
                lcd_d     <= op_data[7:4];        // upper half first
                lcd_e     <= 1'b0;
                second    <= 1'b0;
                cnt       <= 0;
                st        <= E_SETUP;
            end
            E_SETUP: begin                        // data settles before E rises
                if (cnt == T_1US - 1) begin cnt <= 0; lcd_e <= 1'b1; st <= E_HIGH; end
                else cnt <= cnt + 1'b1;
            end
            E_HIGH: begin                         // hold E high
                if (cnt == T_1US - 1) begin cnt <= 0; lcd_e <= 1'b0; st <= E_HOLD; end
                else cnt <= cnt + 1'b1;
            end
            E_HOLD: begin                         // LCD latched on the falling edge
                if (cnt == T_1US - 1) begin
                    cnt <= 0;
                    if (!cur_nib && !second) begin
                        second <= 1'b1;
                        lcd_d  <= cur_byte[3:0];  // now the lower half
                        st     <= E_SETUP;
                    end else st <= E_DELAY;
                end else cnt <= cnt + 1'b1;
            end
            E_DELAY: begin                        // give the LCD time to finish
                if (cnt == cur_delay - 1) begin
                    cnt  <= 0;
                    step <= (step == 6'd41) ? 6'd8 : step + 1'b1;
                    st   <= E_LOAD;
                end else cnt <= cnt + 1'b1;
            end
            default: st <= E_POWER;
            endcase
        end
    end
endmodule
