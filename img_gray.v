//  img_gray.v  ——  RGB888 -> 灰度/彩色，带开关与灰度变换增强
//  I_sw1 = 1 : 灰度(黑白+灰度变换增强)
//  I_sw1 = 0 : 彩色(自然还原)
//  纯组合逻辑，0 拍延迟
module img_gray(
    input  wire        I_sw1,    // 1=灰度, 0=彩色
    input  wire [23:0] I_rgb,    // {R[7:0], G[7:0], B[7:0]}
    output wire [23:0] O_rgb
);

    wire [7:0]  r = I_rgb[23:16];
    wire [7:0]  g = I_rgb[15:8];
    wire [7:0]  b = I_rgb[7:0];

    // ---- RGB转灰度 (标准加权) ----
    wire [15:0] y  = (r*77 + g*150 + b*29) >> 8;

    // ---- 灰度变换增强 ----
    // 通过预计算的灰度映射表, 适度扩展中间灰度范围
    // 暗部微提, 中间扩展对比度, 亮部保留
    function [7:0] gray_enh;
        input [7:0] v;
        begin
            case(v)
                 0:gray_enh=  6;   8:gray_enh= 14;  16:gray_enh= 22;
                24:gray_enh= 30;  32:gray_enh= 38;  40:gray_enh= 46;
                48:gray_enh= 54;  56:gray_enh= 62;  64:gray_enh= 70;
                72:gray_enh= 78;  80:gray_enh= 86;  88:gray_enh= 94;
                96:gray_enh=102; 104:gray_enh=110; 112:gray_enh=118;
               120:gray_enh=126; 128:gray_enh=134;
               default:gray_enh = v;
            endcase
        end
    endfunction

    wire [7:0] y_out = gray_enh(y[7:0]);
    wire [23:0] gray = {y_out, y_out, y_out};

    // ---- 彩色模式: 直通(自然还原) ----
    wire [23:0] color = I_rgb;

    assign O_rgb = I_sw1 ? gray : color;

endmodule
