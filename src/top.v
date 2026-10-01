module top (
    // Core Clock (50MHz)
    input  wire        clk_sys,

    // Interface to External SRAM (Mapped via Analogue OS)
    output wire [21:0] sram_addr,
    input  wire [15:0] sram_data,

    // Video Output Signals
    output reg         video_hs,
    output reg         video_vs,
    output reg         video_de,
    output reg  [7:0]  video_r,
    output reg  [7:0]  video_g,
    output reg  [7:0]  video_b
);

    // Video Display Timings for 800x800
    reg [10:0] h_count = 0;
    reg [10:0] v_count = 0;

    localparam H_ACTIVE = 800;
    localparam H_FRONT  = 40;
    localparam H_SYNC   = 128;
    localparam H_BACK   = 88;
    localparam H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;

    localparam V_ACTIVE = 800;
    localparam V_FRONT  = 10;
    localparam V_SYNC   = 2;
    localparam V_BACK   = 25;
    localparam V_TOTAL  = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

    always @(posedge clk_sys) begin
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

    // Signal generation for Sync and Data Enable
    always @(posedge clk_sys) begin
        video_hs <= !((h_count >= (H_ACTIVE + H_FRONT)) && (h_count < (H_ACTIVE + H_FRONT + H_SYNC)));
        video_vs <= !((v_count >= (V_ACTIVE + V_FRONT)) && (v_count < (V_ACTIVE + V_FRONT + V_SYNC)));
        video_de <= (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    end

    // 24-bit True Color Address Mapping (2 words per pixel)
    // Pixel index = (v * 800) + h. Memory word address = index * 2.
    wire [10:0] next_h = (h_count == H_TOTAL - 1) ? 11'd0 : h_count + 11'd1;
    wire [10:0] next_v = (h_count == H_TOTAL - 1) ? ((v_count == V_TOTAL - 1) ? 11'd0 : v_count + 11'd1) : v_count;
    
    wire [21:0] pixel_index = (next_v * 22'd800) + next_h;
    
    // Toggle the lowest address bit to fetch High vs Low halves of the 32-bit container
    // We alternate fetching Word 0 (Padded/Red) and Word 1 (Green/Blue) using a fast sub-clock cycle or counter step
    reg fetch_phase = 0;
    always @(posedge clk_sys) begin
        fetch_phase <= ~fetch_phase;
    end

    assign sram_addr = (next_v < 800 && next_h < 800) ? {pixel_index[20:0], fetch_phase} : 22'd0;

    // Buffer registers to assemble the split data chunks
    reg [7:0] r_buf;
    reg [7:0] g_buf;
    reg [7:0] b_buf;

    always @(posedge clk_sys) begin
        if (!fetch_phase) begin
            // Word 0 contains Red in lower byte (upper byte is dummy padding)
            r_buf <= sram_data[7:0];
        end else begin
            // Word 1 contains Green in upper byte, Blue in lower byte
            g_buf <= sram_data[15:8];
            b_buf <= sram_data[7:0];
        end
    end

    // Output raw color assignments straight to screen matrix
    always @(posedge clk_sys) begin
        if (video_de) begin
            video_r <= r_buf;
            video_g <= g_buf;
            video_b <= b_buf;
        end else begin
            video_r <= 8'd0;
            video_g <= 8'd0;
            video_b <= 8'd0;
        end
    end

endmodule

