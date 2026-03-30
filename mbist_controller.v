`timescale 1ns / 1ps

module mbist_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    output reg        we,
    output reg        re,
    output reg [2:0]  addr,
    output reg [7:0]  din,
    input  wire [7:0] dout,
    output reg        done,
    output reg        fail
);

    reg [4:0] state;
    reg [7:0] expected;

    // --- STATE ENCODING ---
    localparam IDLE          = 0;
    localparam UP_W0         = 1;
    
    // (r0, w1) UP
    localparam UP_R0_READ    = 2;
    localparam UP_R0_WAIT    = 3;
    localparam UP_R0_CHECK   = 4;
    localparam UP_R0_WRITE   = 5; // NEW

    // (r1, w0) UP
    localparam UP_R1_READ    = 6;
    localparam UP_R1_WAIT    = 7;
    localparam UP_R1_CHECK   = 8;
    localparam UP_R1_WRITE   = 9; // NEW

    // (r0, w1) DOWN
    localparam DOWN_R0_READ  = 10;
    localparam DOWN_R0_WAIT  = 11;
    localparam DOWN_R0_CHECK = 12;
    localparam DOWN_R0_WRITE = 13; // NEW

    // (r1, w0) DOWN
    localparam DOWN_R1_READ  = 14;
    localparam DOWN_R1_WAIT  = 15;
    localparam DOWN_R1_CHECK = 16;
    localparam DOWN_R1_WRITE = 17; // NEW

    // (r0) UP
    localparam UP_R0F_READ   = 18;
    localparam UP_R0F_WAIT   = 19;
    localparam UP_R0F_CHECK  = 20;
    
    localparam FINISH        = 21;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            addr  <= 0;
            we    <= 0;
            re    <= 0;
            din   <= 0;
            done  <= 0;
            fail  <= 0;
        end else begin
            // Defaults
            we <= 0;
            re <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        addr  <= 0;
                        state <= UP_W0;
                    end
                end

                // -------------------------------------------------
                // Initialize Memory (Write 0s)
                UP_W0: begin
                    we  <= 1;
                    din <= 8'h00;
                    if (addr == 7) begin
                        addr  <= 0;
                        state <= UP_R0_READ;
                    end else begin
                        addr <= addr + 1;
                    end
                end

                // -------------------------------------------------
                // Element 1: (r0, w1) UP
                UP_R0_READ: begin
                    re       <= 1;
                    expected <= 8'h00;
                    state    <= UP_R0_WAIT;
                end
                UP_R0_WAIT: state <= UP_R0_CHECK;
                UP_R0_CHECK: begin
                    // Check Data
                    if (dout !== expected) begin
                        fail <= 1;
                        $display("FAIL at %t: Addr %d | Exp %h | Got %h", $time, addr, expected, dout);
                    end
                    // Prep Write: Set WE=1, Keep Addr same
                    we    <= 1;
                    din   <= 8'hFF;
                    state <= UP_R0_WRITE; 
                end
                UP_R0_WRITE: begin
                    // WE is high during this state. Complete the write.
                    // Now move to next address
                    if (addr == 7) begin
                        addr  <= 0;
                        state <= UP_R1_READ;
                    end else begin
                        addr  <= addr + 1;
                        state <= UP_R0_READ;
                    end
                end

                // -------------------------------------------------
                // Element 2: (r1, w0) UP
                UP_R1_READ: begin
                    re       <= 1;
                    expected <= 8'hFF;
                    state    <= UP_R1_WAIT;
                end
                UP_R1_WAIT: state <= UP_R1_CHECK;
                UP_R1_CHECK: begin
                    if (dout !== expected) begin
                        fail <= 1;
                        $display("FAIL at %t: Addr %d | Exp %h | Got %h", $time, addr, expected, dout);
                    end
                    we    <= 1;
                    din   <= 8'h00;
                    state <= UP_R1_WRITE;
                end
                UP_R1_WRITE: begin
                    if (addr == 7) begin
                        // Keep addr 7 for Down count
                        state <= DOWN_R0_READ;
                    end else begin
                        addr  <= addr + 1;
                        state <= UP_R1_READ;
                    end
                end

                // -------------------------------------------------
                // Element 3: (r0, w1) DOWN
                DOWN_R0_READ: begin
                    re       <= 1;
                    expected <= 8'h00;
                    state    <= DOWN_R0_WAIT;
                end
                DOWN_R0_WAIT: state <= DOWN_R0_CHECK;
                DOWN_R0_CHECK: begin
                    if (dout !== expected) begin
                        fail <= 1;
                        $display("FAIL at %t: Addr %d | Exp %h | Got %h", $time, addr, expected, dout);
                    end
                    we    <= 1;
                    din   <= 8'hFF;
                    state <= DOWN_R0_WRITE;
                end
                DOWN_R0_WRITE: begin
                    if (addr == 0) begin
                        state <= DOWN_R1_READ;
                    end else begin
                        addr  <= addr - 1;
                        state <= DOWN_R0_READ;
                    end
                end

                // -------------------------------------------------
                // Element 4: (r1, w0) DOWN
                DOWN_R1_READ: begin
                    re       <= 1;
                    expected <= 8'hFF;
                    state    <= DOWN_R1_WAIT;
                end
                DOWN_R1_WAIT: state <= DOWN_R1_CHECK;
                DOWN_R1_CHECK: begin
                    if (dout !== expected) begin
                        fail <= 1;
                        $display("FAIL at %t: Addr %d | Exp %h | Got %h", $time, addr, expected, dout);
                    end
                    we    <= 1;
                    din   <= 8'h00;
                    state <= DOWN_R1_WRITE;
                end
                DOWN_R1_WRITE: begin
                    if (addr == 0) begin
                        state <= UP_R0F_READ;
                    end else begin
                        addr  <= addr - 1;
                        state <= DOWN_R1_READ;
                    end
                end

                // -------------------------------------------------
                // Element 5: (r0) UP Final
                UP_R0F_READ: begin
                    re       <= 1;
                    expected <= 8'h00;
                    state    <= UP_R0F_WAIT;
                end
                UP_R0F_WAIT: state <= UP_R0F_CHECK;
                UP_R0F_CHECK: begin
                    if (dout !== expected) begin
                        fail <= 1;
                        $display("FAIL at %t: Addr %d | Exp %h | Got %h", $time, addr, expected, dout);
                    end
                    if (addr == 7) state <= FINISH;
                    else begin
                        addr  <= addr + 1;
                        state <= UP_R0F_READ;
                    end
                end

                FINISH: done <= 1;
            endcase
        end
    end
endmodule