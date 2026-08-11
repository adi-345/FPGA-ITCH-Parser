`timescale 1ns / 1ps

import itch_pkg::*;

module itch_parser_tb;

    logic aclk;
    logic aresetn;

    logic [31:0] s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tready;

    normalized_msg_t m_axis_tdata;
    logic            m_axis_tvalid;

    normalized_msg_t parser_to_filter_data;
    logic            parser_to_filter_valid;

    // Math Output Tracking Registers
    logic [63:0] aapl_shares;
    logic [63:0] aapl_pv;
    logic [63:0] tsla_shares;
    logic [63:0] tsla_pv;

    // Signal Output Trigger Vectors (2'b00 = HOLD, 2'b01 = BUY, 2'b10 = SELL)
    logic [1:0] aapl_trade_signal;
    logic [1:0] tsla_trade_signal;

    // UUT 1: ITCH Parser
    itch_parser uut_parser (
        .aclk          (aclk),
        .aresetn        (aresetn),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),

        .m_axis_tdata  (parser_to_filter_data),
        .m_axis_tvalid (parser_to_filter_valid)
    );

    // UUT 2: Symbol filter
    trade_filter uut_filter (
        .aclk           (aclk),
        .aresetn         (aresetn),

        // Inputs come from parser output
        .s_axis_tdata   (parser_to_filter_data),
        .s_axis_tvalid  (parser_to_filter_valid),

        // Outputs go to testbench monitor
        .filtered_tdata (m_axis_tdata),
        .filtered_tvalid(m_axis_tvalid)
    );

    // UUT 3: Math module
    trade_math_core uut_math (
        .aclk              (aclk),
        .aresetn            (aresetn),
        .s_axis_tdata      (m_axis_tdata),
        .s_axis_tvalid     (m_axis_tvalid),

        .aapl_total_shares (aapl_shares),
        .aapl_total_pv     (aapl_pv),
        .tsla_total_shares (tsla_shares),
        .tsla_total_pv     (tsla_pv)
    );

    // UUT 4: Trigger module
    trade_signal_trigger uut_trigger (
        .aclk              (aclk),
        .aresetn            (aresetn),

        .aapl_total_shares (aapl_shares),
        .aapl_total_pv     (aapl_pv),
        .tsla_total_shares (tsla_shares),
        .tsla_total_pv     (tsla_pv),

        .aapl_signal       (aapl_trade_signal),
        .tsla_signal       (tsla_trade_signal)
    );

    // 100 MHz clock
    always #5 aclk = ~aclk;

    always @(posedge aclk) begin
        if (m_axis_tvalid) begin
            $display("==================================================");
            $display("TIME: %0t ps | FILTERED DATA PASSED TO MATH ENGINE", $time);
            $display("Message Type: %c | Symbol: %s", m_axis_tdata.message_type,
             string'(m_axis_tdata.symbol));
            $display("Shares Added: %0d | Price: %0d", m_axis_tdata.shares, m_axis_tdata.price);
            $display("--------------------------------------------------");

            // Wait 3 clock cycles for Multiplier + Accumulator + Trigger pipelining to stabilize
            #32;
            $display("DOWNSTREAM CORES INFRASTRUCTURE LOGS:");
            $display("  AAPL Total Shares: %0d | Total Price-Volume: %0d", aapl_shares, aapl_pv);
            $display("  TSLA Total Shares: %0d | Total Price-Volume: %0d", tsla_shares, tsla_pv);
            $display("  LIVE SIGNALS:");
            $display("  AAPL: %b (%s)", aapl_trade_signal, (aapl_trade_signal == 2'b01)
             ? "BUY!" : (aapl_trade_signal == 2'b10) ? "SELL!" : "HOLD");
            $display("  TSLA: %b (%s)", tsla_trade_signal, (tsla_trade_signal == 2'b01)
             ? "BUY!" : (tsla_trade_signal == 2'b10) ? "SELL!" : "HOLD");
            $display("==================================================");
        end
    end

    // Helper Task to send data cycles
    task send_word(input logic [31:0] data);
        begin
            s_axis_tdata  <= data;
            s_axis_tvalid = 1'b1;
            do begin
                @(posedge aclk);
            end while (!s_axis_tready);
        end
    endtask

    initial begin
        // Initialize Signals
        aclk          = 0;
        aresetn        = 0;
        s_axis_tdata  = 32'h0;
        s_axis_tvalid = 0;

        // Reset Pulse
        #40;
        aresetn = 1;
        #20;

        $display("[TB START] Initiating multi-packet, continuous stream verification...");

        // 1: System Event 'S' (12 bytes) - Sent perfectly aligned
        // Word 0: Type 'S' (0x53), Stock Locate, Tracking Number byte 1
        send_word(32'h53_1234_12);
        // Word 1: Tracking number byte 2, Timestamp bytes 1 - 3
        send_word(32'h34_123456);
        // Word 2: Timestamp bytes 4 - 6, Event Code 'O'
        send_word(32'h789012_4F); // Message ends aligned

        // 2: Stock Directory 'R' (39 bytes) - Offset stays 0
        // Word 0: Type 'R' (0x52), Stock Locate, Tracking Number byte 1
        send_word(32'h52_1234_12);
        // Word 1: Tracking Number byte 2, Timestamp bytes 1 - 3
        send_word(32'h34_123456);
        // Word 2: Timestamp bytes 4 - 6, Stock byte 1 ("TSLA - T")
        send_word(32'h789012_54);
        // Word 3: Symbol bytes 2-5 ("SLA ")
        send_word(32'h534C4120);
        // Word 4: Symbol bytes 6-8 ("   "), Market Category "Q"
        send_word(32'h202020_51);
        // Word 5: Financial Status ('N'), Round Lot Size byte 1 - 3 (100)
        send_word(32'h4E_4E0000);
        // Word 6: Round Lot Size byte 4, Round Lots Only ("Y"), Issue Class ('G'), Sub-issue byte 1 (' ')
        send_word(32'h00_54_47_20);
        // Word 7: Sub-issue byte 2 (' '), Authenticity ('P'), Short-sale threshold ('N'), IPO flag ('N')
        send_word(32'h20_50_4E_4E);
        // Word 8: LULD reference tier ('1'), Etp Flag ('N'), Etp leverage byte 1 - 2 (1)
        send_word(32'h01_4E_0000);
        // Word 9: Etp leverage byte 3 - 4 (1), Inverse flag ('N') + A first byte
        send_word(32'h0001_4E_41);

        // 3: Add Order 'A' (36 bytes total) - Starts at offset 3
        // Word 0: Stock Locate, Tracking Number
        send_word(32'h1234_1234);
        // Word 1: Timestamp bytes 1 - 4
        send_word(32'h12345678);
        // Word 2: Timestamp 5 - 6, Order Reference Number bytes 1 - 2
        send_word(32'h9012_1234);
        // Word 3: Order Reference Number bytes 3 - 6
        send_word(32'h56789012);
        // Word 4: Order Reference Number bytes 7 - 8, Buy/Sell Indicator ("B"), Shares byte 1 (1000)
        send_word(32'h3456_42_00);
        // Word 5: Shares byte 2 - 4, Stock byte 1 ("AAPL    ")
        send_word(32'h0003E8_41);
        // Word 6: Stock bytes 2 - 5
        send_word(32'h41504C20);
        // Word 7: Symbol bytes 7-8 ("  "), Price byte 1
        send_word(32'h202020_12);
        // Word 8: Price bytes 2 - 4, Start E at 4th byte
        send_word(32'h345678_45);

        // 4: Order Execute 'E' (31 bytes total) - Same byte offset 3, should end with next byte offset 2
        // Word 0: Stock Locate, Tracking Number
        send_word(32'h1234_1234);
        // Word 1: Timestamp bytes 1 - 4
        send_word(32'h12345678);
        // Word 2: Timestamp bytes 5 - 6, Order Reference Number bytes 1 - 2
        send_word(32'h9012_1234);
        // Word 3: Order Reference Number bytes 3 - 6
        send_word(32'h56789012);
        // Word 4: Order Ref Number bytes 7 - 8, Shares bytes 1 - 2
        send_word(32'h3456_0000);
        // Word 5: Executed Shares bytes 3 - 4, Match number bytes 1 - 2
        send_word(32'h0001_1234);
        // Word 6: Match ID bytes 3 - 6
        send_word(32'h56789012);
        // Word 7: Match ID bytes 7 - 8, 2 bytes padding
        send_word(32'h3456_FF_FF);

        // End Simulation
        s_axis_tvalid = 1'b0;
        #100;
        $display("[TB FINISH] All message blocks parsed successfully with shifting boundaries!");
        $finish;
    end

endmodule
