`timescale 1ns / 1ps
import itch_pkg::*;

module trade_engine (
    input  logic        aclk,
    input  logic        aresetn,

    // Hardened Upstream AXI4-Stream Slave Interface
    input  logic [31:0] s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    output logic        s_axis_tready,

    // Downstream Algorithmic Trade Signals (Aligned to 2-bit vectors)
    output logic [1:0]  aapl_signal,
    output logic [1:0]  tsla_signal
);

    // Flush Logic

    logic global_flush_n;
    assign global_flush_n = aresetn && !(s_axis_tvalid && s_axis_tlast);

    // Internal wires

    normalized_msg_t parser_to_filter_data;
    logic            parser_to_filter_valid;

    normalized_msg_t filter_to_math_data;
    logic            filter_to_math_valid;

    logic [63:0] aapl_total_shares;
    logic [63:0] aapl_total_pv;
    logic [63:0] tsla_total_shares;
    logic [63:0] tsla_total_pv;

    // UUT 1: Core parser

    itch_parser uut_parser (
        .aclk           (aclk),
        .aresetn        (aresetn),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tready  (s_axis_tready),
        .m_axis_tdata   (parser_to_filter_data),
        .m_axis_tvalid  (parser_to_filter_valid)
    );

    // UUT 2: Symbol filter

    trade_filter uut_filter (
        .aclk           (aclk),
        .aresetn        (aresetn),
        .s_axis_tdata   (parser_to_filter_data),
        .s_axis_tvalid  (parser_to_filter_valid),
        .filtered_tdata (filter_to_math_data),
        .filtered_tvalid(filter_to_math_valid)
    );

    // UUT 3: Math module

    trade_math_core uut_math (
        .aclk               (aclk),
        .aresetn            (aresetn),
        .s_axis_tdata       (filter_to_math_data),
        .s_axis_tvalid      (filter_to_math_valid),
        .aapl_total_shares  (aapl_total_shares),
        .aapl_total_pv      (aapl_total_pv),
        .tsla_total_shares  (tsla_total_shares),
        .tsla_total_pv      (tsla_total_pv)
    );

    // UUT 4: Trigger module

    trade_signal_trigger uut_trigger (
        .aclk               (aclk),
        .aresetn            (aresetn),

        .trigger_strobe     (filter_to_math_valid),

        .aapl_total_shares  (aapl_total_shares),
        .aapl_total_pv      (aapl_total_pv),
        .tsla_total_shares  (tsla_total_shares),
        .tsla_total_pv      (tsla_total_pv),
        .aapl_signal        (aapl_signal),
        .tsla_signal        (tsla_signal)
    );

endmodule : trade_engine
