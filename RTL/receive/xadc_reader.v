`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Texas Tech University Department of Electrical and Computer Engineering
// Jagrati Kumari
//
// Module Name: xadc_reader   (HARDWARE - needs the XADC Wizard IP "xadc_wiz_0")
//
// Reads the three receiver channels on the JXADC header with the XADC
// sequencer (~1 MSPS total, so each channel ~333 kSPS = one sample / 3 us).
//
//   Rx channel 1 = VAUX6   JXADC pin 1 (+) / pin 7  (-)
//   Rx channel 2 = VAUX14  JXADC pin 2 (+) / pin 8  (-)
//   Rx channel 3 = VAUX7   JXADC pin 3 (+) / pin 9  (-)
//
// Output: one 12-bit sample per conversion, tagged with its channel (0..2),
// plus a one-cycle sample_valid strobe.
//
// XADC Wizard settings (IP Catalog -> XADC Wizard, component name xadc_wiz_0):
//   Basic       : Interface DRP, Timing Mode Continuous,
//                 Startup Channel Selection = Channel Sequencer,
//                 DCLK 100 MHz, ADC Conversion Rate 1000 KSPS
//   ADC Setup   : Sequencer Mode Continuous, all averaging off
//   Alarms      : uncheck everything
//   Channel Sequencer: enable VAUXP6/VAUXN6, VAUXP7/VAUXN7, VAUXP14/VAUXN14
//                 (unipolar), nothing else
//////////////////////////////////////////////////////////////////////////////////

module xadc_reader (
    input  wire        clk,
    input  wire        rst,
    input  wire        vauxp6,  vauxn6,
    input  wire        vauxp14, vauxn14,
    input  wire        vauxp7,  vauxn7,
    output reg  [11:0] sample,
    output reg  [1:0]  sample_ch,      // 0 = Rx1, 1 = Rx2, 2 = Rx3
    output reg         sample_valid
);
    wire        eoc, drdy;
    wire [15:0] do_out;
    wire [4:0]  channel;
    reg  [4:0]  ch_q;

    xadc_wiz_0 u_xadc (
        .daddr_in   ({2'b00, channel}),   // read the register of the channel just converted
        .dclk_in    (clk),
        .den_in     (eoc),
        .di_in      (16'h0000),
        .dwe_in     (1'b0),
        .reset_in   (rst),
        .vauxp6     (vauxp6),  .vauxn6  (vauxn6),
        .vauxp7     (vauxp7),  .vauxn7  (vauxn7),
        .vauxp14    (vauxp14), .vauxn14 (vauxn14),
        .busy_out   (),
        .channel_out(channel),
        .do_out     (do_out),
        .drdy_out   (drdy),
        .eoc_out    (eoc),
        .eos_out    (),
        .alarm_out  (),
        .vp_in      (1'b0),
        .vn_in      (1'b0)
    );

    always @(posedge clk) begin
        sample_valid <= 1'b0;
        if (rst) begin
            sample <= 0; sample_ch <= 0; ch_q <= 0;
        end else begin
            if (eoc) ch_q <= channel;              // remember which channel is being read
            if (drdy) begin
                sample <= do_out[15:4];            // 12-bit result is left-justified
                case (ch_q)
                    5'h16:   begin sample_ch <= 2'd0; sample_valid <= 1'b1; end  // VAUX6
                    5'h1E:   begin sample_ch <= 2'd1; sample_valid <= 1'b1; end  // VAUX14
                    5'h17:   begin sample_ch <= 2'd2; sample_valid <= 1'b1; end  // VAUX7
                    default: ;                                                  // ignore others
                endcase
            end
        end
    end
endmodule
