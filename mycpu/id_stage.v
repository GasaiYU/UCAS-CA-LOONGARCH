`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //add block codes
    input  [`ES_TO_ID_BYQ_WD -1:0] es_to_id_byp_block,
    input  [`MS_TO_ID_BYQ_WD -1:0] ms_to_id_byp_block,
    input  [`WS_TO_ID_BYQ_WD -1:0] wb_to_id_byp_block,
    //Int
    input  [0                  :0] has_int,
    //input  [0                  :0] es_inst_csrrd,
    //input  [0                  :0] es_inst_csrwr,
    //input  [0                  :0] es_inst_csrxchg, 
    //input  [0                  :0] ms_inst_csrrd,
    //input  [0                  :0] ms_inst_csrwr,
    //input  [0                  :0] ms_inst_csrxchg, 
    //input  [0                  :0] ws_inst_csrrd, 
    //input  [0                  :0] ws_inst_csrwr,
    //input  [0                  :0] ws_inst_csrxchg, 
    input  [0                  :0] ws_ertn,
    input  [0                  :0] ws_ex,
    //input  [0                  :0] es_inst_rdcntid,
    //input  [0                  :0] ms_inst_rdcntid,
    //input  [0                  :0] ws_inst_rdcntid
    input  [3                  :0] es_to_ds_csr_inst,
    input  [3                  :0] ms_to_ds_csr_inst,
    input  [3                  :0] ws_to_ds_csr_inst,
    output [13                 :0] ds_csr_num  
);
reg         ds_valid   ;
wire        ds_ready_go;

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire [ 0:0] has_adef;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {has_adef,
        ds_inst,
        ds_pc
        } = fs_to_ds_bus_r;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire        br_stall;
wire [31:0] br_target;

wire [18:0] alu_op;
wire [ 4:0] load_op;
wire [ 2:0] store_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [ 4:0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] ds_imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;
wire [31:0] adder_result;
wire        adder_cout;
wire        rj_ls_rd;
wire        rju_ls_rdu;
wire        rjo;     //only need rd register
wire        rjark;   //both need rd and rk register
wire        rj_not0;
wire        rkd_not0;
wire        es_not0;
wire        ms_not0;
wire        ws_not0;
wire        rj_eq;
wire        rkd_eq;
wire        rj_exe_byp;
wire        rk_exe_byp;
wire        rj_mem_byp;
wire        rk_mem_byp;
wire        rj_wb_byp; 
wire        rk_wb_byp;
wire        inst_b_type;

wire        ds_ex;
wire [ 5:0] ds_ecode;
wire [ 8:0] ds_esubcode;
wire        csrr_block;
wire        has_ale;
wire        has_ine;
wire        es_not_ready_fwd;
wire [ 4:0] es_to_ds_dest;
wire [ 4:0] ms_to_ds_dest;
wire [ 4:0] wb_to_id_dest;
wire        es_wen;
wire        ms_wen;
wire        wb_wen;
wire [31:0] es_to_ds_res;
wire [31:0] ms_to_ds_res;
wire [31:0] wb_to_id_res;
wire        ms_blk;
wire [ 2:0] counter_op;
wire  es_inst_csrrd;
wire  es_inst_csrwr;
wire  es_inst_csrxchg;
wire  es_inst_rdcntid;
wire  ms_inst_csrrd;
wire  ms_inst_csrwr;
wire  ms_inst_csrxchg;
wire  ms_inst_rdcntid;
wire  ws_inst_csrrd;
wire  ws_inst_csrwr;
wire  ws_inst_csrxchg;
wire  ws_inst_rdcntid;

wire [ 4:0] tlb_op;
wire [ 4:0] invtlb_op;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
  
wire        inst_add_w; 
wire        inst_sub_w;  
wire        inst_slt;    
wire        inst_sltu;   
wire        inst_nor;    
wire        inst_and;    
wire        inst_or;     
wire        inst_xor;    
wire        inst_slli_w;  
wire        inst_srli_w;  
wire        inst_srai_w;  
wire        inst_addi_w; 
wire        inst_ld_w;  
wire        inst_st_w;   
wire        inst_jirl;   
wire        inst_b;      
wire        inst_bl;     
wire        inst_beq;    
wire        inst_bne;    
wire        inst_lu12i_w;
//Lab 6 add code
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
//lab 6 div_inst
wire        inst_div_w;
wire        inst_mod_w;
wire        inst_div_wu;
wire        inst_mod_wu;
//Lab 7 add inst
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;
//Lab 8 add inst
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;
//lab 9 add
wire        inst_break;
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid;
//lab 14 add tlb inst
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;
//Lab 6 add code end
wire        need_ui5;
wire        need_ui12;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;  
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rj_eq_rd;
wire [2:0]  fs_tlb_ex;


