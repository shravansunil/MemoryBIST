`timescale 1ns / 1ps

module mbist_top #(
    // Parameters passed from TB to here, then to SRAM
    parameter FAULT_EN   = 0,
    parameter FAULT_ADDR = 3'd4,
    parameter STUCK_AT_0 = 0,
    parameter STUCK_AT_1 = 0
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    output wire done,
    output wire fail
);

    wire        we;
    wire        re;
    wire [2:0]  addr;
    wire [7:0]  din;
    wire [7:0]  dout;

    mbist_controller u_mbist (
        .clk(clk),
        .rst(rst),
        .start(start),
        .we(we),
        .re(re),
        .addr(addr),
        .din(din),
        .dout(dout),
        .done(done),
        .fail(fail)
    );

    sram_faulty #(
        .FAULT_EN(FAULT_EN),
        .FAULT_ADDR(FAULT_ADDR),
        .STUCK_AT_0(STUCK_AT_0),
        .STUCK_AT_1(STUCK_AT_1)
    ) u_mem (
        .clk(clk),
        .we(we),
        .re(re),
        .addr(addr),
        .din(din),
        .dout(dout)
    );

endmodule