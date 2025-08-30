/*
 * Copyright (c) 2025 ReJ aka Renaldas Zioma
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.
module tqvp_rejunity_vga (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [5:0]   address,      // Address within this peripheral's address space
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    output        user_interrupt  // Dedicated interrupt request for this peripheral
);
    // 256 pixel vram (16x16, ~18x14, ~25x10)
    // 256x4 = 1024

    // 320 pixel vram (20x16)
    // 320x3 = 960

    // 384 pixel vram (24x16)
    // 384x2 = 768
    // 384x2.5 = 960
    // 

    // vertical
    // 192x4 = 256x3 = 384x2 = 768




    // TODO:
    assign data_ready = 1'b1;
    assign data_out = 32'd0;
    assign vga_cli = (data_write_n != 2'b11); // Any write resets interrupt, TODO if need to be more careful
    // \TODO

    localparam PIXEL_COUNT      = 384;
    localparam REG_LAST_PIXEL   = PIXEL_COUNT / 8 - 1;
    localparam REG_BG_COLOR     = 6'h30;
    localparam REG_FG_COLOR     = 6'h31;
    localparam REG_BANK         = 6'h3F;

    reg [PIXEL_COUNT-1:0] vram;
    reg         vram_write_bank;
    reg [5:0]   bg_color;
    reg [5:0]   fg_color;

    always @(posedge clk) begin
        if (!rst_n) begin
            vram_write_bank <= 1'b0;
            bg_color <= 6'b010000;
            fg_color <= 6'b001011;
        end else begin
            if (~&data_write_n) begin
                // if (address < REG_BG_COLOR) begin
                //     if (data_write_n == 2'b10) begin // TODO: only 32-bit writes are supported atm
                //         vram[{address[4:2], 5'b00000} +: 32] <= data_in[31:0];
                //     end
                if (address <= REG_LAST_PIXEL) begin
                    if (data_write_n == 2'b10) begin // TODO: only 32-bit writes are supported atm
                        vram[{address[5:2], 5'b00000} +: 32] <= data_in[31:0];
                    end
                // if (address < 6'h20) begin
                //     if (data_write_n == 2'b10) begin // TODO: only 32-bit writes are supported atm
                //         vram[{vram_write_bank, address[4:2], 5'b00000} +: 32] <= data_in[31:0];
                //     end
                end else if (address == REG_BG_COLOR) begin
                    bg_color <= data_in[5:0];
                end else if (address == REG_FG_COLOR) begin
                    fg_color <= data_in[5:0];
                end else if (address == REG_BANK) begin
                    vram_write_bank <= data_in[0];
                end
            end
        end
    end

    wire        vga_cli;
    wire [10:0] vga_x;
    wire  [9:0] vga_y;
    wire        vga_hsync;
    wire        vga_vsync;
    wire        vga_blank;

    vga_timing vga (
        .clk,
        .rst_n,
        .cli(vga_cli),
        .x(vga_x),
        .y(vga_y),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .blank(vga_blank),
        .interrupt(user_interrupt)
    );

    reg [8:0] vram_index;
    always @(posedge clk) begin
        if (!rst_n) begin
            vram_index <= 9'd0;
        end else if (vram_index == PIXEL_COUNT-1) begin
            vram_index <= 9'd0;
        end else begin
            vram_index <= vram_index + 9'd1;
        end
    end

    reg pixel;
    reg hsync_buf;
    reg vsync_buf;

    always @(posedge clk) begin
        if (!rst_n) begin
            pixel <= 1'b0;
        end else if (vga_blank) begin
            pixel <= 1'b0;
        end else begin
            // pixel <= vram[vga_x[7:0]];
            pixel <= vram[vram_index];
        end
        hsync_buf <= vga_hsync;
        vsync_buf <= vga_vsync;
    end

    always @(posedge clk) begin
    end

    wire [5:0] rrggbb = pixel ? fg_color : bg_color;
    assign uo_out = {hsync_buf, rrggbb[5:3], vsync_buf, rrggbb[2:0]};

    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    wire _unused = &{data_read_n, 1'b0};

endmodule
