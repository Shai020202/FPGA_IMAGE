//  img_median.v  ——  3x3窗口中值滤波 (去噪)
//  对RGB三通道分别取中值, 保留边缘的同时平滑噪点
module img_median(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_de,
    input  wire [23:0] I_rgb,
    output wire        O_de,
    output wire [23:0] O_rgb
);

    // ---- 坐标 ----
    reg [9:0] x_cnt;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) x_cnt <= 0;
        else if(I_de) x_cnt <= (x_cnt == 10'd1023) ? 10'd0 : x_cnt + 1'd1;
    end

    // ---- 行缓冲 (2行) ----
    reg [23:0] line0 [0:1023];
    reg [23:0] line1 [0:1023];
    always @(posedge I_clk) begin
        if(I_de) begin
            line0[x_cnt] <= I_rgb;
            line1[x_cnt] <= line0[x_cnt];
        end
    end

    // ---- 3x3窗口数据 (延迟对齐) ----
    // 行0: 当前行
    reg [23:0] p00, p01, p02;
    // 行1: 上一行
    reg [23:0] p10, p11, p12;
    // 行2: 上上行
    reg [23:0] p20, p21, p22;

    always @(posedge I_clk) begin
        if(I_de) begin
            // 当前行
            p02 <= I_rgb;
            p01 <= p02;
            p00 <= p01;
            // 上一行
            p12 <= line0[x_cnt];
            p11 <= p12;
            p10 <= p11;
            // 上上行
            p22 <= line1[x_cnt];
            p21 <= p22;
            p20 <= p21;
        end
    end

    // ---- 8位排序网络: 9个数取中值 ----
    // 经典实现: 每行排序取中间 -> 列向再排序
    function [7:0] sort3_mid;
        input [7:0] a, b, c;
        reg [7:0] mn, md, mx;
        begin
            mn = a; mx = a;
            if(b < mn) mn = b; if(b > mx) mx = b;
            if(c < mn) mn = c; if(c > mx) mx = c;
            md = a + b + c - mn - mx;
            sort3_mid = md;
        end
    endfunction

    function [7:0] median9;
        input [7:0] a00, a01, a02, a10, a11, a12, a20, a21, a22;
        reg [7:0] m0, m1, m2;
        reg [7:0] mn, mx, md;
        begin
            // 每行取中间
            m0 = sort3_mid(a00, a01, a02);
            m1 = sort3_mid(a10, a11, a12);
            m2 = sort3_mid(a20, a21, a22);
            // 三个中间值再取中间 = 9个数的中值
            mn = m0; mx = m0;
            if(m1 < mn) mn = m1; if(m1 > mx) mx = m1;
            if(m2 < mn) mn = m2; if(m2 > mx) mx = m2;
            md = m0 + m1 + m2 - mn - mx;
            median9 = md;
        end
    endfunction

    // 对R/G/B分别取中值
    wire [7:0] med_r = median9(
        p00[23:16], p01[23:16], p02[23:16],
        p10[23:16], p11[23:16], p12[23:16],
        p20[23:16], p21[23:16], p22[23:16]
    );
    wire [7:0] med_g = median9(
        p00[15:8], p01[15:8], p02[15:8],
        p10[15:8], p11[15:8], p12[15:8],
        p20[15:8], p21[15:8], p22[15:8]
    );
    wire [7:0] med_b = median9(
        p00[7:0], p01[7:0], p02[7:0],
        p10[7:0], p11[7:0], p12[7:0],
        p20[7:0], p21[7:0], p22[7:0]
    );

    // ---- de延迟对齐 (3拍) ----
    reg de_d1, de_d2, de_d3;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) {de_d1, de_d2, de_d3} <= 3'd0;
        else {de_d1, de_d2, de_d3} <= {I_de, de_d1, de_d2};
    end

    assign O_de  = de_d3;
    assign O_rgb = {med_r, med_g, med_b};

endmodule
