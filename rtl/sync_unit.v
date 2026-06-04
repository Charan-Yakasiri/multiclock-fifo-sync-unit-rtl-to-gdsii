`timescale 1ns / 1ps

module sync_unit #(
    parameter DATA_WIDTH = 27,
    parameter ADDR_WIDTH = 12
)(
    // Camera 1 Input Domain (75MHz)
    input  wire                    cam1_pclk,
    input  wire [DATA_WIDTH-1:0]   cam1_data,
    input  wire                    cam1_write_en,
    output wire                    cam1_full,
    output wire                    cam1_prog_full,

    // Camera 2 Input Domain (100MHz - Matches sys_clk)
    input  wire                    cam2_pclk, // This is 100MHz now
    input  wire [DATA_WIDTH-1:0]   cam2_data,
    input  wire                    cam2_write_en,
    output wire                    cam2_full,
    output wire                    cam2_prog_full,

    // System Domain (100MHz)
    input  wire                    sys_clk,
    input  wire                    rst_n,
    input  wire                    out_read_en,
    output wire [DATA_WIDTH-1:0]   out_data_cam1,
    output wire [DATA_WIDTH-1:0]   out_data_cam2,
    output wire                    out_empty,
    output reg                     lock_signal,
    output reg  [2:0]              align_state
);

    // State Encoding
    localparam STATE_RESET      = 3'b000;
    localparam STATE_COMPARING  = 3'b001;
    localparam STATE_ALIGNED    = 3'b010;
    localparam STATE_MISALIGNED = 3'b100;

    reg [2:0] next_state;

    // Internal wires connecting the intermediate buffers to the FSM
    wire [DATA_WIDTH-1:0] fifo1_dout;
    wire [DATA_WIDTH-1:0] fifo2_dout;
    wire                  fifo1_empty;
    wire                  fifo2_empty;
    
    reg                   fifo1_rd_en;
    reg                   fifo2_rd_en;
    reg                   out_fifo_wr_en;

    wire out_fifo1_empty;
    wire out_fifo2_empty;

    // Gating condition: both buffered camera streams must have data to process
    wire streams_valid = (!fifo1_empty && !fifo2_empty);

    // =========================================================================
    // CAMERA 1 INTERFACE: ASYNCHRONOUS FIFO (75MHz -> 100MHz)
    // =========================================================================
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) cam1_async_fifo_inst (
        .wr_clk    (cam1_pclk),
        .rd_clk    (sys_clk),
        .rst_n     (rst_n),
        .wr_data   (cam1_data),
        .wr_en     (cam1_write_en),
        .full      (cam1_full),
        .prog_full (cam1_prog_full),
        .rd_data   (fifo1_dout),
        .rd_en     (fifo1_rd_en),
        .empty     (fifo1_empty),
        .prog_empty()
    );

    // =========================================================================
    // CAMERA 2 INTERFACE: SYNCHRONOUS FIFO (100MHz -> 100MHz)
    // =========================================================================
    // Modified: Cam 2 uses sync_fifo because cam2_pclk == sys_clk (100MHz)
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) cam2_sync_fifo_buf_inst (
        .clk       (sys_clk), // Driven by system domain clock
        .rst_n     (rst_n),
        .wr_data   (cam2_data),
        .wr_en     (cam2_write_en),
        .full      (cam2_full),
        .prog_full (cam2_prog_full),
        .rd_data   (fifo2_dout),
        .rd_en     (fifo2_rd_en),
        .empty     (fifo2_empty),
        .prog_empty(),
        .fill_level()
    );

    // =========================================================================
    // ALIGNMENT STATE MACHINE (100MHz Domain)
    // =========================================================================
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) align_state <= STATE_RESET;
        else        align_state <= next_state;
    end

    always @(*) begin
        next_state = align_state;
        lock_signal = 1'b0;
        fifo1_rd_en = 1'b0;
        fifo2_rd_en = 1'b0;
        out_fifo_wr_en = 1'b0;

        case (align_state)
            STATE_RESET: begin
                if (rst_n) next_state = STATE_COMPARING;
            end

            STATE_COMPARING: begin
                if (streams_valid) begin
                    // Check SOF marker on Bit 26
                    if (fifo1_dout[26] == 1'b1 && fifo2_dout[26] == 1'b1) begin
                        next_state = STATE_ALIGNED;
                    end else begin
                        fifo1_rd_en = !fifo1_dout[26];
                        fifo2_rd_en = !fifo2_dout[26];
                    end
                end
            end

            STATE_ALIGNED: begin
                lock_signal = 1'b1;
                
                if (streams_valid) begin
                    if (fifo1_dout[26] != fifo2_dout[26]) begin
                        next_state = STATE_MISALIGNED;
                    end else begin
                        fifo1_rd_en    = 1'b1;
                        fifo2_rd_en    = 1'b1;
                        out_fifo_wr_en = 1'b1;
                        next_state     = STATE_ALIGNED;
                    end
                end 
                else begin
                    // Throttles the reads if FIFO 1 (from 75MHz) runs temporarily dry
                    fifo1_rd_en    = 1'b0;
                    fifo2_rd_en    = 1'b0;
                    out_fifo_wr_en = 1'b0;
                    next_state     = STATE_ALIGNED;
                end
            end

            STATE_MISALIGNED: begin
                lock_signal = 1'b0;
                fifo1_rd_en = !fifo1_empty;
                fifo2_rd_en = !fifo2_empty;
                next_state  = STATE_COMPARING;
            end

            default: next_state = STATE_RESET;
        endcase
    end

    // =========================================================================
    // OUTPUT STAGE: SYNCHRONOUS ELASTIC FIFOs (100MHz Domain)
    // =========================================================================
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) out_stage_ch1_inst (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .wr_data   (fifo1_dout),
        .wr_en     (out_fifo_wr_en),
        .full      (),
        .prog_full (),
        .rd_data   (out_data_cam1),
        .rd_en     (out_read_en),
        .empty     (out_fifo1_empty),
        .prog_empty(),
        .fill_level()
    );

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) out_stage_ch2_inst (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .wr_data   (fifo2_dout),
        .wr_en     (out_fifo_wr_en),
        .full      (),
        .prog_full (),
        .rd_data   (out_data_cam2),
        .rd_en     (out_read_en),
        .empty     (out_fifo2_empty),
        .prog_empty(),
        .fill_level()
    );

    assign out_empty = out_fifo1_empty || out_fifo2_empty;

endmodule