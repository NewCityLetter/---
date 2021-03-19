module Divider #(parameter N=100000)
(
   input  I_CLK,
   output reg O_CLK_1M
);
        integer  i=0;
        always@(posedge I_CLK)
        begin
            if(i==N/2-1) 
            begin
               O_CLK_1M<=~O_CLK_1M;
               i<=0;
            end
            else
               i<=i+1;
        end         
   endmodule 
   
module Adjust_vol(
    input clk,
    input [3:0] hex1,
    input [3:0] hex0,
    input keyup,
    output reg [3:0] vol_class=10,
    output reg [15:0]vol=16'h0000
    );
    wire [15:0]adjusted_vol;
    assign adjusted_vol=vol;
    integer clk_cnt=0;
    always @(posedge clk) 
    begin
        if(clk_cnt==200000) 
        begin
            clk_cnt<=0;
            if(!keyup)
            begin
            case({hex1,hex0})
            8'b01110101:
            begin
                vol<=(vol==16'h0000)?16'h0000:(vol-16'h197f);
            end
            8'b01110010:
            begin
                vol<=(vol==16'hfef6)?16'hfefe:(vol+16'h197f);
            end
            endcase
            end
        end
        else 
            clk_cnt<=clk_cnt+1;
    end
    always @(posedge clk)
    begin
        case(vol)
        16'he577:
        begin
            vol_class<=0;
        end
        16'hcbf8:
        begin
            vol_class<=1;
        end
        16'hb279:
        begin
            vol_class<=2;
        end
        16'h98fa:
        begin
            vol_class<=3;
        end
        16'h7f7b:
        begin
            vol_class<=4;
        end
        16'h65fc:
        begin
            vol_class<=5;
        end
        16'h4c7d:
        begin
            vol_class<=6;
        end
        16'h32fe:
        begin
            vol_class<=7;
        end
        16'h197f:
        begin
            vol_class<=8;
        end
        16'h0000:
        begin
            vol_class<=9;    
        end
        default:
        begin
            vol_class<=0;
        end
        endcase 
    end
endmodule 

module display7(rst,iData,oData);
    input rst;
    input [3:0] iData;
    output reg [6:0] oData;
    always@(*)
        begin
            case({rst,iData})
            5'b10000:oData=7'b1000000;
            5'b10001:oData=7'b1111001;
            5'b10010:oData=7'b0100100;
            5'b10011:oData=7'b0110000;
            5'b10100:oData=7'b0011001;
            5'b10101:oData=7'b0010010;
            5'b10110:oData=7'b0000010;
            5'b10111:oData=7'b1111000;
            5'b11000:oData=7'b0000000;
            5'b11001:oData=7'b0010000;
            default:oData=7'b1111111;
            endcase
        end
endmodule


//ʵ����һ����λ�Ĵ���������22λ���ݣ�
//������λ�Ĵ�����ĳЩλ�������ʮ������ֵ��
//��KB����SDATA���ڶ�ȡ" F0"ʱ����ѡͨ�ź�
module KBDecoder(
    input CLK,//ͬ����usb�ź�
    input SDATA,//ͬ����usb����
    input ARST_L,//�����ź�
    output [3:0] HEX0,//16���Ƽ���
    output [3:0] HEX1,//16���Ƽ���
    output reg KEYUP//�����Ƿ��ȡ��������Ϣ��1Ϊ��ȡ��
    );
    
wire arst_i, rollover_i;
reg [21:0] Shift;

assign arst_i = ~ARST_L;
// ����λ�Ĵ����в�ͣȡֵ
assign HEX0[3:0] = Shift[15:12];
assign HEX1[3:0] = Shift[19:16];

// ����һ����Ҫ22��ͬ�����ʱ�����ڣ�������ſ���11������ϢΪFOXX,XXΪ���¼��ļ��룩
always @(negedge CLK or posedge arst_i) begin;
    if(arst_i)begin
        Shift <= 22'b0000000000000000000000;
    end
    else begin
        Shift <= {SDATA, Shift[21:1]}; //�����һλ����
    end
end

//�ҵ�F0�������ҵ���һ���룬����һ��1��ֵ
always @(posedge CLK) begin
    if(Shift[8:1] == 8'hF0) begin
        KEYUP <= 1'b1;
    end
    else begin
        KEYUP <= 1'b0;
    end    
end    

endmodule

module MP3(
	input CLK,//ϵͳʱ��
	input CLK_1M,
	input DREQ,//��������
	output reg XRSET,//Ӳ����λ
	output reg XCS,//�͵�ƽ��ЧƬѡ���
	output reg XDCS,////����Ƭ�ֽ�ͬ��
	output reg SI,//������������	
	output reg SCLK,//SPIʱ��
	input init,//��ʼ��
	input [3:0] hex1,//16���Ƽ����λ
    input [3:0] hex0,//16���Ƽ����λ
    input [15:0] adjusted_vol,
    input keyup,
    output reg [3:0] tune=0
    
);
    parameter  CMD_START=0;//��ʼдָ��
    parameter  WRITE_CMD=1;//��һ��ָ��ȫ��д��
    parameter  DATA_START=2;//��ʼд����
    parameter  WRITE_DATA=3;//��һ������ȫ��д��
    parameter  DELAY=4;//��ʱ  
    parameter VOL_CMD_START=5;// �������
    parameter SEND_VOL_CMD=6;

	reg [31:0] volcmd;
  
    reg [20:0]addr;
    
    reg  [15:0] Data;
    wire [15:0] D_do;
    wire [15:0] D_re;
    wire [15:0] D_mi;
    wire [15:0] D_fa;
    wire [15:0] D_so;
    wire [15:0] D_la;
    wire [15:0] D_xi;
    wire [15:0] D_hdo;
    wire [15:0] D_hre;
    wire [15:0] D_hmi;
    wire [15:0] music1;
    wire [15:0] music2;
    wire [15:0] music3;
    wire [15:0] music4;
    
    reg [3:0] pretune=0;  
    reg [15:0] _Data;
    blk_mem_gen_1 your_instance_name1(.clka(CLK),.ena(1),.addra(addr),.douta(D_do));
    blk_mem_gen_2 your_instance_name2(.clka(CLK),.ena(1),.addra(addr),.douta(D_re));
    blk_mem_gen_3 your_instance_name3(.clka(CLK),.ena(1),.addra(addr),.douta(D_mi));
    blk_mem_gen_4 your_instance_name4(.clka(CLK),.ena(1),.addra(addr),.douta(D_fa));
    blk_mem_gen_5 your_instance_name5(.clka(CLK),.ena(1),.addra(addr),.douta(D_so));
    blk_mem_gen_6 your_instance_name6(.clka(CLK),.ena(1),.addra(addr),.douta(D_la));
    blk_mem_gen_7 your_instance_name7(.clka(CLK),.ena(1),.addra(addr),.douta(D_xi));
    blk_mem_gen_8 your_instance_name8(.clka(CLK),.ena(1),.addra(addr),.douta(D_hdo));
    blk_mem_gen_9 your_instance_name9(.clka(CLK),.ena(1),.addra(addr),.douta(D_hre));
    blk_mem_gen_10 your_instance_name10(.clka(CLK),.ena(1),.addra(addr),.douta(D_hmi));
    blk_mem_gen_11 your_instance_name11(.clka(CLK),.ena(1),.addra(addr),.douta(music1));//year
    blk_mem_gen_12 your_instance_name12(.clka(CLK),.ena(1),.addra(addr),.douta(music2));//mojito
    blk_mem_gen_13 your_instance_name13(.clka(CLK),.ena(1),.addra(addr),.douta(music3));//north
    blk_mem_gen_14 your_instance_name14(.clka(CLK),.ena(1),.addra(addr),.douta(music4));//balloon
   
    integer tune_delay=0;
	always @(posedge CLK_1M)
	begin
	   if(tune_delay==0) 
	   begin
            if(keyup) 
            begin
               tune_delay<=50000;
               case({hex1,hex0})
               8'b00010110:
               begin
                   tune<=4'b0001;
               end
               8'b00011110:
               begin
                    tune<=4'b0010;
               end
               8'b00100110:
               begin
                    tune<=4'b0011;
               end
               8'b00100101:
               begin
                    tune<=4'b0100;
               end
               8'b00101110:
               begin
                    tune<=4'b0101;
               end
               8'b00110110:
               begin
                    tune<=4'b0110;
               end
               8'b00111101:
               begin
                    tune<=4'b0111;
               end
               8'b00111110:
               begin
                    tune<=4'b1000;
               end
               8'b01000110:
               begin
                    tune<=4'b1001;
               end
               8'b01000101:
               begin
                    tune<=4'b1010;
               end
               8'b01001110:
               begin
                    tune<=4'b1011;
               end
               8'b01010101:
               begin
                    tune<=4'b1100;
               end
               8'b01010100:
               begin
                    tune<=4'b1101;
               end
               8'b01011011:
               begin
                    tune<=4'b1110;
               end
               default:
               begin
                    //tune<=0;
               end
               endcase
             end
       end
       else 
       begin
            tune_delay<=tune_delay-1;
       end
	   
	   
	   case(tune)
	   4'b0001:
	   begin
	       Data<=D_do;
	   end
	   4'b0010:
	   begin
	       Data<=D_re;
	   end
	   4'b0011:
	   begin
	       Data<=D_mi;
	   end
	   4'b0100:
	   begin
	       Data<=D_fa;
	   end
	   4'b0101:
	   begin
	       Data<=D_so;
	   end
	   4'b0110:
	   begin
	       Data<=D_la;
	   end
	   4'b0111:
	   begin
	       Data<=D_xi;
	   end
	   4'b1000:
	   begin
	       Data<=D_hdo;
	   end
	   4'b1001:
	   begin
	       Data<=D_hre;
	   end
	   4'b1010:
	   begin
	       Data<=D_hmi;
	   end
	   4'b1011:
	   begin
	       Data<=music1;
	   end
	   4'b1100:
	   begin
	       Data<=music2;
	   end
	   4'b1101:
	   begin
	       Data<=music3;
	   end
	   4'b1110:
	   begin
	       Data<=music4;
	   end
	   default:
	   begin
	       //Data<=D_none;
	   end
	   endcase
	end
	
	reg [63:0] cmd={32'h02000804,32'h020B0000};//00�ǿ���ģʽ 0B������ 08 ����ģʽ 04 �����λ��ÿ�׸�֮�������λ��
    integer status=CMD_START;
    integer cnt=0;//λ�Ɣ�
    integer cmd_cnt=0;//�������
	
    always @(posedge CLK_1M) 
	begin
	    pretune<=tune;
        if(~init||pretune!=tune||!keyup) 
	    begin
            XCS<=1;
            XDCS<=1;
            XRSET<=0;
            cmd_cnt<=0;
            status<=DELAY;  // �տ���ʱ��delay,�ȴ�DREQ
            SCLK<=0;
            cnt<=0;
            addr<=0;
        end
        
        else if((tune<4'b1011&&addr<10000)||(tune>4'b1010))
	    begin
            case(status)
            CMD_START: // �ȴ���������
		    begin
                SCLK<=0;//ʱ���½������룬�����ض�ȡ
                if(cmd_cnt>=2) // ��ǰ2��Ԥ�����mode ���� ��������Ϻ� ��ʼ��������
					status<=DATA_START;
                else if(DREQ) // DREQ��Ч�J �������� si���Խ���32��bit���ź�
                begin  
                    XCS<=0;//XCS���ͱ�ʾ����ָ��
                    status<=WRITE_CMD;  // ��ʼ����
                    SI<=cmd[63];
                    cmd<={cmd[62:0],cmd[63]}; 
                    cnt<=1;
                end
            end
            WRITE_CMD://д��ָ��
            begin
                if(DREQ) 
                begin
                    if(SCLK) 
                    begin
                        if(cnt>=32)
                        begin
                            XCS<=1;  // ȡ����λ
                            cnt<=0;
                            cmd_cnt<=cmd_cnt+1;
                            status<=CMD_START;  // ��ת������ִ��
                        end
                        else 
                        begin
                            SCLK<=0;
                           SI<=cmd[63]; // ������ʮ��λдָ�дָ��0200����MODE�Ĵ����� 0804��MODE��ʮ��λ ����ֻ���ĵ�11��2λ ������λ��
                           cmd<={cmd[62:0],cmd[63]}; //ѭ������
                           cnt<=cnt+1; 
                        end
                    end
                    SCLK<=~SCLK;
                end
            end
            
            DATA_START://д������
            begin
                if(adjusted_vol[15:0]!=cmd[15:0])  // cmd[47:32] ��洢���ǵ�ǰ���� ��ʼֵΪ0000
                begin//��������
                    cnt<=0;
                    volcmd<={16'h020B,adjusted_vol}; // ������������ 0B�Ĵ���������������  �üĴ����洢���ݱ�ʾ������С
                    status<=VOL_CMD_START;			// ת����������
                end
                else if(DREQ) // �ȴ��������� ֮��ÿ������32ʹ ��DREQ�´α�߽������� vs1003B���Զ����ղ�����
                begin
                    XDCS<=0;
                    SCLK<=0;
                    SI<=Data[15];
                    _Data<={Data[14:0],Data[15]};
                    cnt<=1;    
                    status<=WRITE_DATA;  // �����ź�
                end
                cmd[15:0]<=adjusted_vol; // ����cmd�д洢������
            end
            
            WRITE_DATA:
            begin  
                if(SCLK)
                begin
                    if(cnt>=16)
                    begin
                        XDCS<=1;
                        addr<=addr+1; // ����ʮ��λ���ַ����1λ
                        status<=DATA_START;
                    end
                    else 
                    begin  // ѭ������ ����ʮ��λ
                        SCLK<=0;
                        cnt<=cnt+1;
                        _Data<={_Data[14:0],_Data[15]};
                        SI<=_Data[15];
                    end
                end
                SCLK<=~SCLK;
            end
          
            DELAY:
            begin
                if(cnt<50000)   // �ȴ�100��ʱ���ܖc
                    cnt<=cnt+1;
                else 
                begin
                    cnt<=0;
                    status<=CMD_START;  // ��ʼ��������
                    XRSET<=1;
                end
            end
            
            VOL_CMD_START:
            begin
                if(DREQ) 
                begin  // �ȴ�DREQ�ź�
                    XCS<=0;  // �͵�ƽ��ЧƬѡ���
                    status<=SEND_VOL_CMD;   // ����������������
                    SI<=volcmd[31];
                    volcmd<={volcmd[30:0],volcmd[31]}; 
                    cnt<=1;
                end
            end
            
            SEND_VOL_CMD:
            begin
                if(DREQ) 
                begin
                     if(SCLK) 
                     begin
                        if(cnt<32)//ѭ����ֵ
                        begin
                            SI<=volcmd[31];
                            volcmd<={volcmd[30:0],volcmd[31]}; 
                            cnt<=cnt+1; 
                        end
                        else 
                        begin 
                            XCS<=1; // ��������
                            cnt<=0;
                            status<=DATA_START; // ����֮ǰ�����
                          
                        end
                    end
                    SCLK<=~SCLK;
                end
            end
		default:;
        endcase
    end
end
endmodule

module oled(
	input CLK, 
	input RST,
	input [3: 0] current,
	output reg DIN, // input pin 
	output reg OLED_CLK, 
	output reg CS, // chip select
	output reg DC, // Data & CMD 
	output reg RES
);
	parameter DELAY_TIME = 25000;
	
	// DC parameter
	parameter CMD = 1'b0;
	parameter DATA = 1'b1;
	
	// init cmds
	reg [383:0] cmds;
	initial
		begin
			cmds= {
			8'hAE, 8'hA0, 8'h76, 8'hA1, 8'h00, 8'hA2,
			8'h00, 8'hA4, 8'hA8, 8'h3F, 8'hAD, 8'h8E, 
			8'hB0, 8'h0B, 8'hB1, 8'h31, 8'hB3, 8'hF0,
			8'h8A, 8'h64, 8'h8B, 8'h78, 8'h8C, 8'h64,
			8'hBB, 8'h3A, 8'hBE, 8'h3E, 8'h87, 8'h06,
			8'h81, 8'h91, 8'h82, 8'h50, 8'h83, 8'h7D, 
			8'h15, 8'h00, 8'h5F, 8'h75, 8'h00, 8'h3F, 
			8'haf, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; 
		end
 
	// base map 
	wire [1535:0] map;
	reg [5: 0] addr;
	blk_mem_gen_0 your_instance_name(.clka(CLK),.ena(1),.addra({current, addr}),.douta(map));
	
	// states
	parameter CMD_PRE = 0;
	parameter PRE_WRITE = 1;
	parameter WRITE = 2;
	parameter DATA_PRE = 3;
	
	wire clk_div;
    Divider #(.N(50)) CLKDIV2(CLK, clk_div);
	
	// vars 
	reg [1535:0] temp;
	reg [15: 0] cmd_cnt;
	reg [7: 0] data_reg;
	reg [3: 0] state;
	reg [3: 0] state_pre;
	integer cnt = 0;
	integer write_cnt = 0;
	
	// state machine
	always @ (posedge clk_div) begin 
		if(!RST) begin 
			state <= CMD_PRE;
			cmd_cnt <= 0;
			CS <= 1'b1;
			RES <= 0;
		end
		else begin 
			RES <= 1;
			case(state)
				// prepare for cmd write, put cmds rows into temp 
				CMD_PRE: 
				begin 
						if(cmd_cnt == 1) 
						begin 
							cmd_cnt <= 0;
							addr <= 0;
							state <= DATA_PRE;
						end
						else begin 
							temp <= cmds;
							state <= PRE_WRITE;
							state_pre <= CMD_PRE;
							write_cnt <= 48;
							DC <= CMD;
						end
					end
				// prepare for data write 
				DATA_PRE: 
				begin 
						if(cmd_cnt == 64) 
						begin 
							cmd_cnt <= 0;
							state <= DATA_PRE;
						end
						else 
						begin 
							temp <= map;
							state <= PRE_WRITE;
							state_pre <= DATA_PRE;
							write_cnt <= 192;
							DC <= DATA;
						end
					end
				// cut temp into several 8bits regs
				PRE_WRITE: 
				begin 
						if(write_cnt == 0) 
						begin 
							cmd_cnt <= cmd_cnt+1;
							addr <= addr+1;
							state <= state_pre;
						end
						else 
						begin 
							data_reg[7: 0] <= (state_pre==CMD_PRE)? temp[383: 376]: temp[1535: 1528];
							temp <= (state_pre==CMD_PRE)? {temp[375: 0], temp[383: 376]}: {temp[1527: 0], temp[1535: 1528]};
							state <= WRITE;
							OLED_CLK <= 0;
							cnt <= 0;
						end
					end
				// shift 8bits into DIN port
				WRITE: 
				begin 
						if(OLED_CLK) 
						begin 
							if(cnt == 8) 
							begin 
								CS <= 1;
								write_cnt <= write_cnt-1;
								state <= PRE_WRITE;
							end
							else 
							begin 
								CS <= 0;
								DIN <= data_reg[7];
								cnt <= cnt+1;
								data_reg<={data_reg[6:0], data_reg[7]}; 
							end
						end
						OLED_CLK <= ~OLED_CLK;
					end
				default:;
			endcase
		end
	end 
endmodule


module top(
	input CLK,//ϵͳʱ��
	input DREQ,//��������
	output wire XRSET,//Ӳ����λ
	output wire XCS,//�͵�ƽ��ЧƬѡ���
	output wire XDCS,////����Ƭ�ֽ�ͬ��
	output wire SI,//������������	
	output wire SCLK,//SPIʱ��
	output wire [6:0] oData,
	input init,//��ʼ��
	input usbCLK,//usbʱ�� F4
    input usbDATA,//usb���� B2
	output wire [3:0] hex1,//16���Ƽ����λ
    output wire [3:0] hex0,//16���Ƽ����λ
    
    output wire DIN, // input pin 
    output wire OLED_CLK, 
    output wire CS, // chip select
    output wire DC, // Data & CMD 
    output wire RES
);
    wire  usbclk,usbdata,keyup;//ͬ�����usb�źţ�ͬ�����usb���ݣ��Ƿ��ȡ��������Ϣ��1Ϊ��ȡ����
    wire [15:0] adjusted_vol;
	wire [3:0] vol_class;
	wire [3:0] tune;
	
    KBDecoder keyboard(.CLK(usbCLK), .SDATA(usbDATA), .ARST_L(init), .HEX1(hex1), .HEX0(hex0), .KEYUP(keyup));
    Divider #(.N(100)) CLKDIV1(CLK,CLK_1M);
	Adjust_vol adjvol(.clk(CLK_1M), .hex1(hex1), .hex0(hex0), .keyup(keyup),.vol_class(vol_class),.vol(adjusted_vol));  //output
    oled OLED(.CLK(CLK),.RST(init),.current(tune),.DIN(DIN),.OLED_CLK(OLED_CLK),.CS(CS),.DC(DC),.RES(RES));
	display7 Display7(.rst(init),.iData(vol_class),.oData(oData));
	MP3 mp3(.CLK(CLK),.CLK_1M(CLK_1M),.DREQ(DREQ),.XRSET(XRSET),.XCS(XCS),.XDCS(XDCS),.SI(SI),.SCLK(SCLK),.init(init),.hex1(hex1),.hex0(hex0),.adjusted_vol(adjusted_vol),.keyup(keyup),.tune(tune));
endmodule