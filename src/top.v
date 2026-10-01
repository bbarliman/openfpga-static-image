module top (
    input  wire        clk_pixel,    // Pixel clock input (Target ~38.0 MHz for 720x720 @ 60Hz)
    input  wire        rst,          // Reset signal (active high)
    
    // Video Output Signals to APF Bridge
    output reg         vga_hsync,
    output reg         vga_vsync,
    output reg         vga_blank,    // Active when outside visible screen area
    output reg  [15:0] vga_rgb,      // 16-bit color (RGB565 format)
    
    // Memory Interface
    output reg  [19:0] mem_address   // 720 * 720 = 518,400 pixels (Fits inside 20 bits)
);

    // Custom 720x720 Square Canvas Hardware Timing Matrix
    localparam H_ACTIVE = 720;
    localparam H_FRONT  = 32;
    localparam H_SYNC   = 96;
    localparam H_BACK   = 64;
    localparam H_TOTAL  = 912;

    localparam V_ACTIVE = 720;
    localparam V_FRONT  = 1;
    localparam V_SYNC   = 4;
    localparam V_BACK   = 23;
    localparam V_TOTAL  = 748;

    // Coordinate Tracking Registers (10 bits handle values up to 1023)
    reg [9:0] h_count;
    reg [9:0] v_count;
    wire video_active;

    // Matrix Coordinate Counters
    always @(posedge clk_pixel or posedge rst) begin
        if (rst) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 1) begin
                    v_count <= 0;
                end else begin
                    v_count <= v_count + 1;
                end
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // Verify Active Display Region Boundings
    assign video_active = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);

    // Output Sync Latency Alignment (Inverted logic for standard framework bus sync)
    always @(posedge clk_pixel) begin
        vga_hsync <= ~((h_count >= (H_ACTIVE + H_FRONT)) && (h_count < (H_ACTIVE + H_FRONT + H_SYNC)));
        vga_vsync <= ~((v_count >= (V_ACTIVE + V_FRONT)) && (v_count < (V_ACTIVE + V_FRONT + V_SYNC)));
        vga_blank <= ~video_active;
    end

    // Address Sequencing Engine
    always @(posedge clk_pixel or posedge rst) begin
        if (rst) begin
            mem_address <= 0;
            vga_rgb     <= 16'h0000;
        end else begin
            if (video_active) begin
                // Increments linearly across 518,400 address points
                mem_address <= (v_count * H_ACTIVE) + h_count;
                
                // Hardware visual diagnostic pattern (color ramp matrix)
                vga_rgb     <= {h_count[4:0], v_count[5:0], h_count[4:0]}; 
            end else begin
                vga_rgb     <= 16'h0000; // Pin output to absolute black during blanking intervals
            end
        end
    end

endmodule

