`timescale 1ns / 1ps
import itch_pkg::*;

module trade_filter (
    input  logic              aclk,
    input  logic              aresetn,

    // Upstream Interface
    input  normalized_msg_t   s_axis_tdata,
    input  logic              s_axis_tvalid,

    // Downstream Interface
    output normalized_msg_t   filtered_tdata,
    output logic              filtered_tvalid
);

    localparam logic [63:0] SYM_AAPL = 64'h41_41_50_4C_20_20_20_20;
    localparam logic [63:0] SYM_TSLA = 64'h54_53_4C_41_20_20_20_20;

    logic symbol_hit;

    always_comb begin
        if ((s_axis_tdata.message_type == 8'h41) &&
            ((s_axis_tdata.symbol == SYM_AAPL) || (s_axis_tdata.symbol == SYM_TSLA))) begin
            symbol_hit = 1'b1;
        end else begin
            symbol_hit = 1'b0;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            filtered_tdata  <= '0;
            filtered_tvalid <= 1'b0;
        end else begin
            if (s_axis_tvalid && symbol_hit) begin
                filtered_tdata  <= s_axis_tdata;
                filtered_tvalid <= 1'b1;
            end else begin
                filtered_tvalid <= 1'b0;
            end
        end
    end

endmodule
