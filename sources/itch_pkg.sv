`timescale 1ns / 1ps

package itch_pkg;

    typedef struct packed {
        logic [7:0]  message_type;
        logic [63:0] ref_number;
        logic [7:0]  buy_sell;
        logic [31:0] shares;
        logic [63:0] symbol;
        logic [31:0] price;
    } normalized_msg_t;

endpackage
