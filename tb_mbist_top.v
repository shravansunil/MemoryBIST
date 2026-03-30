`timescale 1ns / 1ps

module tb_mbist_top;

    reg clk;
    reg rst;
    reg start;
    wire done;
    wire fail;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------
    // TEST CASE 1: NO FAULTS (Should PASS)
    // -----------------------------------------------------------
//    mbist_top #(
//        .FAULT_EN(1)
//    ) dut_clean (
//        .clk(clk),
//        .rst(rst),
//        .start(start),
//        .done(done),
//        .fail(fail)
//    );
    
    // Uncomment this and comment out dut_clean above to test faulty memory
    
    mbist_top #(
        .FAULT_EN(1),
        .FAULT_ADDR(3'd4),
        .STUCK_AT_0(1), // Address 4 is stuck at 0
        .STUCK_AT_1(0)
    ) dut_faulty (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .fail(fail)
    );

    initial begin
        // Reset
        rst = 1;
        start = 0;
        #20 rst = 0;

        // Start
        #10 start = 1;
        #10 start = 0;

        // Wait for Done
        wait(done);
        
        // Report
        if (fail) $display("TEST FAILED");
        else      $display("TEST PASSED");

        #50 $finish;
    end

endmodule