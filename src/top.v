module top (
    // Core Clock (50MHz)
    input  wire        clk_sys,

    // External Cellular RAM Address Pins
    output wire        sram_addr_0,  sram_addr_1,  sram_addr_2,  sram_addr_3,
    output wire        sram_addr_4,  sram_addr_5,  sram_addr_6,  sram_addr_7,
    output wire        sram_addr_8,  sram_addr_9,  sram_addr_10, sram_addr_11,
    output wire        sram_addr_12, sram_addr_13, sram_addr_14, sram_addr_15,
    output wire        sram_addr_16, sram_addr_17, sram_addr_18, sram_addr_19,
    output wire        sram_addr_20, sram_addr_21,

    // External Cellular RAM Bidirectional Data Pins
    input  wire        sram_data_0,  sram_data_1,  sram_data_2,  sram_data_3,
    input  wire        sram_data_4,  sram_data_5,  sram_data_6,  sram_data_7,
    input  wire        sram_data_8,  sram_data_9,  sram_data_10, sram_data_11,
    input  wire        sram_data_12, sram_data_13, sram_data_14, sram_data_15,

    // Video Sync & Control Signals
    output reg         video_hs,
    output reg         video_vs,
    output reg         video_de,

    // Video Matrix Red Channel Outputs
    output reg         video_r_0, video_r_1, video_r_2, video_r_3,
    output reg         video_r_4, video_r_5, video_r_6, video_r_7,

    // Video Matrix Green Channel Outputs
    output reg         video_g_0, video_g_1, video_g_2, video_g_3,
    output reg         video_g_4, video_g_5, video_g_6, video_g_7,

    // Video Matrix Blue Channel Outputs
    output reg         video_b_0, video_b_1, video_b_2, video_b_3,
    output reg         video_b_4, video_b_5, video_b_6, video_b_7
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

    // Sync and Data Enable Generation
    always @(posedge clk_sys) begin
        video_hs <= !((h_count >= (H_ACTIVE + H_FRONT)) && (h_count < (H_ACTIVE + H_FRONT + H_SYNC)));
        video_vs <= !((v_count >= (V_ACTIVE + V_FRONT)) && (v_count < (V_ACTIVE + V_FRONT + V_SYNC)));
        video_de <= (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    end

    // Address Lookahead Calculation
    wire [10:0] next_h = (h_count == H_TOTAL - 1) ? 11'd0 : h_count + 11'd1;
    wire [10:0] next_v = (h_count == H_TOTAL - 1) ? ((v_count == V_TOTAL - 1) ? 11'd0 : v_count + 11'd1) : v_count;
    
    wire [21:0] pixel_index = (next_v * 22'd800) + next_h;
    
    reg fetch_phase = 0;
    always @(posedge clk_sys) begin
        fetch_phase <= ~fetch_phase;
    end

    wire [21:0] internal_sram_addr = (next_v < 800 && next_h < 800) ? {pixel_index[20:0], fetch_phase} : 22'd0;

    // Concatenate and distribute clean assignments out to single pins
    assign {sram_addr_21, sram_addr_20, sram_addr_19, sram_addr_18, 
            sram_addr_17, sram_addr_16, sram_addr_15, sram_addr_14, 
            sram_addr_13, sram_addr_12, sram_addr_11, sram_addr_10, 
            sram_addr_9,  sram_addr_8,  sram_addr_7,  sram_addr_6, 
            sram_addr_5,  sram_addr_4,  sram_addr_3,  sram_addr_2, 
            sram_addr_1,  sram_addr_0} = internal_sram_addr;

    // Bundle incoming data single-bit streams back into an internal bus vector
    wire [15:0] internal_sram_data = {
        sram_data_15, sram_data_14, sram_data_13, sram_data_12,
        sram_data_11, sram_data_10, sram_data_9,  sram_data_8,
        sram_data_7,  sram_data_6,  sram_data_5,  sram_data_4,
        sram_data_3,  sram_data_2,  sram_data_1,  sram_data_0
    };

    // Color Reconstruction Buffer
    reg [7:0] r_buf;
    reg [7:0] g_buf;
    reg [7:0] b_buf;

    always @(posedge clk_sys) begin
        if (!fetch_phase) begin
            r_buf <= internal_sram_data[7:0];
        end else begin
            g_buf <= internal_sram_data[15:8];
            b_buf <= internal_sram_data[7:0];
        end
    end

    // Assign buffered true colors to descriptive output channels
    always @(posedge clk_sys) begin
        if (video_de) begin
            {video_r_7, video_r_6, video_r_5, video_r_4, video_r_3, video_r_2, video_r_1, video_r_0} <= r_buf;
            {video_g_7, video_g_6, video_g_5, video_g_4, video_g_3, video_g_2, video_g_1, video_g_0} <= g_buf;
            {video_b_7, video_b_6, video_b_5, video_b_4, video_b_3, video_b_2, video_b_1, video_b_0} <= b_buf;
        end else begin
            {video_r_7, video_r_6, video_r_5, video_r_4, video_r_3, video_r_2, video_r_1, video_r_0} <= 8'd0;
            {video_g_7, video_g_6, video_g_5, video_g_4, video_g_3, video_g_2, video_g_1, video_g_0} <= 8'd0;
            {video_b_7, video_b_6, video_b_5, video_b_4, video_b_3, video_b_2, video_b_1, video_b_0} <= 8'd0;
        end
    end

endmodule

