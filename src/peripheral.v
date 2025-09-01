/*
 * Copyright (c) 2025 ReJ aka Renaldas Zioma
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

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
    // length 


    // 256 pixel vram (16x16, ~18x14, ~25x10)
    // 256x3 = 768
    // 256x4 = 1024

    // 320 pixel vram (20x16)
    // 320x3 = 960

    // 384 pixel vram (24x16)
    // 384x2 = 768
    // 384x2.5 = 960

    // vertical
    // 192x4 = 256x3 = 384x2 = 768


    // TODO:
    // REG_SET_VRAM_INDEX = 10bit
    // REG_SET_1024vs960 = 1bit
    // REG_SET_4COLOR = 1bit
    // REG_SET_COLOR2, REG_SET_COLOR3 = 6bit x 2
    // \TODO

    `define PIXEL_COUNT 320
    localparam [5:0]    REG_LAST_PIXEL      = `PIXEL_COUNT / 8 - 1;
    localparam [5:0]    REG_BG_COLOR        = 6'h30;
    localparam [5:0]    REG_FG_COLOR        = 6'h31;
    localparam [5:0]    REG_VRAM_STRIDE     = 6'h34;
    localparam [5:0]    REG_PIXEL_SIZE      = 6'h38;
    localparam [5:0]    REG_MODE            = 6'h3C;

    localparam [5:0]    REQ_WAIT_HBLANK     = 6'h00;
    localparam [5:0]    REQ_WAIT_PIXEL0     = 6'h04;
    // localparam REG_Y            = 6'h10;

    // test 20x384
    // localparam DEFAULT_STRIDE = 9'd20;
    // localparam DEFAULT_PIXEL_WIDTH  = 7'd48; // 960/20=48
    // localparam DEFAULT_PIXEL_HEIGHT = 7'd2;

    // 320 vram = 20x16 @ 960x768
    // localparam DEFAULT_STRIDE = 9'd20;
    // localparam DEFAULT_PIXEL_WIDTH  = 7'd48; // 960/20=48
    // localparam DEFAULT_PIXEL_HEIGHT = 7'd48; // 768/16=48

    // 320 vram = 20x16 @ 1024x768
    localparam DEFAULT_STRIDE = 9'd20;
    localparam DEFAULT_PIXEL_WIDTH  = 7'd52; // 1024/20=~52
    // localparam DEFAULT_PIXEL_HEIGHT = 7'd48; // 768/16=48

    // 320 vram = 32x10 @ 1024x768
    // localparam DEFAULT_STRIDE = 9'd32;
    // localparam DEFAULT_PIXEL_WIDTH  = 7'd32; // 1024/32=32
    // localparam DEFAULT_PIXEL_HEIGHT = 7'd77; // 768/10=~77


    // 256 vram = 18x14 @ 1024x768
    // localparam DEFAULT_STRIDE = 9'd18;
    // localparam DEFAULT_PIXEL_WIDTH  = 7'd54; // 1024/18=~54
    // localparam DEFAULT_PIXEL_HEIGHT = 7'd55; // 768/14=~55

    localparam DEFAULT_PIXEL_HEIGHT = 7'd2;


    // registers
    reg [`PIXEL_COUNT-1:0] vram;
    reg [5:0]   bg_color;
    reg [5:0]   fg_color;
    reg [1:0]   interrupt_type;
    reg         vga_960_vs_1024;

    reg         pause_cpu;
    reg         wait_hblank;
    reg         wait_pixel0;
    assign data_ready = !pause_cpu;

    always @(posedge clk) begin
        if (!rst_n) begin
            bg_color <= 6'b010000;
            fg_color <= 6'b001011;
            
            vram_stride     <= DEFAULT_STRIDE;
            vga_x_per_pixel <= DEFAULT_PIXEL_WIDTH  - 7'd1;
            vga_y_per_pixel <= DEFAULT_PIXEL_HEIGHT - 7'd1;

            interrupt_type  <= 2'b00;
            vga_960_vs_1024 <= 1'b0;

            pause_cpu   <= 1'b0;
            wait_hblank <= 1'b0;
            wait_pixel0 <= 1'b0;
        end else begin
            // WRITE register
            if (~&data_write_n) begin
                if (address <= REG_LAST_PIXEL) begin
                    if (data_write_n == 2'b10) begin // TODO: only 32-bit writes are supported atm
                        vram[{address[5:2], 5'b00000} +: 32] <= data_in[31:0];
                    end
                end else if (address == REG_BG_COLOR) begin  // TODO: support 32-bit writes
                    bg_color <= data_in[5:0];
                end else if (address == REG_FG_COLOR) begin  // TODO: support 32-bit writes
                    fg_color <= data_in[5:0];
                end else if (address == REG_VRAM_STRIDE) begin
                    vram_stride <= data_in[8:0];
                    // if (data_write_n == 2'b00) // TODO: support 8-bit write as well by setting highest bit(s) to 0
                end else if (address == REG_PIXEL_SIZE) begin // TODO: support 8-bit/16-bit writes
                    vga_x_per_pixel <= data_in[0  +: 6];
                    vga_y_per_pixel <= data_in[16 +: 6];
                end else if (address == REG_MODE) begin
                    interrupt_type <= data_in[1:0];
                    vga_960_vs_1024 <= data_in[2];
                end
                
            // READ register
            end else if (~&data_read_n) begin
                if          (address == REQ_WAIT_HBLANK) begin
                    pause_cpu   <= 1'b1;
                    wait_hblank <= 1'b1;
                    wait_pixel0 <= 1'b0;
                end else if (address == REQ_WAIT_PIXEL0) begin
                    pause_cpu   <= 1'b1;
                    wait_hblank <= 1'b0;
                    wait_pixel0 <= 1'b1;
                end
            end

            if (wait_hblank && vga_blank) begin // NOTE: do not block cpu during the VBLANK/VSYNC
                                                // TODO: block until the next blank, if already inside the blank
                pause_cpu   <= 1'b0;
                wait_hblank <= 1'b0;
            end
            if (wait_pixel0 && vram_index == 0) begin
                pause_cpu   <= 0;
                wait_pixel0 <= 0;
            end
        end
    end

    wire vga_cli          = (data_write_n != 2'b11); // Any write resets interrupt, TODO if need to be more careful
    wire vga_ei_frame     = (interrupt_type == 2'b00);
    wire vga_ei_scanline  = (interrupt_type == 2'b01);
    wire vga_ei_pixline   = (interrupt_type == 2'b10);
    wire vga_ei_vblank    = vga_ei_frame;
    wire vga_ei_hblank    = vga_ei_scanline || (vga_ei_pixline && vram_pixel_y == vga_y_per_pixel);

    wire [10:0] vga_x;
    wire  [9:0] vga_y;
    wire        vga_hsync;
    wire        vga_vsync;
    wire        vga_new_scanline;
    wire        vga_blank;

    vga_timing vga (
        .clk,
        .rst_n,
        .cli(vga_cli),
        .enable_interrupt_on_hblank(vga_ei_hblank),
        .enable_interrupt_on_vblank(vga_ei_vblank),
        .narrow_960(vga_960_vs_1024),
        .x(vga_x),
        .y(vga_y),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .retrace(vga_new_scanline),
        .blank(vga_blank),
        .interrupt(user_interrupt)
    );

    reg [6:0] vga_x_per_pixel;
    reg [6:0] vga_y_per_pixel;
    reg [6:0] vram_pixel_x;
    reg [6:0] vram_pixel_y;
    reg [8:0] vram_index_on_blank;
    reg [8:0] vram_stride;
    reg [8:0] vram_index;

    wire [8:0] advance_vram_index_by_one    = (vram_index + 9'd1        < `PIXEL_COUNT)  ? vram_index + 9'd1
                                                                                        : 9'd0;

    wire [8:0] advance_vram_index_by_stride = (vram_index_on_blank + 
                                                            vram_stride < `PIXEL_COUNT)  ? vram_index_on_blank + vram_stride
                                                                                        : 9'd0;

    always @(posedge clk) begin
        if (!rst_n) begin
            vram_index_on_blank 
                            <= 9'd0;
            vram_index      <= 9'd0;
            vram_pixel_x    <= 7'd0;
            vram_pixel_y    <= 7'd0;

        end else if (vga_new_scanline) begin
            vram_pixel_x <= 7'd0;
            if (vram_pixel_y == vga_y_per_pixel) begin
                vram_pixel_y <= 7'd0;
                vram_index   <= advance_vram_index_by_stride;
                vram_index_on_blank <= advance_vram_index_by_stride;
            end else begin
                vram_pixel_y <= vram_pixel_y + 7'd1;
                vram_index   <= vram_index_on_blank;
            end

        end else if (vga_blank) begin
            vram_pixel_x <= 7'd0;

        end else begin
            if (vram_pixel_x == vga_x_per_pixel) begin
                vram_index   <= advance_vram_index_by_one;
                vram_pixel_x <= 7'd0;
            end else begin
                vram_pixel_x <= vram_pixel_x + 7'd1;
            end
        end
    end

    reg [5:0] bbggrr;
    reg hsync_buf;
    reg vsync_buf;

    always @(posedge clk) begin
        if (!rst_n) begin
            bbggrr <= 6'b00_00_00;
        end else if (vga_blank) begin
            bbggrr <= 6'b00_00_00;
        end else begin
            bbggrr <= vram[vram_index] ? fg_color : bg_color;
        end
        hsync_buf <= vga_hsync;
        vsync_buf <= vga_vsync;
    end

    assign uo_out = {hsync_buf, bbggrr[5:3], vsync_buf, bbggrr[2:0]};
    assign data_out = {22'd0, vga_y};

    // List all unused inputs to prevent warnings
    wire _unused = &{ui_in, vga_x, 1'b0};

endmodule
