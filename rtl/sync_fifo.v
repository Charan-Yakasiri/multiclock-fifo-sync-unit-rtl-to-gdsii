`timescale 1ns / 1ps

module sync_fifo #(
    parameter DATA_WIDTH        = 27,
    parameter ADDR_WIDTH        = 12,
    parameter PROG_FULL_THRESH  = 3072,
    parameter PROG_EMPTY_THRESH = 1024
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Write Interface
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  wr_en,
    output wire                  full,
    output wire                  prog_full,
    
    // Read Interface
    output reg  [DATA_WIDTH-1:0] rd_data,
    input  wire                  rd_en,
    output wire                  empty,
    output wire                  prog_empty,
    
    // Status
    output wire [ADDR_WIDTH:0]   fill_level
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    // --- Flags & Status Logic (Combinatorial) ---
    assign fill_level = wr_ptr - rd_ptr;
    assign empty      = (fill_level == 0);
    assign full       = (fill_level == DEPTH);
    assign prog_full  = (fill_level >= PROG_FULL_THRESH);
    assign prog_empty = (fill_level <= PROG_EMPTY_THRESH);

    // --- Write Interface Sync Logic ---
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr                      <= wr_ptr + 1'b1;
        end
    end

    // --- Read Interface Sync Logic ---
    // Look-ahead combination reading directly out of our inferable RAM block array
    wire [DATA_WIDTH-1:0] ram_out = mem[rd_ptr[ADDR_WIDTH-1:0]];

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr  <= {(ADDR_WIDTH+1){1'b0}};
            rd_data <= {DATA_WIDTH{1'b0}};
        end else begin
            if (rd_en && !empty) begin
                rd_ptr  <= rd_ptr + 1'b1;
                // Capture the look-ahead value directly into our output register boundary
                rd_data <= ram_out; 
            end
        end
    end

endmodule