assign br_bus = {fs_tlb_ex,
                 br_taken,
                 br_stall,
                 br_target
                 };
//The bus add some new signals
//Lab 8 add code, we need to pass the inst_csrrX 
//because we need them to judge what we should do in wb
assign ds_to_es_bus = {fs_tlb_ex   ,  //234:232
                       invtlb_op   ,  //231:227
                       tlb_op      ,  //226:222
                       counter_op  ,  //221:219
                       ds_esubcode ,  //218:210
                       ds_ecode    ,  //209:204
                       inst_syscall,  //203:203
                       has_int   ,    //202:202
                       ds_ex     ,    //201:201
                       inst_ertn ,    //200:200
                       ds_inst   ,    //199:168
                       inst_csrrd,    //167:167
                       inst_csrwr,    //166:166
                       inst_csrxchg,  //165:165
                       alu_op      ,  //164:146
                       res_from_mem,  //145:145
                       store_op    ,  //144:142
                       load_op     ,  //141:137
                       src1_is_pc  ,  //136:136
                       src2_is_imm ,  //135:135
                       gr_we       ,  //134:134
                       mem_we      ,  //133:133
                       dest        ,  //132:128
                       ds_imm      ,  //127:96
                       rj_value    ,  //95 :64
                       rkd_value   ,  //63 :32
                       ds_pc          //31 :0
                      };
assign {es_inst_csrrd,
        es_inst_csrwr,
        es_inst_csrxchg,
        es_inst_rdcntid} = es_to_ds_csr_inst;
assign {ms_inst_csrrd,
        ms_inst_csrwr,
        ms_inst_csrxchg,
        ms_inst_rdcntid} = ms_to_ds_csr_inst;
assign {ws_inst_csrrd,
        ws_inst_csrwr,
        ws_inst_csrxchg,
        ws_inst_rdcntid} = ws_to_ds_csr_inst;
