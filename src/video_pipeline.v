module video_pipeline (
    input  wire        clk_pixel,   // Expecting 50MHz from clk_sys
    input  wire        rst,         // Active-high reset
    
    // Video Timing Sync Signals
    output reg         vga_hsync,
    output reg         vga_vsync,
    output reg         vga_blank,   // High during porch/blanking intervals
    output reg  [15:0] vga_rgb,     // 16-bit color (RGB565 layout)
    
    // VRAM Addressing Memory Bus
    output reg  [19:0] mem_address  // Output index to look up pixel (0 to 518,399)
);

    // ── 720x720 Video Array Matrix Constraints (60Hz Timing Specification)
    localparam H_ACTIVE      = 720;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC_PULSE = 62;
    localparam H_BACK_PORCH  = 60;
    localparam H_TOTAL       = H_ACTIVE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

    localparam V_ACTIVE      = 720;
    localparam V_FRONT_PORCH = 3;
    localparam V_SYNC_PULSE = 7;
    localparam V_BACK_PORCH  = 18;
    localparam V_TOTAL       = V_ACTIVE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    // ── Internal Screen Scanning Coordinate Tracking Registers
    reg [10:0] h_count;
    reg [10:0] v_count;

    // ── Horizontal and Vertical Scanning Core Loop Control
    always @(posedge clk_pixel or posedge rst) begin
        if (rst) begin
            h_count <= 11'd0;
            v_count <= 11'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 11'd0;
                if (v_count == V_TOTAL - 1) begin
                    v_count <= 11'd0;
                end else begin
                    v_count <= v_count + 11'd1;
                end
            end else begin
                h_count <= h_count + 11'd1;
            end
        end
    end

    // ── Pipeline Registers: Generate Low-Latency Sync and Blanking Intervals
    always @(posedge clk_pixel or posedge rst) begin
        if (rst) begin
            vga_hsync   <= 1'b1;
            vga_vsync   <= 1'b1;
            vga_blank   <= 1'b1;
            mem_address <= 20'd0;
            vga_rgb     <= 16'd0;
        end else begin
            // 1. Generate Sync Pulses (Active Low)
            vga_hsync <= ~((h_count >= (H_ACTIVE + H_FRONT_PORCH)) && 
                           (h_count < (H_ACTIVE + H_FRONT_PORCH + H_SYNC_PULSE)));
                           
            vga_vsync <= ~((v_count >= (V_ACTIVE + V_FRONT_PORCH)) && 
                           (v_count < (V_ACTIVE + V_FRONT_PORCH + V_SYNC_PULSE)));

            // 2. Control Blanking Flags
            if ((h_count < H_ACTIVE) && (v_count < V_ACTIVE)) begin
                vga_blank <= 1'b0; // Active rendering viewport region
                
                // 3. Increment the memory index to scan the image.bin file linearly
                mem_address <= (v_count * H_ACTIVE) + h_count;
                
                // For a quick diagnostic pattern (before memory blocks are wired):
                // Displays alternating green/black horizontal tracking stripes
                vga_rgb <= (v_count[4]) ? 16'h07E0 : 16'h0000; 
            end else begin
                vga_blank <= 1'b1; // Inside blanking/retrace zones
                vga_rgb   <= 16'h0000; // Force black color lines
            end
        end
    end

endmodule
