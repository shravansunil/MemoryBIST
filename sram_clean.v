`timescale 1ns / 1ps

module sram_faulty #(
    parameter FAULT_EN    = 0,
    parameter FAULT_ADDR  = 3'd4,
    parameter STUCK_AT_0  = 0,
    parameter STUCK_AT_1  = 0
)(
    input  wire       clk,
    input  wire       we,
    input  wire       re,
    input  wire [2:0] addr,
    input  wire [7:0] din,
    output reg  [7:0] dout
);

    reg [7:0] mem [0:7];
    integer i;

    initial begin
        for (i = 0; i < 8; i = i + 1)
            mem[i] = 8'h00;
    end

    always @(posedge clk) begin
        // Write Operation
        if (we) begin
            mem[addr] <= din;
        end

        // Read Operation with Fault Injection
        if (re) begin
            if (FAULT_EN && (addr == FAULT_ADDR)) begin
                if (STUCK_AT_0)      dout <= 8'h00;
                else if (STUCK_AT_1) dout <= 8'hFF;
                else                 dout <= mem[addr]; // Fallback
            end else begin
                dout <= mem[addr];
            end
        end
    end
endmodule