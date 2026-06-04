`timescale 1ns/1ps
// =============================================================================
// async_fifo
// Dual-clock asynchronous FIFO with Gray-code pointer CDC.
// - Standard FIFO logic (1-cycle read latency, NOT FWFT)
// - Vivado BRAM inference compliant (No async reset on memory array)
// - Standardized on Current-Pointer Compare style for full-depth utilization
// - Hardened CDC paths with ASYNC_REG placement constraints
// =============================================================================

module async_fifo #(
    parameter DATA_WIDTH = 27,
    parameter ADDR_WIDTH = 12
)(
    input  wire                  wr_clk,
    input  wire                  rd_clk,
    input  wire                  rst_n,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  wr_en,
    output wire                  full,
    output wire                  prog_full,
    output wire [DATA_WIDTH-1:0] rd_data,
    input  wire                  rd_en,
    output wire                  empty,
    output wire                  prog_empty
);

    localparam DEPTH             = (1 << ADDR_WIDTH);
    localparam PROG_FULL_THRESH  = 3072;
    localparam PROG_EMPTY_THRESH = 1024;

    // Dual-port Block RAM Inference (Dedicated from reset blocks)
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    reg [DATA_WIDTH-1:0] rd_data_reg;
    assign rd_data = rd_data_reg;

    // Internal Pointers
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    reg [ADDR_WIDTH:0] wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_bin;
    reg [ADDR_WIDTH:0] rd_ptr_gray;

    // CDC Synchronizer Chains with strict AMD/Xilinx Vivado Placement Attributes
    (* ASYNC_REG = "TRUE" *) reg [ADDR_WIDTH:0] wr_rd_ptr_gray_s1, wr_rd_ptr_gray_s2;
    (* ASYNC_REG = "TRUE" *) reg [ADDR_WIDTH:0] rd_wr_ptr_gray_s1, rd_wr_ptr_gray_s2;

    // =========================================================================
    // Gray / Binary Conversion Functions
    // =========================================================================
    function automatic [ADDR_WIDTH:0] bin2gray (input [ADDR_WIDTH:0] bin);
        begin
            bin2gray = bin ^ (bin >> 1);
        end
    endfunction

    function automatic [ADDR_WIDTH:0] gray2bin (input [ADDR_WIDTH:0] gray);
        integer i;
        begin
            gray2bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
            for (i = ADDR_WIDTH-1; i >= 0; i = i - 1)
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
        end
    endfunction

    // =========================================================================
    // Write Domain Logic
    // =========================================================================
    wire wr_fire = wr_en && !full;

    // 1. DEDICATED BRAM WRITE BLOCK (No asynchronous reset to allow BRAM inference)
    always @(posedge wr_clk) begin
        if (wr_fire) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end

    // 2. POINTER & CDC LOGIC (With asynchronous reset)
    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_rd_ptr_gray_s1 <= {(ADDR_WIDTH+1){1'b0}};
            wr_rd_ptr_gray_s2 <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_bin        <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray       <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            // CDC: Double-flop synchronize read pointer into write domain
            wr_rd_ptr_gray_s1 <= rd_ptr_gray;
            wr_rd_ptr_gray_s2 <= wr_rd_ptr_gray_s1;
            
            // Pointer update on successful write transaction
            if (wr_fire) begin
                wr_ptr_bin  <= wr_ptr_bin + 1'b1;
                wr_ptr_gray <= bin2gray(wr_ptr_bin + 1'b1);
            end
        end
    end

    // Current-Pointer Full Detection Method
    assign full = (wr_ptr_gray == {~wr_rd_ptr_gray_s2[ADDR_WIDTH:ADDR_WIDTH-1], wr_rd_ptr_gray_s2[ADDR_WIDTH-2:0]});
    
    // Programmable Full Flag Generation
    wire [ADDR_WIDTH:0] wr_rd_ptr_bin = gray2bin(wr_rd_ptr_gray_s2);
    assign prog_full = ((wr_ptr_bin - wr_rd_ptr_bin) >= PROG_FULL_THRESH);

    // =========================================================================
    // Read Domain Logic
    // =========================================================================
    wire rd_fire = rd_en && !empty;

    // 3. DEDICATED BRAM READ BLOCK (No asynchronous reset to allow BRAM inference)
    always @(posedge rd_clk) begin
        if (rd_fire) begin
            rd_data_reg <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
        end
    end

    // 4. POINTER & CDC LOGIC (With asynchronous reset)
    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_wr_ptr_gray_s1 <= {(ADDR_WIDTH+1){1'b0}};
            rd_wr_ptr_gray_s2 <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_bin        <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray       <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            // CDC: Double-flop synchronize write pointer into read domain
            rd_wr_ptr_gray_s1 <= wr_ptr_gray;
            rd_wr_ptr_gray_s2 <= rd_wr_ptr_gray_s1;
            
            // Pointer update on successful read transaction
            if (rd_fire) begin
                rd_ptr_bin  <= rd_ptr_bin + 1'b1;
                rd_ptr_gray <= bin2gray(rd_ptr_bin + 1'b1);
            end
        end
    end

    // Current-Pointer Empty Detection Method
    assign empty = (rd_ptr_gray == rd_wr_ptr_gray_s2);
    
    // Programmable Empty Flag Generation
    wire [ADDR_WIDTH:0] rd_wr_ptr_bin = gray2bin(rd_wr_ptr_gray_s2);
    assign prog_empty = ((rd_wr_ptr_bin - rd_ptr_bin) <= PROG_EMPTY_THRESH);

endmodule