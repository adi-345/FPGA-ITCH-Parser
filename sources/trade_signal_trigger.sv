`timescale 1ns / 1ps

module trade_signal_trigger (
    input  logic        aclk,
    input  logic        aresetn,

    input  logic        trigger_strobe,

    // Ingest metrics from math core
    input  logic [63:0] aapl_total_shares,
    input  logic [63:0] aapl_total_pv,
    input  logic [63:0] tsla_total_shares,
    input  logic [63:0] tsla_total_pv,

    // Output flags
    output logic [1:0]  aapl_signal,
    output logic [1:0]  tsla_signal
);

    // Thresholds
    localparam logic [63:0] AAPL_BUY_THRESH = 64'd3000000;
    localparam logic [63:0] TSLA_BUY_THRESH = 64'd1800000;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            aapl_signal <= 2'b00;
            tsla_signal <= 2'b00;
        end else begin
            // Default assignments
            aapl_signal <= 2'b00;
            tsla_signal <= 2'b00;

            if (trigger_strobe) begin
                if (aapl_total_shares > 0 && (aapl_total_pv >
                 (AAPL_BUY_THRESH * aapl_total_shares))) begin
                    aapl_signal <= 2'b01;
                end

                if (tsla_total_shares > 0 && (tsla_total_pv >
                 (TSLA_BUY_THRESH * tsla_total_shares))) begin
                    tsla_signal <= 2'b01;
                end
            end
        end
    end

endmodule
