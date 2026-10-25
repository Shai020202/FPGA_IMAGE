//  img_sobel.v  ——  Sobel边缘检测
//  I_sw2 = 0 : 直通(灰度/彩色)
//  I_sw2 = 1 : Sobel边缘二值化
module img_sobel(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_sw2,
    input  wire        I_de,
    input  wire [23:0] I_rgb,
    output wire        O_de,
    output wire [23:0] O_rgb
);

    // ---- 1. RGB -> 灰度 ----
    wire [15:0] y_tmp = (I_rgb[23:16]*77 + I_rgb[15:8]*150 + I_rgb[7:0]*29);
    wire [7:0]  gray  = y_tmp[15:8];

    // ---- 2. 列计数器 (0~1023) ----
    reg [9:0] x_cnt;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)  x_cnt <= 10'd0;
        else if(I_de) x_cnt <= (x_cnt == 10'd1023) ? 10'd0 : x_cnt + 1'd1;
    end

    // ---- 2b. 行计数器 (0~599) ----
    reg [9:0] vc_cnt;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)                    vc_cnt <= 10'd0;
        else if(I_de && x_cnt == 10'd1023) vc_cnt <= (vc_cnt == 10'd599) ? 10'd0 : vc_cnt + 1'd1;
    end

    // ---- 3. 两行行缓冲 ----
    reg [7:0] line0 [0:1023];  // 上上一行
    reg [7:0] line1 [0:1023];  // 上一行
    always @(posedge I_clk) begin
        if(I_de) begin
            line0[x_cnt] <= line1[x_cnt];
            line1[x_cnt] <= gray;
        end
    end

    // ---- 4. 3x3 窗口移位 ----
    //  d0: 当前列读入
    //  d1/d2/d3: 移位3拍, 形成 左/中/右
    reg [7:0] d0_r0, d0_r1, d0_r2;
    reg [7:0] d1_r0, d1_r1, d1_r2;
    reg [7:0] d2_r0, d2_r1, d2_r2;
    reg [7:0] d3_r0, d3_r1, d3_r2;

    always @(posedge I_clk) begin
        if(I_de) begin
            d0_r0 <= line0[x_cnt]; d0_r1 <= line1[x_cnt]; d0_r2 <= gray;
            d1_r0 <= d0_r0; d1_r1 <= d0_r1; d1_r2 <= d0_r2;
            d2_r0 <= d1_r0; d2_r1 <= d1_r1; d2_r2 <= d1_r2;
            d3_r0 <= d2_r0; d3_r1 <= d2_r1; d3_r2 <= d2_r2;
        end
    end

    // 3x3 窗口 (行缓冲延迟后):
    //   row0(上上一行): 左=d3_r0  中=d2_r0  右=d1_r0
    //   row1(上一行):   左=d3_r1  中=d2_r1  右=d1_r1
    //   row2(当前行):   左=d3_r2  中=d2_r2  右=d1_r2

    // ---- 5. Sobel卷积 ----
    // Gx: -1 0 1 / -2 0 2 / -1 0 1
    wire signed [11:0] gx = -d3_r0 + d1_r0 - (d3_r1<<1) + (d1_r1<<1) - d3_r2 + d1_r2;
    // Gy: -1 -2 -1 / 0 0 0 / 1 2 1
    wire signed [11:0] gy = -d3_r0 - (d2_r0<<1) - d1_r0 + d3_r2 + (d2_r2<<1) + d1_r2;
    wire [11:0] mag = (gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy);

    // ---- 6. 阈值化 (Sobel+中值滤波, 阈值120平衡边缘和噪点) ----
    localparam [11:0] THRESHOLD = 12'd120;
    wire is_edge_raw = (mag > THRESHOLD);

    // ---- 6b. 3x3边缘膨胀: 左右+上下, 边缘线更粗更清晰 ----
    // 水平膨胀
    reg is_d1, is_d2;
    always @(posedge I_clk) begin
        is_d1 <= is_edge_raw;
        is_d2 <= is_d1;
    end
    // 垂直膨胀: 行缓冲存上一行边缘
    reg is_line [0:1023];
    reg [9:0] x_dly;
    reg is_up;
    always @(posedge I_clk) begin
        if(I_de) begin
            is_line[x_cnt] <= is_edge_raw;
            x_dly <= x_cnt;
            is_up <= is_line[x_dly];
        end
    end
    wire is_edge = is_edge_raw | is_d1 | is_d2 | is_up;

    // ---- 7. 屏蔽白边 (前几列/前几行行缓冲未填满) ----
    reg [9:0] x_d1, x_d2, x_d3, x_d4;
    reg [9:0] vc_d1, vc_d2, vc_d3, vc_d4;
    always @(posedge I_clk) begin
        x_d1 <= x_cnt; x_d2 <= x_d1; x_d3 <= x_d2; x_d4 <= x_d3;
        vc_d1 <= vc_cnt; vc_d2 <= vc_d1; vc_d3 <= vc_d2; vc_d4 <= vc_d3;
    end
    wire left_border  = (x_d4 < 10'd16);   // 前16列屏蔽(MIPI首列垃圾)
    wire top_border   = (vc_d4 < 10'd2);   // 前2行屏蔽

    wire [23:0] edge_rgb = (is_edge && !left_border && !top_border) ? 24'h00FFFF : 24'h000000;

    // ---- 8. de 延迟对齐 (4拍) ----
    reg de_d1, de_d2, de_d3, de_d4;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) {de_d1,de_d2,de_d3,de_d4} <= 4'd0;
        else begin
            de_d1 <= I_de; de_d2 <= de_d1; de_d3 <= de_d2; de_d4 <= de_d3;
        end
    end

    // ---- 9. SW2 选择 ----
    assign O_de  = I_sw2 ? de_d4 : I_de;
    assign O_rgb = I_sw2 ? edge_rgb : I_rgb;

endmodule
