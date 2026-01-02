module reaction_game(
    input  wire clk,
    input  wire start_btn,
    input  wire resp_btn,
    input  wire reset_btn,

    output reg  [7:0] leds,
    output reg  [6:0] seg,
    output reg        dp,
    output reg  [7:0] an,
    output wire       piezo,

    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_e,
    output reg [7:0] lcd_data,

    // RGB LED (F_LED1)
    output reg fc_r,
    output reg fc_g,
    output reg fc_b
);

parameter CLOCK_FREQ=50000000;
parameter MS_TICKS=CLOCK_FREQ/1000;

reg [31:0] clk_cnt=0;
reg ms_tick=0;
always@(posedge clk)begin
    if(clk_cnt>=MS_TICKS-1)begin clk_cnt<=0;ms_tick<=1;end
    else begin clk_cnt<=clk_cnt+1;ms_tick<=0;end
end

parameter S_IDLE=0,S_WAIT=1,S_SIGNAL=2,S_CAPTURE=3,S_RESULT=4,S_FALSE=5;
reg [2:0] state=S_IDLE,next_state=S_IDLE,prev_state=S_IDLE;

reg [15:0] lfsr=16'hACE1;
always@(posedge clk)begin
    if(state==S_IDLE) lfsr<=16'hACE1;
    else lfsr<={lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
end

parameter MIN_WAIT=500,MAX_WAIT=2000;
wire [31:0] wait_rng=MAX_WAIT-MIN_WAIT+1;

reg [31:0] wait_ms=0,wait_tgt=0,ms_counter=0,false_ms=0;
reg [3:0] wait_step=0;
reg was_signal=0;

reg intro_play=0;reg [31:0] intro_ms=0;
reg play_good=0,play_bad=0;
reg [15:0] melody_ms=0;reg [3:0] melody_step=0;

always@(*)begin
    next_state=state;
    case(state)
        S_IDLE:   if(start_btn) next_state=S_WAIT;
        S_WAIT:   if(resp_btn) next_state=S_FALSE; else if(wait_ms>=wait_tgt) next_state=S_SIGNAL;
        S_SIGNAL: if(resp_btn) next_state=S_CAPTURE;
        S_CAPTURE:next_state=S_RESULT;
        S_RESULT: if(start_btn) next_state=S_IDLE;
        S_FALSE:  if(false_ms>=2000) next_state=S_IDLE;
    endcase
end

always@(posedge clk)begin
    if(reset_btn)begin state<=S_IDLE;prev_state<=S_IDLE;end
    else begin prev_state<=state;state<=next_state;end
    was_signal<=(state==S_SIGNAL);

    case(state)
    S_IDLE:begin
        ms_counter<=0;wait_ms<=0;false_ms<=0;wait_step<=0;
        wait_tgt<=MIN_WAIT+(lfsr%wait_rng);
        intro_play<=0;intro_ms<=0;play_good<=0;play_bad<=0;
    end
    S_WAIT:begin
        if(!intro_play)begin intro_play<=1;intro_ms<=0;end
        if(ms_tick)begin intro_ms<=intro_ms+1;wait_ms<=wait_ms+1;if(wait_ms%10==0)wait_step<=wait_step+1;end
        play_good<=0;play_bad<=0;
    end
    S_SIGNAL:begin
        intro_play<=0;
        if(!was_signal)ms_counter<=0;
        else if(ms_tick)ms_counter<=ms_counter+1;
    end
    S_CAPTURE:intro_play<=0;
    S_RESULT:begin
        intro_play<=0;
        if(prev_state!=S_RESULT)begin
            if(ms_counter<1000)begin play_good<=1;play_bad<=0;end
            else begin play_good<=0;play_bad<=1;end
        end else begin
            if(melody_step>=7)begin play_good<=0;play_bad<=0;end
        end
    end
    S_FALSE:begin
        intro_play<=0;if(ms_tick)false_ms<=false_ms+1;ms_counter<=0;play_good<=0;play_bad<=0;
    end
    endcase
end

always@(*)begin
    case(state)
        S_IDLE:leds=8'b00000001;
        S_WAIT:leds=(8'b1<<wait_step[1:0]);
        S_SIGNAL, S_CAPTURE:leds=8'hFF;
        S_RESULT:leds=(ms_counter<=1000)?8'h0F:8'hF0;
        S_FALSE:leds=(false_ms%200<100)?8'hFF:8'h00;
        default:leds=8'b1;
    endcase
end

localparam T1=25000,T2=16666,T3=12500,FT=25000;

// HAPPY YAY
localparam Y0=9500,Y1=7100,Y2=6400,Y3=4800,Y4=6400,Y5=7100,Y6=9500;
// SAD TROMBONE
localparam W0=13000,W1=15000,W2=19000,W3=22500,W4=26000,W5=30000,W6=34000;

reg [15:0] p_cnt=0;reg p_out=0;reg [31:0] tone=0;

always@(posedge clk)begin
    if(reset_btn)begin melody_ms<=0;melody_step<=0;end
    else if(play_good||play_bad)begin
        if(ms_tick)begin
            if(melody_step<12)begin
                if(melody_ms>=180)begin melody_ms<=0;melody_step<=melody_step+1;end
                else melody_ms<=melody_ms+1;
            end
        end
    end else begin melody_ms<=0;melody_step<=0;end
end

always@(posedge clk)begin
    if(state==S_FALSE)begin
        if(p_cnt>=FT)begin p_cnt<=0;p_out<=~p_out;end else p_cnt<=p_cnt+1;
    end
    else if(intro_play)begin
        if(intro_ms<120)tone=T1;else if(intro_ms<240)tone=T2;else if(intro_ms<360)tone=T3;
        else tone=32'hFFFFFFFF;
        if(tone==32'hFFFFFFFF)begin p_cnt<=0;p_out<=0;end
        else if(p_cnt>=tone)begin p_cnt<=0;p_out<=~p_out;end else p_cnt<=p_cnt+1;
    end
    else if(play_good)begin
        case(melody_step)
            0:tone=Y0;1:tone=Y1;2:tone=Y2;3:tone=Y3;4:tone=Y4;5:tone=Y5;6:tone=Y6;
            default:tone=32'hFFFFFFFF;
        endcase
        if(tone==32'hFFFFFFFF)begin p_cnt<=0;p_out<=0;end
        else if(p_cnt>=tone)begin p_cnt<=0;p_out<=~p_out;end else p_cnt<=p_cnt+1;
    end
    else if(play_bad)begin
        case(melody_step)
            0:tone=W0;1:tone=W1;2:tone=W2;3:tone=W3;4:tone=W4;5:tone=W5;6:tone=W6;
            default:tone=32'hFFFFFFFF;
        endcase
        if(tone==32'hFFFFFFFF)begin p_cnt<=0;p_out<=0;end
        else if(p_cnt>=tone)begin p_cnt<=0;p_out<=~p_out;end else p_cnt<=p_cnt+1;
    end
    else begin p_cnt<=0;p_out<=0;end
end

assign piezo=p_out;

reg [15:0] scan_div=0;reg[2:0] digit_sel=0;reg[3:0] digit=0;
always@(posedge clk)begin scan_div<=scan_div+1;digit_sel<=scan_div[15:13];end

wire [13:0] sec=ms_counter/1000;
wire [13:0] ms10=(ms_counter%1000)/10;

wire [3:0] s_t=(sec/10)%10,s_o=sec%10,mt=(ms10/10)%10,mo=ms10%10;

always@(*)begin
    an=8'hFF;
    case(digit_sel)
        0:begin an[0]=0;digit=s_t;end
        1:begin an[1]=0;digit=s_o;end
        2:begin an[2]=0;digit=mt;end
        3:begin an[3]=0;digit=mo;end
        default:digit=4'hF;
    endcase
end

function [6:0] map(input[3:0]v);case(v)
0:map=7'b0111111;
1:map=7'b0000110;
2:map=7'b1011011;
3:map=7'b1001111;
4:map=7'b1100110;
5:map=7'b1101101;
6:map=7'b1111101;
7:map=7'b0000111;
8:map=7'b1111111;
9:map=7'b1101111;
default:map=7'b0000000;
endcase endfunction
always@(*)begin seg=map(digit);
dp=(digit_sel==1);end

//-------------------------------------------------------------
// TEXT LCD - 1 LINE ONLY VERSION
//-------------------------------------------------------------

// ---------- Line 1 Message (6 chars) ----------
function [47:0] msg1(input [2:0] s, input fast);
    case (s)
        S_IDLE:     msg1 = {"START "};
        S_WAIT:     msg1 = {"WAIT  "};
        S_SIGNAL:   msg1 = {"GO!!  "};
        S_RESULT:   msg1 = (fast ? {"GOOD!!"} : {"AGAIN "});
        S_FALSE:    msg1 = {"FALSE "};
        default:    msg1 = {"------"};
    endcase
endfunction

// ---------- Pick 1 char from 6-char message ----------
function [7:0] pick6(input [47:0] m, input integer i);
    case (i)
        1: pick6 = m[47:40];
        2: pick6 = m[39:32];
        3: pick6 = m[31:24];
        4: pick6 = m[23:16];
        5: pick6 = m[15:8];
        6: pick6 = m[7:0];
        default: pick6 = 8'h20;
    endcase
endfunction

//-------------------------------------------------------------
// Message update
//-------------------------------------------------------------
reg [47:0] line1;

always @(*) begin
    line1 = msg1(state, (ms_counter < 1000));
end

//-------------------------------------------------------------
// LCD ENGINE (1 LINE ONLY)
//-------------------------------------------------------------
reg [7:0] lcd_idx = 0;
reg [1:0] lcd_phase = 0;
reg [7:0] lcd_wait = 0;
reg [2:0] lcd_prev_state = 7;

// RW fixed to write mode
always @(posedge clk) begin
    lcd_rw <= 0;

    // detect state change ? refresh LCD
    if (state != lcd_prev_state) begin
        lcd_prev_state <= state;
        lcd_idx <= 0;
        lcd_phase <= 0;
        lcd_wait <= 0;
    end else begin
        case (lcd_phase)

        //-------------------------------------------------
        // Phase 0: prepare RS & DATA
        //-------------------------------------------------
        0: begin
            if (lcd_idx == 0) begin
                // Always write to line 1 DDRAM
                lcd_rs   <= 0;
                lcd_data <= 8'h80; // Set cursor to line 1 start
            end
            else begin
                lcd_rs   <= 1;     // data write
                lcd_data <= pick6(line1, lcd_idx);
            end

            lcd_e <= 0;
            lcd_phase <= 1;
        end

        //-------------------------------------------------
        // Phase 1: E high
        //-------------------------------------------------
        1: begin
            lcd_e <= 1;
            lcd_phase <= 2;
        end

        //-------------------------------------------------
        // Phase 2: E low ? delay start
        //-------------------------------------------------
        2: begin
            lcd_e <= 0;
            lcd_wait <= 0;
            lcd_phase <= 3;
        end

        //-------------------------------------------------
        // Phase 3: wait ~2ms then next character
        //-------------------------------------------------
        3: begin
            if (ms_tick) begin
                lcd_wait <= lcd_wait + 1;

                if (lcd_wait >= 2) begin
                    lcd_wait <= 0;
                    lcd_idx <= lcd_idx + 1;

                    // Only 1 command + 6 characters ? idx = 0 ~ 6
                    if (lcd_idx >= 6)
                        lcd_idx <= 6; // stop when done
                    else
                        lcd_phase <= 0;
                end
            end
        end

        endcase
    end
end




endmodule
