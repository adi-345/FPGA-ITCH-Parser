`timescale 1ns / 1ps
import itch_pkg::*;

module trading_engine_tb;

    logic aclk;
    logic aresetn;

    logic [31:0] s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tlast;
    logic        s_axis_tready;

    logic [1:0]  aapl_signal;
    logic [1:0]  tsla_signal;

    int error_count   = 0;
    int trigger_count = 0;

    trade_engine uut (
        .aclk           (aclk),
        .aresetn        (aresetn),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tready  (s_axis_tready),
        .aapl_signal    (aapl_signal),
        .tsla_signal    (tsla_signal)
    );

    // 200 MHz clock
    always #2.5 aclk = ~aclk;

    int file_ptr;
    int scan_status;

    logic [31:0] file_data;
    logic        file_valid;
    logic        file_last;

    initial begin
        aclk          = 1'b0;
        aresetn       = 1'b0;
        s_axis_tdata  = 32'd0;
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;

        repeat (4) @(posedge aclk);
        aresetn = 1'b1;
        $display("[TB START] Reset released");

        file_ptr = $fopen("C:/Users/Aditya/ITCH_Parser_Sim/itch_test_vectors.txt", "r");
        if (file_ptr == 0) begin
            $display("[ERROR] Vector file 'itch_test_vectors.txt' could not be opened");
            $finish;
        end

        while (!$feof(file_ptr)) begin
            @(posedge aclk);
            scan_status = $fscanf(file_ptr, "%h %b %b\n", file_data, file_valid, file_last);
            if (scan_status == 3) begin
                s_axis_tdata  <= file_data;
                s_axis_tvalid <= file_valid;
                s_axis_tlast  <= file_last;
            end
        end

        @(posedge aclk);
        s_axis_tdata  <= 32'd0;
        s_axis_tvalid <= 1'b0;
        s_axis_tlast  <= 1'b0;

        repeat (20) @(posedge aclk);

        $fclose(file_ptr);
        $display("[TB SUCCESS] End of vector stream reached.");
        $finish;
    end

    always @(posedge aclk) begin
        if (aresetn) begin
            // Monitor AAPL Signal
            if (aapl_signal == 2'b01) begin
                $display("[ALGO ERROR] TIME: %0t ps | AAPL BUY signal fired!",
                 $time);
                error_count++;
            end

            // Monitor TSLA Signal (Should fire BUY 2'b01 at exactly 508000 ps and 558000 ps)
            if (tsla_signal == 2'b01) begin
                trigger_count++;
                $display("[ALGO TRIGGER] TIME: %0t ps | TSLA Trading Target BUY Fired! [PULSE EDGE]"
                , $time);

                // Check integer nanoseconds (508 ns and 558 ns)
                if ($time != 508 && $time != 558) begin
                    $display("[ALGO ERROR] TIME: %0t ps | TSLA signal outside expected window!",
                     $time);
                    error_count++;
                end
            end
        end
    end

    // Final tally
    final begin
        $display("\n==================================================");
        $display("                      SUMMARY                       ");
        $display("==================================================");
        $display("  Total Triggers Detected : %0d (Expected: 2)", trigger_count);
        $display("  Total Errors Detected   : %0d (Expected: 0)", error_count);

        if (error_count == 0 && trigger_count == 2) begin
            $display("    [PASSED]    ");
        end else begin
            $display("    [FAILED]    ");
        end
        $display("==================================================\n");
    end

endmodule