//assign ds_ready_go    = 1'b1;
assign ds_allowin     = !ds_valid | ds_ready_go & es_allowin;
assign ds_to_es_valid = ds_valid & ds_ready_go & ~ws_ertn & ~ws_ex;
always @(posedge clk) begin 
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end 

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w    = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w    = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w    = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w    = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w      = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w      = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl      = op_31_26_d[6'h13];
assign inst_b         = op_31_26_d[6'h14];
assign inst_bl        = op_31_26_d[6'h15];
assign inst_beq       = op_31_26_d[6'h16];
assign inst_bne       = op_31_26_d[6'h17];
assign inst_lu12i_w   = op_31_26_d[6'h05] & ~ds_inst[25];
//Lab 6 add code
assign inst_slti      = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui     = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi      = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori       = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori      = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ds_inst[25];
assign inst_mul_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
//lab 6 div_inst
assign inst_div_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
//lab 7 add code
//B-Type inst
assign inst_blt       = op_31_26_d[6'h18];
assign inst_bge       = op_31_26_d[6'h19];
assign inst_bltu      = op_31_26_d[6'h1a];
assign inst_bgeu      = op_31_26_d[6'h1b];
//L-Type inst
assign inst_ld_b      = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h      = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu     = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu     = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b      = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h      = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
//Lab 8 add code
assign inst_csrrd      = op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & (ds_inst[9:5] == 5'b0);
assign inst_csrwr      = op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & (ds_inst[9:5] == 5'b1);
assign inst_csrxchg    = op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & (ds_inst[9:5] != 5'b1) & (ds_inst[9:5] != 5'b0);
assign inst_ertn       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[9:0] == 10'b0) & (ds_inst[14:10] == 5'b01110);
assign inst_syscall    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
//Lab 9 add code
assign inst_break      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntvl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (ds_inst[14:10] == 5'b11000) & (ds_inst[9:5] == 5'b00000);
assign inst_rdcntvh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (ds_inst[14:10] == 5'b11001) & (ds_inst[9:5] == 5'b00000);
assign inst_rdcntid    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (ds_inst[14:10] == 5'b11000) & (ds_inst[4:0] == 5'b00000);
//Lab 6 change code
assign inst_tlbsrch    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[14:10] == 5'b01010);
assign inst_tlbrd      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[14:10] == 5'b01011);
assign inst_tlbwr      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[14:10] == 5'b01100);
assign inst_tlbfill    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (ds_inst[14:10] == 5'b01101);
assign inst_invtlb     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

assign alu_op[ 0] = inst_add_w  | inst_addi_w | inst_ld_w       | inst_st_w |
                    inst_jirl   | inst_bl     | inst_pcaddu12i | (|load_op) | (|store_op);  //Lab 6 change code
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt    | inst_slti;   //Lab 6 change
assign alu_op[ 3] = inst_sltu   | inst_sltui;  //Lab 6 change
assign alu_op[ 4] = inst_and    | inst_andi;   //Lab 6 change
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or     | inst_ori;    //Lab 6 change
assign alu_op[ 7] = inst_xor    | inst_xori;   //Lab 6 change
assign alu_op[ 8] = inst_slli_w | inst_sll_w;//Lab 6 change
assign alu_op[ 9] = inst_srli_w | inst_srl_w;//Lab 6 change
assign alu_op[10] = inst_srai_w | inst_sra_w;//Lab 6 change
assign alu_op[11] = inst_lu12i_w;
//Lab 6 add code
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
//lab 6 div_inst
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_mod_w;
assign alu_op[17] = inst_div_wu;
assign alu_op[18] = inst_mod_wu;
//Lab 6 add code end
//Lab 6 change code End
assign load_op = {inst_ld_w, inst_ld_b, inst_ld_h, inst_ld_bu, inst_ld_hu};//3
assign store_op = {inst_st_w ,inst_st_b, inst_st_h};

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
//Lab 6 add code
assign need_ui12  =  inst_andi   | inst_ori    | inst_xori;
//Lab 6 add code end
assign need_si12  =  inst_addi_w | (|load_op)  | (|store_op) | inst_slti | inst_sltui;  //Lab 6 add code
assign need_si16  =  inst_jirl   | inst_beq    | inst_bne;
assign need_si20  =  inst_lu12i_w| inst_pcaddu12i;
assign need_si26  =  inst_b      | inst_bl;
assign src2_is_4  =  inst_jirl   | inst_bl;
//Lab 6 change code
assign ds_imm =  src2_is_4 ? 32'h4:
		         need_si20 ? {i20[19:0],12'b0}: 
                 need_ui12 ? {20'b0,i12}: //i20[16:5]==i12[11:0]
  /*need_ui5 || need_si12*/ {{20{i12[11]}}, i12[11:0]};
assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} : 
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
//Lab 8 change code, add csrrX instrutions
assign src_reg_is_rd = inst_beq  | inst_bne  | inst_blt   | inst_bge   | inst_bltu   |
                       inst_bgeu |(|store_op)| inst_csrrd | inst_csrwr | inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;  //Lab 6 change code
assign src2_is_imm   = inst_slli_w | inst_srli_w  | inst_srai_w | inst_addi_w |(|load_op)     |
                       (|store_op) | inst_lu12i_w | inst_jirl   | inst_bl     | inst_slti     |
                       inst_sltui  | inst_andi    | inst_ori    | inst_xori   | inst_pcaddu12i;
//Lab 7 add code
//Lab 7 change and add code
assign res_from_mem  = inst_ld_w | inst_ld_h | inst_ld_b | inst_ld_bu | inst_ld_hu;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~(|store_op) & ~inst_beq  & ~inst_bne  & ~inst_b  & ~inst_blt & 
                       ~inst_bge    & ~inst_bltu & ~inst_bgeu & ~has_ine & ~has_adef &
                       ~has_ale     &~(|tlb_op)  & ~(|fs_tlb_ex);
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;
assign dest          = dst_is_r1    ? 5'd1: 
                       inst_rdcntid ? rj:
                                      rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd:
                                   rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );
//assign rj_value  = rf_rdata1; 
//assign rkd_value = rf_rdata2;
//add forward four-path selectors
//Lab 7 add and change code
assign {adder_cout,
        adder_result
        } = rj_value + ~rkd_value + 1;

assign rj_ls_rd = (rj_value[31] & ~rkd_value[31]) |
                  ((rj_value[31] ~^ rkd_value[31]) & adder_result[31]);
assign rju_ls_rdu = adder_cout;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (inst_beq  &  rj_eq_rd   |
                   inst_bne  & !rj_eq_rd   |
                   inst_blt  &  rj_ls_rd   |
                   inst_bge  & !rj_ls_rd   |
                   inst_bltu &  rju_ls_rdu |
                   inst_bgeu & !rju_ls_rdu |
                   inst_jirl | 
                   inst_bl   | 
                   inst_b   )& 
                   ds_valid  & ds_ready_go; 
assign br_target = (inst_beq | inst_bne  | inst_bl   | inst_b | inst_blt |
                    inst_bge | inst_bltu | inst_bgeu ) ? (ds_pc + br_offs):
                                           /*inst_jirl*/ (rj_value + jirl_offs);
assign br_stall  = inst_b_type & (rj_eq | rkd_eq);

always @(posedge clk) begin
    if (reset /*|| ~ws_ertn || ~ws_ex*/) begin
        ds_valid <= 0;
    end
    else if (ws_ertn | ws_ex) begin
        ds_valid <= 0;
    end 
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
   // else if (br_taken) begin
     //   ds_valid <= 0;
    //end 
 end //1
//add block code
//exe
//This signal avoid mistakes brought by inst like "ld.w"
assign {has_ale,
        es_wen,
        es_to_ds_dest,
        es_to_ds_res,
        es_not_ready_fwd
        } = es_to_id_byp_block;
//mem
assign {ms_wen,
        ms_to_ds_dest,
        ms_to_ds_res,
        ms_blk
        } = ms_to_id_byp_block;
//wb
assign {wb_wen,
        wb_to_id_dest,
        wb_to_id_res
        } = wb_to_id_byp_block;

//Task 7 change code
assign rjark = inst_add_w   | inst_sub_w  | inst_slt     | inst_sltu   | inst_and   |
               inst_or      | inst_nor    | inst_xor     | inst_bne    | inst_beq   |
               inst_blt     | inst_bge    | inst_bltu    | inst_bgeu   |(|store_op) |
               inst_mul_w   | inst_mulh_w | inst_mulh_wu | inst_sll_w  | inst_srl_w |
               inst_sra_w   | inst_div_w  | inst_mod_w   | inst_div_wu | inst_csrwr |
               inst_csrxchg | inst_mod_wu;
//lab 6 div_inst
assign rjo   = inst_addi_w | inst_slli_w | inst_srai_w | inst_srli_w | inst_jirl |
               (|load_op)  | inst_slti   | inst_sltui  | inst_andi   | inst_ori  |
               inst_xori   | inst_pcaddu12i;
//Task 7 change code end       
//judge if 0
assign rj_not0  = (rf_raddr1     != 0 & ds_valid)? 1'b1:1'b0;
assign rkd_not0 = (rf_raddr2     != 0 & ds_valid)? 1'b1:1'b0;
assign es_not0  = (es_to_ds_dest != 0 & ds_valid)? 1'b1:1'b0;
assign ms_not0  = (ms_to_ds_dest != 0 & ds_valid)? 1'b1:1'b0;
assign ws_not0  = (wb_to_id_dest != 0 & ds_valid)? 1'b1:1'b0;

assign rj_eq  = ((rj_not0 & es_not0 & es_wen) & (rj == es_to_ds_dest)) |
                ((rj_not0 & ms_not0 & ms_wen) & (rj == ms_to_ds_dest)) |
                ((rj_not0 & ws_not0 & wb_wen) & (rj == wb_to_id_dest))? 1'b1:1'b0;
assign rkd_eq = ((rkd_not0 & es_not0 & es_wen) & (rf_raddr2 == es_to_ds_dest)) |
                ((rkd_not0 & ms_not0 & ms_wen) & (rf_raddr2 == ms_to_ds_dest)) |
                ((rkd_not0 & ws_not0 & wb_wen) & (rf_raddr2 == wb_to_id_dest))? 1'b1:1'b0;
/*These signals symbolize that rs only eq in es,ms,ws*/
assign rj_exe_byp = (rj_not0 & es_not0 & es_wen & (rjo | rjark)) & (rj == es_to_ds_dest);
assign rj_mem_byp = (rj_not0 & ms_not0 & ms_wen & (rjo | rjark)) & (rj == ms_to_ds_dest);
assign rj_wb_byp  = (rj_not0 & ws_not0 & wb_wen & (rjo | rjark)) & (rj == wb_to_id_dest);
//rj selectors
assign rj_value = (rj_exe_byp & ~es_not_ready_fwd) ? es_to_ds_res:
                   rj_mem_byp                      ? ms_to_ds_res:
                   rj_wb_byp                       ? wb_to_id_res:
                                                     rf_rdata1;
assign rk_exe_byp = (rkd_not0 & es_not0 & es_wen & rjark) & (rf_raddr2 == es_to_ds_dest);
assign rk_mem_byp = (rkd_not0 & ms_not0 & ms_wen & rjark) & (rf_raddr2 == ms_to_ds_dest);
assign rk_wb_byp  = (rkd_not0 & ws_not0 & wb_wen & rjark) & (rf_raddr2 == wb_to_id_dest);
//rkd selectors
assign rkd_value = (rk_exe_byp & ~es_not_ready_fwd)? es_to_ds_res:
                    rk_mem_byp                     ? ms_to_ds_res:
                    rk_wb_byp                      ? wb_to_id_res:
                                                     rf_rdata2;
//assign ds_ready_go = ~((rj_eq & rjo) | ((rj_eq | rkd_eq) & rjark))? 1'b1:1'b0;
//This signal need to change
assign ds_ready_go = ~((es_not_ready_fwd & ~ws_ex &  ~ws_ertn) | csrr_block) & ~ms_blk ; //| ~((rj_exe_byp & rjo) | (rk_exe_byp & rjark) | (rj_exe_byp & rjark));
//(Int and Exception) This signal symbolize if there is exception or int
assign ds_ex = (has_int | inst_syscall | has_adef | inst_break | has_ine | (|fs_tlb_ex)) & ds_valid;
assign ds_ecode = inst_syscall ? 6'h0b: 
                  has_adef     ? 6'h08:
                  inst_break   ? 6'h0c:
                  has_ine      ? 6'h0d:
                  fs_tlb_ex[2] ? 6'h3f:
                  fs_tlb_ex[1] ? 6'h03:
                  fs_tlb_ex[0] ? 6'h07: 6'h00;
assign ds_esubcode = 9'b0;
//Block csrrX
assign csrr_block = ((es_inst_csrrd | es_inst_csrwr | es_inst_rdcntid) & (rj == es_to_ds_dest | rf_raddr2 == es_to_ds_dest)) |
                    ((ms_inst_csrrd | ms_inst_csrwr | ms_inst_rdcntid) & (rj == ms_to_ds_dest | rf_raddr2 == ms_to_ds_dest)) |
                    ((ws_inst_csrrd | ws_inst_csrwr | ws_inst_rdcntid) & (rj == wb_to_id_dest | rf_raddr2 == wb_to_id_dest));
//Lab 9 add
assign has_ine = ~(inst_add_w   | inst_sub_w   | inst_slt       | inst_sltu      | inst_nor     |
                   inst_and     | inst_or      | inst_xor       | inst_slli_w    | inst_srli_w  |
                   inst_srai_w  | inst_addi_w  | inst_ld_w      | inst_st_w      | inst_jirl    |
                   inst_b       | inst_bl      | inst_beq       | inst_bne       | inst_lu12i_w |
                   inst_slti    | inst_sltui   | inst_andi      | inst_ori       | inst_xori    |
                   inst_sll_w   | inst_srl_w   | inst_sra_w     | inst_pcaddu12i | inst_mul_w   |
                   inst_mulh_w  | inst_mulh_wu | inst_div_w     | inst_mod_w     | inst_div_wu  |
                   inst_mod_wu  | inst_blt     | inst_bge       | inst_bltu      | inst_bgeu    |
                   inst_ld_b    | inst_ld_h    | inst_ld_bu     | inst_ld_hu     | inst_st_b    |
                   inst_st_h    | inst_csrrd   | inst_csrwr     | inst_csrxchg   | inst_ertn    |
                   inst_syscall | inst_break   | inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid |
                   inst_tlbsrch | inst_tlbrd   | inst_tlbwr     | inst_tlbfill   | inst_invtlb  
                   )|invtlb_op_ine;
                
assign counter_op = {inst_rdcntvl_w,
                     inst_rdcntvh_w,
                     inst_rdcntid
                     };
//br_stall
assign inst_b_type = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
//tlb operation
assign tlb_op = {inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb};
assign invtlb_op = rd;
wire invtlb_op_ine = (~(invtlb_op==5'b00000 || invtlb_op==5'b00001 || invtlb_op==5'b00010 || invtlb_op==5'b00011
                        ||invtlb_op==5'b00100 || invtlb_op==5'b00101 || invtlb_op==5'b00110)&inst_invtlb);

wire        ds_csr_we;
wire [13:0] ds_csr_num_o;

assign ds_csr_we    = (inst_csrwr | inst_csrxchg) & ds_valid & ~ds_ex;
assign ds_csr_num_o = counter_op[0]? 64: ds_inst[23:10];
assign ds_csr_num   = {14{ds_valid}} & {14{ds_csr_we}} & ds_csr_num_o;
endmodule