//  img_target.v  ——  红色检测画框 + 模式文字(Logo右边)
module img_target(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_sw1,
    input  wire        I_sw2,
    input  wire        I_de,
    input  wire [23:0] I_rgb,
    output wire [23:0] O_rgb
);

    wire [7:0] r = I_rgb[23:16];
    wire [7:0] g = I_rgb[15:8];
    wire [7:0] b = I_rgb[7:0];

    // ---- 坐标 ----
    reg [9:0] x_cnt;
    reg [9:0] y_cnt;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            x_cnt <= 0; y_cnt <= 0;
        end else if(I_de) begin
            if(x_cnt == 10'd1023) begin
                x_cnt <= 0;
                y_cnt <= (y_cnt == 10'd599) ? 10'd0 : y_cnt + 1'd1;
            end
            else x_cnt <= x_cnt + 1'd1;
        end
    end

    // 红色检测: R明显大于G/B, 且G/B不过高 (排除亮白背景)
    wire is_red = (x_cnt >= 10'd4) && (r > 8'd110) && (r > g + 8'd30) && (r > b + 8'd25) && (g < 8'd140) && (b < 8'd140);

    reg [9:0] min_x, max_x, min_y, max_y;
    reg [9:0] bx_min, bx_max, by_min, by_max;
    reg       box_valid;
    wire frame_end = I_de && (y_cnt == 10'd599) && (x_cnt == 10'd1023);

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            min_x <= 10'd1023; max_x <= 0;
            min_y <= 10'd599; max_y <= 0;
            bx_min <= 0; bx_max <= 0; by_min <= 0; by_max <= 0;
            box_valid <= 0;
        end else if(frame_end) begin
            bx_min <= min_x; bx_max <= max_x;
            by_min <= min_y; by_max <= max_y;
            box_valid <= ((max_x - min_x) > 10'd30) && ((max_y - min_y) > 10'd30);
            min_x <= 10'd1023; max_x <= 0;
            min_y <= 10'd599; max_y <= 0;
        end else if(I_de && is_red) begin
            if(x_cnt < min_x) min_x <= x_cnt;
            if(x_cnt > max_x) max_x <= x_cnt;
            if(y_cnt < min_y) min_y <= y_cnt;
            if(y_cnt > max_y) max_y <= y_cnt;
        end
    end

    wire color_mode = !I_sw1 && !I_sw2;
    wire on_left   = box_valid && color_mode && (x_cnt >= bx_min) && (x_cnt <= bx_min+2) && (y_cnt >= by_min) && (y_cnt <= by_max);
    wire on_right  = box_valid && color_mode && (x_cnt <= bx_max) && (x_cnt >= bx_max-2) && (y_cnt >= by_min) && (y_cnt <= by_max);
    wire on_top    = box_valid && color_mode && (y_cnt >= by_min) && (y_cnt <= by_min+2) && (x_cnt >= bx_min) && (x_cnt <= bx_max);
    wire on_bottom = box_valid && color_mode && (y_cnt <= by_max) && (y_cnt >= by_max-2) && (x_cnt >= bx_min) && (x_cnt <= bx_max);
    wire on_box = on_left || on_right || on_top || on_bottom;

    // 模式文字 (Logo右边 x=170, y=5, 5x7点阵)
    // 4个字符: COLOR / GRAY / EDGE
    function [4:0] glyph;
        input [7:0] ch;
        input [2:0] row;
        begin
            case(ch)
                8'h43: case(row) 3'd0:glyph=5'b01110;3'd1:glyph=5'b10001;3'd2:glyph=5'b10000;3'd3:glyph=5'b10000;3'd4:glyph=5'b10000;3'd5:glyph=5'b10001;3'd6:glyph=5'b01110;default:glyph=5'b00000;endcase
                8'h4F: case(row) 3'd0:glyph=5'b01110;3'd1:glyph=5'b10001;3'd2:glyph=5'b10001;3'd3:glyph=5'b10001;3'd4:glyph=5'b10001;3'd5:glyph=5'b10001;3'd6:glyph=5'b01110;default:glyph=5'b00000;endcase
                8'h4C: case(row) 3'd0:glyph=5'b10000;3'd1:glyph=5'b10000;3'd2:glyph=5'b10000;3'd3:glyph=5'b10000;3'd4:glyph=5'b10000;3'd5:glyph=5'b10000;3'd6:glyph=5'b11111;default:glyph=5'b00000;endcase
                8'h52: case(row) 3'd0:glyph=5'b11110;3'd1:glyph=5'b10001;3'd2:glyph=5'b10001;3'd3:glyph=5'b11110;3'd4:glyph=5'b10010;3'd5:glyph=5'b10001;3'd6:glyph=5'b10001;default:glyph=5'b00000;endcase
                8'h47: case(row) 3'd0:glyph=5'b01110;3'd1:glyph=5'b10001;3'd2:glyph=5'b10000;3'd3:glyph=5'b10011;3'd4:glyph=5'b10001;3'd5:glyph=5'b10001;3'd6:glyph=5'b01110;default:glyph=5'b00000;endcase
                8'h41: case(row) 3'd0:glyph=5'b01110;3'd1:glyph=5'b10001;3'd2:glyph=5'b10001;3'd3:glyph=5'b11111;3'd4:glyph=5'b10001;3'd5:glyph=5'b10001;3'd6:glyph=5'b10001;default:glyph=5'b00000;endcase
                8'h59: case(row) 3'd0:glyph=5'b10001;3'd1:glyph=5'b10001;3'd2:glyph=5'b01010;3'd3:glyph=5'b00100;3'd4:glyph=5'b00100;3'd5:glyph=5'b00100;3'd6:glyph=5'b00100;default:glyph=5'b00000;endcase
                8'h45: case(row) 3'd0:glyph=5'b11111;3'd1:glyph=5'b10000;3'd2:glyph=5'b10000;3'd3:glyph=5'b11110;3'd4:glyph=5'b10000;3'd5:glyph=5'b10000;3'd6:glyph=5'b11111;default:glyph=5'b00000;endcase
                8'h44: case(row) 3'd0:glyph=5'b11110;3'd1:glyph=5'b10001;3'd2:glyph=5'b10001;3'd3:glyph=5'b10001;3'd4:glyph=5'b10001;3'd5:glyph=5'b10001;3'd6:glyph=5'b11110;default:glyph=5'b00000;endcase
                default: glyph = 5'b00000;
            endcase
        end
    endfunction

    // 4个字符位置: 每字符 6像素宽, 间隔2像素
    // char0: x=170~175, char1: x=177~182, char2: x=184~189, char3: x=191~196
    wire [2:0] t_row = y_cnt - 3'd5;  // y=5~11
    wire on_y = (y_cnt >= 5) && (y_cnt <= 11);

    reg [7:0] c0, c1, c2, c3;
    always @(*) begin
        if(I_sw2)      begin c0=8'h45; c1=8'h44; c2=8'h47; c3=8'h45; end // EDGE
        else if(I_sw1) begin c0=8'h47; c1=8'h52; c2=8'h41; c3=8'h59; end // GRAY
        else           begin c0=8'h43; c1=8'h4F; c2=8'h4C; c3=8'h52; end // COLOR
    end

    wire [4:0] g0 = glyph(c0, t_row);
    wire [4:0] g1 = glyph(c1, t_row);
    wire [4:0] g2 = glyph(c2, t_row);
    wire [4:0] g3 = glyph(c3, t_row);

    wire on_c0 = on_y && (x_cnt >= 850) && (x_cnt < 856) && g0[4-(x_cnt-850)];
    wire on_c1 = on_y && (x_cnt >= 857) && (x_cnt < 863) && g1[4-(x_cnt-857)];
    wire on_c2 = on_y && (x_cnt >= 864) && (x_cnt < 870) && g2[4-(x_cnt-864)];
    wire on_c3 = on_y && (x_cnt >= 871) && (x_cnt < 877) && g3[4-(x_cnt-871)];
    wire on_text = on_c0 || on_c1 || on_c2 || on_c3;

    assign O_rgb = on_box  ? 24'h00FF00 :
                   on_text ? 24'hFFFFFF :
                   I_rgb;

endmodule
