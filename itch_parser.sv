`timescale 1ns / 1ps

typedef struct packed {
    logic [7:0]  message_type;
    logic [63:0] ref_number;
    logic [7:0]  buy_sell;
    logic [31:0] shares;
    logic [63:0] symbol;
    logic [31:0] price;
} normalized_msg_t; 

module itch_parser (
    input  logic              aclk,
    input  logic              aresetn,
    
    // AXI4-Stream Slave Interface
    input  logic [31:0]       s_axis_tdata,
    input  logic              s_axis_tvalid,
    output logic              s_axis_tready,
    
    // AXI4-Stream Master Interface
    output normalized_msg_t   m_axis_tdata,
    output logic              m_axis_tvalid    
);

    // 1. Sliding Window Aligner Registers
    logic [31:0] prev_tdata;
    logic [31:0] aligned_data;
    logic [1:0]  byte_offset; 
    
    // Field Storage Registers
    logic [63:0] ref_number_reg;
    logic [7:0]  buy_sell_reg;
    logic [31:0] shares_reg;
    logic [63:0] symbol_reg;
    logic [31:0] price_reg;
    logic [7:0]  msg_type_reg;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            prev_tdata <= 32'd0;
        end else if (s_axis_tvalid && s_axis_tready) begin
            prev_tdata <= s_axis_tdata;
        end
    end
    
    // Barrel Shifter
    always_comb begin
        case (byte_offset)
            2'd0: aligned_data = s_axis_tdata;
            2'd1: aligned_data = {prev_tdata[23:0], s_axis_tdata[31:24]};
            2'd2: aligned_data = {prev_tdata[15:0], s_axis_tdata[31:16]};
            2'd3: aligned_data = {prev_tdata[7:0],  s_axis_tdata[31:8]};
            default: aligned_data = s_axis_tdata;
        endcase
    end

    // 2. Parser State Machine
    typedef enum logic [2:0] {
        WAIT_MSG,
        PARSE_S,
        PARSE_R,
        PARSE_A,
        PARSE_E
    } state_t;
    
    state_t state_reg, state_next;
    logic [3:0] word_count, count_next;
    logic [1:0] byte_offset_next;
    
    localparam [5:0] LEN_S = 6'd12;
    localparam [5:0] LEN_R = 6'd39;
    localparam [5:0] LEN_A = 6'd36;
    localparam [5:0] LEN_E = 6'd31;

    assign s_axis_tready = 1'b1;

    // Sequential Extraction and Storage
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_reg      <= WAIT_MSG;
            word_count     <= 4'd0;
            byte_offset    <= 2'd0;
            m_axis_tvalid  <= 1'b0;
            m_axis_tdata   <= '0;
            ref_number_reg <= '0;
            buy_sell_reg   <= '0;
            shares_reg     <= '0;
            symbol_reg     <= '0;
            price_reg      <= '0;
            msg_type_reg   <= '0;
        end else begin
            m_axis_tvalid <= 1'b0;
            
            if (s_axis_tvalid && s_axis_tready) begin
                state_reg   <= state_next;
                word_count  <= count_next;
                byte_offset <= byte_offset_next;
                
                case (state_reg)
                    WAIT_MSG: begin
                        msg_type_reg <= aligned_data[31:24];
                    end

                    PARSE_S: begin
                        if (word_count == 4'd2) begin
                            m_axis_tdata              <= '0;
                            m_axis_tdata.message_type <= 8'h53; // 'S'
                            m_axis_tvalid             <= 1'b1;
                        end
                    end
                    
                    PARSE_R: begin
                        case (word_count)                                   
                            4'd2: symbol_reg[63:56] <= aligned_data[7:0];   // Byte 11
                            4'd3: symbol_reg[55:24] <= aligned_data[31:0];  // Bytes 12-15
                            4'd4: symbol_reg[23:0]  <= aligned_data[31:8];  // Bytes 16-18
                            4'd9: begin
                                m_axis_tdata              <= '0;
                                m_axis_tdata.message_type <= 8'h52; // 'R'
                                m_axis_tdata.symbol       <= symbol_reg;
                                m_axis_tvalid             <= 1'b1;
                            end
                        endcase
                    end

                    PARSE_A: begin
                        case (word_count)
                            4'd2: ref_number_reg[63:56] <= aligned_data[7:0];   // Byte 11
                            4'd3: ref_number_reg[55:24] <= aligned_data[31:0];  // Bytes 12-15
                            4'd4: begin
                                  ref_number_reg[23:0]  <= aligned_data[31:8];  // Bytes 16-18
                                  buy_sell_reg          <= aligned_data[7:0];   // Byte 19
                            end
                            4'd5: shares_reg            <= aligned_data[31:0];  // Bytes 20-23
                            4'd6: symbol_reg[63:32]     <= aligned_data[31:0];  // Bytes 24-27
                            4'd7: symbol_reg[31:0]      <= aligned_data[31:0];  // Bytes 28-31
                            4'd8: begin
                                m_axis_tdata              <= '0;
                                m_axis_tdata.message_type <= 8'h41; // 'A'
                                m_axis_tdata.ref_number   <= ref_number_reg;
                                m_axis_tdata.buy_sell     <= buy_sell_reg;
                                m_axis_tdata.shares       <= shares_reg;
                                m_axis_tdata.symbol       <= symbol_reg;
                                m_axis_tdata.price        <= aligned_data;      // Bytes 32-35
                                m_axis_tvalid             <= 1'b1;
                            end
                        endcase
                    end
                    
                    PARSE_E: begin
                        case (word_count)                                   
                            4'd2: ref_number_reg[63:56] <= aligned_data[7:0];   // Byte 11
                            4'd3: ref_number_reg[55:24] <= aligned_data[31:0];  // Bytes 12-15
                            4'd4: begin
                                  ref_number_reg[23:0]  <= aligned_data[31:8];  // Bytes 16-18
                                  shares_reg[31:24]     <= aligned_data[7:0];   // Byte 19
                            end 
                            4'd5: shares_reg[23:0]      <= aligned_data[31:8];  // Bytes 20-22
                            4'd7: begin
                                m_axis_tdata              <= '0;
                                m_axis_tdata.message_type <= 8'h45; // 'E'
                                m_axis_tdata.ref_number   <= ref_number_reg;
                                m_axis_tdata.shares       <= shares_reg;
                                m_axis_tvalid             <= 1'b1;
                            end
                        endcase
                    end
                endcase         
            end
        end
    end

    // Combinational Routing and Definitive Next Offset Tracking
    always_comb begin
        logic [1:0] next_offset_calc;
        logic [7:0] lookahead_type;
        logic       lookahead_valid;

        state_next       = state_reg;
        count_next       = word_count;
        byte_offset_next = byte_offset;
        
        // Compute what the next offset will be when the current packet ends
        next_offset_calc = byte_offset;
        if (state_reg == PARSE_S && word_count == 4'd2) next_offset_calc = 2'((byte_offset + LEN_S) % 4);
        if (state_reg == PARSE_R && word_count == 4'd9) next_offset_calc = 2'((byte_offset + LEN_R) % 4);
        if (state_reg == PARSE_A && word_count == 4'd8) next_offset_calc = 2'((byte_offset + LEN_A) % 4);
        if (state_reg == PARSE_E && word_count == 4'd7) next_offset_calc = 2'((byte_offset + LEN_E) % 4);

        // Identify lookahead lane in current s_axis_tdata
        lookahead_valid = 1'b1;
        case (next_offset_calc)
            2'd1: lookahead_type = s_axis_tdata[23:16];
            2'd2: lookahead_type = s_axis_tdata[15:8];
            2'd3: lookahead_type = s_axis_tdata[7:0];
            2'd0: begin
                lookahead_type  = 8'd0;
                lookahead_valid = 1'b0;
            end
        endcase

        if (s_axis_tvalid && s_axis_tready) begin
            case (state_reg)
                WAIT_MSG: begin
                    count_next = 4'd1;
                    case (aligned_data[31:24])
                        8'h53: state_next = PARSE_S;
                        8'h52: state_next = PARSE_R;
                        8'h41: state_next = PARSE_A;
                        8'h45: state_next = PARSE_E;
                        default: begin state_next = WAIT_MSG; count_next = 4'd0; end
                    endcase
                end
                
                PARSE_S: begin
                    if (word_count == 4'd2) begin
                        byte_offset_next = next_offset_calc;
                        if (lookahead_valid) begin
                            count_next = 4'd0;
                            case (lookahead_type)
                                8'h53: state_next = PARSE_S;
                                8'h52: state_next = PARSE_R;
                                8'h41: state_next = PARSE_A;
                                8'h45: state_next = PARSE_E;
                                default: state_next = WAIT_MSG;
                            endcase
                        end else begin
                            state_next = WAIT_MSG; count_next = 4'd0;
                        end
                    end else count_next = word_count + 4'd1;
                end

                PARSE_R: begin
                    if (word_count == 4'd9) begin
                        byte_offset_next = next_offset_calc;
                        if (lookahead_valid) begin
                            count_next = 4'd0;
                            case (lookahead_type)
                                8'h53: state_next = PARSE_S;
                                8'h52: state_next = PARSE_R;
                                8'h41: state_next = PARSE_A;
                                8'h45: state_next = PARSE_E;
                                default: state_next = WAIT_MSG;
                            endcase
                        end else begin
                            state_next = WAIT_MSG; count_next = 4'd0;
                        end
                    end else count_next = word_count + 4'd1;
                end

                PARSE_A: begin
                    if (word_count == 4'd8) begin
                        byte_offset_next = next_offset_calc;
                        if (lookahead_valid) begin
                            count_next = 4'd0;
                            case (lookahead_type)
                                8'h53: state_next = PARSE_S;
                                8'h52: state_next = PARSE_R;
                                8'h41: state_next = PARSE_A;
                                8'h45: state_next = PARSE_E;
                                default: state_next = WAIT_MSG;
                            endcase
                        end else begin
                            state_next = WAIT_MSG; count_next = 4'd0;
                        end
                    end else count_next = word_count + 4'd1;
                end

                PARSE_E: begin
                    if (word_count == 4'd7) begin
                        byte_offset_next = next_offset_calc;
                        if (lookahead_valid) begin
                            count_next = 4'd0;
                            case (lookahead_type)
                                8'h53: state_next = PARSE_S;
                                8'h52: state_next = PARSE_R;
                                8'h41: state_next = PARSE_A;
                                8'h45: state_next = PARSE_E;
                                default: state_next = WAIT_MSG;
                            endcase
                        end else begin
                            state_next = WAIT_MSG; count_next = 4'd0;
                        end
                    end else count_next = word_count + 4'd1;
                end
            endcase
        end
    end

endmodule
