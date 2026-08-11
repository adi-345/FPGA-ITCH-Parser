`timescale 1ns / 1ps
import itch_pkg::*;

module trade_math_core (
    input  logic              aclk,
    input  logic              aresetn,

    // Input Stream from Filter Matrix
    input  normalized_msg_t   s_axis_tdata,
    input  logic              s_axis_tvalid,

    // Metrics Output Monitor Interface
    output logic [63:0]       aapl_total_shares,
    output logic [63:0]       aapl_total_pv,
    output logic [63:0]       tsla_total_shares,
    output logic [63:0]       tsla_total_pv
);

    // Target constants
    localparam logic [63:0] SYM_AAPL = 64'h41_41_50_4C_20_20_20_20;
    localparam logic [63:0] SYM_TSLA = 64'h54_53_4C_41_20_20_20_20;

    // Pipelining Registers
    logic [63:0] pv_product;
    logic        pv_valid;
    logic [63:0] active_symbol;
    logic [31:0] active_shares;

    // Combinational multiplier
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            pv_product    <= '0;
            pv_valid      <= 1'b0;
            active_symbol <= '0;
            active_shares <= '0;
        end else begin
            pv_valid      <= s_axis_tvalid;
            active_symbol <= s_axis_tdata.symbol;
            active_shares <= s_axis_tdata.shares;

            pv_product    <= 64'(s_axis_tdata.price) * 64'(s_axis_tdata.shares);
        end
    end

    // Independent asset tracker
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            aapl_total_shares <= '0;
            aapl_total_pv     <= '0;
            tsla_total_shares <= '0;
            tsla_total_pv     <= '0;
        end else if (pv_valid) begin
            case (active_symbol)
                SYM_AAPL: begin
                    aapl_total_shares <= aapl_total_shares + active_shares;
                    aapl_total_pv     <= aapl_total_pv + pv_product;
                end
                SYM_TSLA: begin
                    tsla_total_shares <= tsla_total_shares + active_shares;
                    tsla_total_pv     <= tsla_total_pv + pv_product;
                end
                default: ; // Do nothing if it's an untracked edge asset
            endcase
        end
    end

endmodule
