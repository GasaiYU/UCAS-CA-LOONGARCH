`include "mycpu.h"

module csrr (
    input         clk   ,
    input         reset ,
    input         wb_ex ,
    input  [7 :0] hw_int_in, 
    input  [0 :0] ipi_int_in,
    input  [31:0] ws_pc ,
    input  [31:0] ws_pc_e,
    input  [31:0] wb_vaddr ,
    input         ertn_reflush,
    input  [13:0] csr_num,
    input         csr_we,
    input  [31:0] csr_wmask,
    input  [31:0] csr_wvalue,
    input  [5 :0] wb_ecode,
    input  [8 :0] wb_esubcode,
    input  [31:0] coreid_in,
    output [31:0] csr_rvalue,
    //If this is int
    output [0: 0] has_int   ,
    //Control Reg
    output [31:0] csr_era   ,
    output [31:0] csr_eentry,
    output [31:0] csr_estat , 
    output [31:0] csr_crmd  ,
    output [31:0] csr_dmw0  ,
    output [31:0] csr_dmw1  ,
    input  [0 :0] ws_ertn,
    //tlbidx
    output [3:0] csr_tlbidx_index,
    input        csr_tlbidx_index_we,
    input  [3:0] csr_tlbidx_index_w,
    output [5:0] csr_tlbidx_ps,
    input        csr_tlbidx_ps_we,
    input  [5:0] csr_tlbidx_ps_w,
    output       csr_tlbidx_nul,
    input        csr_tlbidx_nul_we,
    input        csr_tlbidx_nul_w,
    //tlbehi
    output [18:0] csr_tlbehi_vppn,
    input        csr_tlbehi_vppn_we,
    input [18:0] csr_tlbehi_vppn_w,
    //lo0
    input        csr_tlbelo0_we,
    input [23:0] csr_tlbelo0_ppn_w,
    input [6 :0] csr_tlbelo0_con_w,
    output       csr_tlbelo0_g,
    output [23:0] csr_tlbelo0_ppn,
    output       csr_tlbelo0_v,
    output [1:0] csr_tlbelo0_plv,
    output [1:0] csr_tlbelo0_mat,
    output       csr_tlbelo0_d,
    //lo1
    input        csr_tlbelo1_we,
    input [23:0] csr_tlbelo1_ppn_w,
    input [6 :0] csr_tlbelo1_con_w,
    output       csr_tlbelo1_g,
    output [23:0] csr_tlbelo1_ppn,
    output       csr_tlbelo1_v,
    output [1:0] csr_tlbelo1_plv,
    output [1:0] csr_tlbelo1_mat,
    output       csr_tlbelo1_d,
    //asid
    input        csr_asid_we,
    input [9:0]  csr_asid_asid_w,
    input [7:0]  csr_asid_asidbits_w,
    output [9:0] csr_asid_asid,
    output [7:0] csr_asid_asidbits,
    //ex
    input [ 2:0] fs_tlb_ex,
    input [ 4:0] es_tlb_ex,
    input [31:0] error_vppn
); 


//Below we want to realize the special registers QQQQQAQQQQQ

//CRMD REGISTERS BEGIN!
wire fs_tlb_refill;
wire fs_plv_inv;
wire fs_fetch_inv;
wire es_tlb_refill;
wire es_plv_inv;
wire es_load_inv;
wire es_store_inv;
wire es_tlb_modified;

assign  {fs_tlb_refill, fs_fetch_inv, fs_plv_inv} = fs_tlb_ex;
assign  {es_tlb_refill, es_plv_inv, es_load_inv, es_store_inv, es_tlb_modified} = es_tlb_ex;

/*PLV Field*/
//wire [31:0] csr_crmd;
reg [1:0] csr_crmd_plv;
reg [1:0] csr_prmd_pplv;

always@(posedge clk) begin
    if(reset) begin
        csr_crmd_plv <= 2'b0;
    end
    else if (wb_ex) begin
        csr_crmd_plv <= 2'b0;
    end
    else if (ertn_reflush) begin
        csr_crmd_plv <= csr_prmd_pplv;
    end
    else if (csr_we && csr_num==`CSR_CRMD) begin
        csr_crmd_plv <= csr_wmask[1:0] & csr_wvalue[1:0] | ~csr_wmask[1:0] & csr_crmd_plv;
    end
end

/*IE Field*/
reg [0:0] csr_crmd_ie;
reg [0:0] csr_prmd_pie;

always @(posedge clk) begin
    if(reset) begin
        csr_crmd_ie <= 1'b0;
    end
    else if(wb_ex) begin
        csr_crmd_ie <= 1'b0;
    end
    else if(ertn_reflush) begin
        csr_crmd_ie <= csr_prmd_pie; 
    end
    else if(csr_we && csr_num==`CSR_CRMD) begin
        csr_crmd_ie <= csr_wmask[2] & csr_wvalue[2] | ~csr_wmask[2] & csr_crmd_ie;
    end
end

/*DA Field*/
reg [0:0] csr_crmd_da;
always @(posedge clk) begin
    if(reset) begin
        csr_crmd_da <= 1'b1;
    end
    else if(fs_tlb_refill | es_tlb_refill) begin
        csr_crmd_da <= 1'b1;
    end
    else if(ertn_reflush | csr_estat_ecode == 6'h3f) begin
        csr_crmd_da <= 1'b0;
    end
    else if(csr_we && csr_num==`CSR_CRMD) begin
        csr_crmd_da <= csr_wmask[3] & csr_wvalue[3] | ~csr_wmask[3] & csr_crmd_da;
    end
end

/*PG Field*/
reg [0:0] csr_crmd_pg;
always @(posedge clk) begin
    if(reset) begin
        csr_crmd_pg <= 1'b0;
    end
    else if(fs_tlb_refill | es_tlb_refill) begin
        csr_crmd_pg <= 1'b0;
    end
    else if(ertn_reflush | csr_estat_ecode == 6'h3f) begin
        csr_crmd_pg <= 1'b1;
    end
    else if(csr_we && csr_num==`CSR_CRMD) begin
        csr_crmd_pg <= csr_wmask[4] & csr_wvalue[4] | ~csr_wmask[4] & csr_crmd_pg;
    end
end

//TLB 
assign csr_crmd = {27'b0, csr_crmd_pg/*PG*/ ,csr_crmd_da/*DA*/, csr_crmd_ie/*IE*/, csr_crmd_plv/*PLV*/};

//Below is the PRMD REGISTERS!!!

/*PPLV and PIE*/
wire [31:0] csr_prmd;
always @(posedge clk) begin
    if(wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie ;
    end
    else if(csr_we && csr_num == `CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[1:0] & csr_wvalue[1:0] | ~csr_wmask[1:0] & csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[2]   & csr_wvalue[2]   | ~csr_wmask[2]   & csr_prmd_pie;
    end
end

assign csr_prmd = {29'b0/*R0*/, csr_prmd_pie/*PIE*/, csr_prmd_pplv/*PPLV*/};

//Below is the ESTAT REGISTERS!!
reg [12:0] csr_estat_is;
reg [31:0] timer_cnt;

/*Timer_cnt*/
//always @(posedge clk) begin
//    if(reset) begin
//        timer_cnt <= 32'hffffffff;
//    end else begin
//        timer_cnt <= timer_cnt - 1'b1;
//    end
//end


/*IS field*/
always @(posedge clk) begin
    if(reset) begin
        csr_estat_is[1:0] <= 2'b0;
    end
    else if(csr_we && csr_num == `CSR_ESTAT) begin
        csr_estat_is[1:0] <= csr_wmask[1:0] & csr_wvalue[1:0] | ~csr_wmask[1:0] & csr_estat_is[1:0];
    end

    csr_estat_is[9:2] <= hw_int_in[7:0];    
    csr_estat_is[10]  <= 1'b0;          //This bit is not defined
    csr_estat_is[12]  <= ipi_int_in;    //Between Core int
end

always @(posedge clk ) begin
    if (timer_cnt[31:0]==32'b0) begin
        csr_estat_is[11] <= 1'b1;
    end
    else if (csr_we && csr_num ==`CSR_TICLR && csr_wmask[0] && csr_wvalue[0]) begin
        csr_estat_is[11] <= 1'b0;
    end
end

/*Ecode and EsubCode field*/
reg [5:0] csr_estat_ecode;
reg [5:0] csr_estat_esubcode;
wire [31:0] csr_estat;

always @(posedge clk) begin
    if(reset) begin
        csr_estat_ecode <= 6'b0;
    end
    else if(wb_ex) begin
        csr_estat_ecode    <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

assign csr_estat = {1'b0/*R0*/, csr_estat_esubcode/*ESUBCODE*/,csr_estat_ecode/*ECODE*/, 3'b0, 
                    csr_estat_is};

//Below is ERA register!!
reg [31:0] csr_era_pc;

always @(posedge clk) begin
    if(wb_ex) begin
        csr_era_pc <= ws_pc_e;
    end
    else if(csr_we && csr_num == `CSR_ERA) begin
        csr_era_pc <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & csr_era_pc;
    end
end

assign csr_era = csr_era_pc;

//Below is EENTRY register!!
reg [25:0] csr_eentry_va;

always @(posedge clk) begin
    if (csr_we && csr_num == `CSR_EENTRY) begin
        csr_eentry_va <= csr_wmask[31:6] & csr_wvalue[31:6] | ~csr_wmask[31:6] & csr_eentry_va;
    end
end

assign csr_eentry = {csr_eentry_va/*VA*/, 6'b0/*0*/};

//Below is SAVE 0-3 register!!
reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;

/*Save 0 register*/
wire [31:0] csr_save0;
always @(posedge clk) begin
    if(csr_we && csr_num == `CSR_SAVE0) begin
        csr_save0_data <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & csr_save0_data;
    end
end

assign csr_save0 = csr_save0_data;

/*Save 1 register*/
wire [31:0] csr_save1;
always @(posedge clk) begin
    if(csr_we && csr_num == `CSR_SAVE1) begin
        csr_save1_data <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & csr_save1_data;
    end
end

assign csr_save1 = csr_save1_data;

/*Save 2 register*/
wire [31:0] csr_save2;
always @(posedge clk) begin
    if(csr_we && csr_num == `CSR_SAVE2) begin
        csr_save2_data <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & csr_save2_data;
    end
end

assign csr_save2 = csr_save2_data;

/*Save 3 register*/
wire [31:0] csr_save3;
always @(posedge clk) begin
    if(csr_we && csr_num == `CSR_SAVE3) begin
        csr_save3_data <= csr_wmask[31:0] & csr_wvalue[31:0] | ~csr_wmask[31:0] & csr_save3_data;
    end
end

assign csr_save3 = csr_save3_data;

/*ECFG register*/
wire [31:0] csr_ecfg;
reg [12:0] csr_ecfg_lie;
always @(posedge clk) begin
    if(reset) begin
        csr_ecfg_lie <= 13'b0;
    end 
    else if(csr_we & csr_num == `CSR_ECFG) begin
        csr_ecfg_lie <= csr_wmask[12:0] & csr_wvalue[12:0] | ~csr_wmask[12:0] & csr_ecfg_lie;
    end
end

assign csr_ecfg = {19'b0, csr_ecfg_lie};

/*LAB9 ADD REG*/
/*BADV register*///ECODE_ADE ^^^=?,
wire [31:0] csr_badv;
reg [31:0] csr_badv_vaddr;
assign wb_ex_addr_err = wb_ecode==6'h08 || wb_ecode==6'h09;

always @(posedge clk) begin
    if(reset) begin
        csr_badv_vaddr <= 32'b0;
    end
    else if (wb_ex && wb_ex_addr_err) begin
        csr_badv_vaddr <= (wb_ecode==6'h08 & wb_esubcode==9'b0) ? ws_pc_e : wb_vaddr;
    end
    else if((|fs_tlb_ex) | (|es_tlb_ex)) begin
        csr_badv_vaddr <= error_vppn;
    end    
end

assign csr_badv = {csr_badv_vaddr};

/*TID register*/
wire [31:0] csr_tid;
reg [31:0] csr_tid_tid;
always @(posedge clk) begin
    if (reset)
        csr_tid_tid <= coreid_in;
    else if (csr_we & csr_num==`CSR_TID)
        csr_tid_tid <= csr_wmask[31:0]&csr_wvalue[31:0] | ~csr_wmask[31:0] & csr_tid_tid;
end
assign csr_tid = {csr_tid_tid};

/*TCFG register*/
wire [31:0] csr_tcfg;
reg [0 :0] csr_tcfg_en;
reg [0 :0] csr_tcfg_periodic;
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we & csr_num==`CSR_TCFG)
        csr_tcfg_en <= csr_wmask[0]&csr_wvalue[0] | ~csr_wmask[0]&csr_tcfg_en;
    if (csr_we && csr_num==`CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[1]&csr_wvalue[1] | ~csr_wmask[1]&csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[31:2]&csr_wvalue[31:2] | ~csr_wmask[31:2]&csr_tcfg_initval;
    end
end
assign csr_tcfg = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

/*TVAL register*/
wire [31:0] csr_tval;
reg [29:0] csr_tcfg_initval;
wire [31:0] tcfg_next_value;
assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]
                        | ~csr_wmask[31:0]&{csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[0])
        timer_cnt <= {tcfg_next_value[31:2], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
end
assign csr_tval = timer_cnt[31:0];

//TICLR register
wire csr_ticlr_clr;
wire [31:0] csr_ticlr;
assign csr_ticlr_clr = 1'b0;
assign csr_ticlr = 32'b0;

/*Below is TLBIDX Register*/
reg [3:0] csr_tlbidx_index1;
reg [5:0] csr_tlbidx_ps1;
reg [0:0] csr_tlbidx_nul1;
reg [11:0] csr_tlbidx_r0;
wire [31:0] csr_tlbidx;
//Index Field
always @(posedge clk) begin
    if(reset) begin
        csr_tlbidx_index1 <= 4'b0;
    end
    else if(csr_tlbidx_index_we) begin
        csr_tlbidx_index1 <= csr_tlbidx_index_w;
    end 
    else if (csr_we && csr_num==`CSR_TLBIDX) begin
        csr_tlbidx_index1 <= csr_wmask[3:0] & csr_wvalue[3:0] | ~csr_wmask[3:0] & csr_tlbidx_index1[3:0];
       // csr_tlbidx_r0 <= csr_wmask[15:4] & csr_wvalue[15:4] | ~csr_wmask[15:4] & csr_tlbidx_index1[15:4];
    end
end
assign csr_tlbidx_index = csr_tlbidx_index1;

//PS Field
always @(posedge clk) begin
    if(reset) begin
        csr_tlbidx_ps1 <= 6'b0;
    end
    else if(csr_tlbidx_ps_we) begin
        csr_tlbidx_ps1 <= csr_tlbidx_ps_w;
    end
    else if (csr_we && csr_num==`CSR_TLBIDX) begin
        csr_tlbidx_ps1 <= csr_wmask[29:24] & csr_wvalue[29:24] | ~csr_wmask[29:24] & csr_tlbidx_ps1[5:0];
    end
end
assign csr_tlbidx_ps = csr_tlbidx_ps1;

//Nul field
always @(posedge clk) begin
    if(reset) begin
        csr_tlbidx_nul1 <= 1'b0;
    end
    else if(csr_tlbidx_nul_we) begin
        csr_tlbidx_nul1 <= csr_tlbidx_nul_w;
    end
    else if (csr_we && csr_num==`CSR_TLBIDX) begin
        csr_tlbidx_nul1 <= csr_wmask[31] & csr_wvalue[31] | ~csr_wmask[31] & csr_tlbidx_nul1;
    end    
end
assign csr_tlbidx_nul = csr_tlbidx_nul1;

assign csr_tlbidx = {csr_tlbidx_nul1/*NE*/ ,1'b0 ,csr_tlbidx_ps1/*PS*/ ,8'b0/*R0*/ ,12'b0/*R*/, csr_tlbidx_index1/*Index*/};


/*TLBEHI register*/
reg [18:0] csr_tlbehi_vppn1;
wire [31:0] csr_tlbehi;

always @(posedge clk) begin
    if(reset) begin
        csr_tlbehi_vppn1 <= 19'b0;
    end
    else if((|fs_tlb_ex) | (|es_tlb_ex)) begin
        csr_tlbehi_vppn1 <= error_vppn[31:13];
    end
    else if(csr_tlbehi_vppn_we)begin
        csr_tlbehi_vppn1 <= csr_tlbehi_vppn_w;
    end
    else if (csr_we && csr_num==`CSR_TLBEHI) begin
        csr_tlbehi_vppn1 <= csr_wmask[31:13] & csr_wvalue[31:13] | ~csr_wmask[31:13] & csr_tlbehi_vppn1[18:0];
    end    
end
assign csr_tlbehi_vppn = csr_tlbehi_vppn1;

assign csr_tlbehi = {csr_tlbehi_vppn1/*VPPN*/, 13'b0};

/*TLBLO0*/
reg  [23:0] csr_tlbelo0_ppn1;
reg  [6:0]  csr_tlbelo0_con;
wire [31:0] csr_tlbelo0;

always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo0_con <= 7'b0;
        csr_tlbelo0_ppn1 <= 24'b0;
    end
    else if(csr_tlbelo0_we) begin
        csr_tlbelo0_ppn1 <= csr_tlbelo0_ppn_w;
        csr_tlbelo0_con <= csr_tlbelo0_con_w;
    end
    else if (csr_we && csr_num==`CSR_TLBELO0) begin
        csr_tlbelo0_con  <= csr_wmask[6:0]  & csr_wvalue[6:0]  | ~csr_wmask[6:0]  & csr_tlbelo0_con[6:0];
        csr_tlbelo0_ppn1 <= csr_wmask[31:8] & csr_wvalue[31:8] | ~csr_wmask[31:8] & csr_tlbelo0_ppn1[23:0];
    end    
end

assign csr_tlbelo0 = {csr_tlbelo0_ppn1, 1'b0, csr_tlbelo0_con};
assign {csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v} = csr_tlbelo0_con;
assign csr_tlbelo0_ppn = csr_tlbelo0_ppn1;

/*TLBLO1*/
reg  [23:0] csr_tlbelo1_ppn1;
reg  [6:0]  csr_tlbelo1_con;
wire [31:0] csr_tlbelo1;

always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_con <= 7'b0;
        csr_tlbelo1_ppn1 <= 24'b0;
    end
    else if(csr_tlbelo1_we) begin
        csr_tlbelo1_ppn1 <= csr_tlbelo1_ppn_w;
        csr_tlbelo1_con <= csr_tlbelo1_con_w;
    end
    else if (csr_we && csr_num==`CSR_TLBELO1) begin
        csr_tlbelo1_con  <= csr_wmask[6:0]  & csr_wvalue[6:0]  | ~csr_wmask[6:0]  & csr_tlbelo1_con[6:0];
        csr_tlbelo1_ppn1 <= csr_wmask[31:8] & csr_wvalue[31:8] | ~csr_wmask[31:8] & csr_tlbelo1_ppn1[23:0];
    end    
end

assign csr_tlbelo1 = {csr_tlbelo1_ppn1, 1'b0, csr_tlbelo1_con};
assign {csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v} = csr_tlbelo1_con;
assign csr_tlbelo1_ppn = csr_tlbelo1_ppn1;

/*ASID*/
reg [9:0] csr_asid_asid1;
reg [7:0] csr_asid_asidbits1;
wire [31:0] csr_asid;
always @(posedge clk) begin
    if(reset) begin
        csr_asid_asid1 <= 10'b0;
        csr_asid_asidbits1 <= 8'h0a;
    end 
    else if(csr_asid_we) begin
        csr_asid_asid1 <= csr_asid_asid_w;
    end
    else if (csr_we && csr_num==`CSR_ASID) begin
        csr_asid_asid1 <= csr_wmask[9:0] & csr_wvalue[9:0] | ~csr_wmask[9:0] & csr_asid_asid1[9:0];
    end    
end

assign csr_asid_asid = csr_asid_asid1;
assign csr_asid_asidbits = csr_asid_asidbits1;
assign csr_asid = {8'b0, csr_asid_asidbits1, 6'b0, csr_asid_asid1};

/*TLBRENTRY*/
reg [25:0] csr_tlbrentry_pa1;
wire [31:0] csr_tlbrentry;
always @(posedge clk) begin
    if(reset) begin
        csr_tlbrentry_pa1 <= 26'b0;
    end
    else if (csr_we && csr_num==`CSR_TLBRENTRY) begin
        csr_tlbrentry_pa1 <= csr_wmask[31:6] & csr_wvalue[31:6] | ~csr_wmask[31:6] & csr_tlbrentry_pa1[25:0];
    end    
end

assign csr_tlbrentry = {csr_tlbrentry_pa1, 6'b0};

/*DMW0*/
reg       csr_dmw0_plv0;
reg       csr_dmw0_plv3;
reg [1:0] csr_dmw0_mat;
reg [2:0] csr_dmw0_pseg;
reg [2:0] csr_dmw0_vseg;
wire [31:0] csr_dmw0;

always @(posedge clk) begin
    if(reset) begin
        csr_dmw0_plv0 <= 1'b0;
        csr_dmw0_plv3 <= 1'b0;
        csr_dmw0_mat  <= 2'b0;
        csr_dmw0_pseg <= 3'b0;
        csr_dmw0_vseg <= 3'b0;
    end
    else if(csr_we && csr_num == `CSR_DMW0) begin
        csr_dmw0_plv0 <= csr_wmask[0]     & csr_wvalue[0]     | ~csr_wmask[0]     & csr_dmw0_plv0;
        csr_dmw0_plv3 <= csr_wmask[3]     & csr_wvalue[3]     | ~csr_wmask[3]     & csr_dmw0_plv3;
        csr_dmw0_mat  <= csr_wmask[5:4]   & csr_wvalue[5:4]   | ~csr_wmask[5:4]   & csr_dmw0_mat ;
        csr_dmw0_pseg <= csr_wmask[27:25] & csr_wvalue[27:25] | ~csr_wmask[27:25] & csr_dmw0_pseg;
        csr_dmw0_vseg <= csr_wmask[31:29] & csr_wvalue[31:29] | ~csr_wmask[31:29] & csr_dmw0_vseg;
    end
end

assign csr_dmw0 = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};

/*DMW1*/
reg       csr_dmw1_plv0;
reg       csr_dmw1_plv3;
reg [1:0] csr_dmw1_mat;
reg [2:0] csr_dmw1_pseg;
reg [2:0] csr_dmw1_vseg;
wire [31:0] csr_dmw1;

always @(posedge clk) begin
    if(reset) begin
        csr_dmw1_plv0 <= 1'b0;
        csr_dmw1_plv3 <= 1'b0;
        csr_dmw1_mat  <= 2'b0;
        csr_dmw1_pseg <= 3'b0;
        csr_dmw1_vseg <= 3'b0;
    end
    else if(csr_we && csr_num == `CSR_DMW1) begin
        csr_dmw1_plv0 <= csr_wmask[0]     & csr_wvalue[0]     | ~csr_wmask[0]     & csr_dmw1_plv0;
        csr_dmw1_plv3 <= csr_wmask[3]     & csr_wvalue[3]     | ~csr_wmask[3]     & csr_dmw1_plv3;
        csr_dmw1_mat  <= csr_wmask[5:4]   & csr_wvalue[5:4]   | ~csr_wmask[5:4]   & csr_dmw1_mat ;
        csr_dmw1_pseg <= csr_wmask[27:25] & csr_wvalue[27:25] | ~csr_wmask[27:25] & csr_dmw1_pseg;
        csr_dmw1_vseg <= csr_wmask[31:29] & csr_wvalue[31:29] | ~csr_wmask[31:29] & csr_dmw1_vseg;
    end
end

assign csr_dmw1 = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};


//Read data defined HERE!!
assign csr_rvalue = {32{csr_num == `CSR_CRMD}}   & csr_crmd   |
                    {32{csr_num == `CSR_PRMD}}   & csr_prmd   |
                    {32{csr_num == `CSR_ERA }}   & csr_era    |
                    {32{csr_num == `CSR_EENTRY}} & csr_eentry |
                    {32{csr_num == `CSR_ESTAT}}  & csr_estat  |
                    {32{csr_num == `CSR_SAVE0}}  & csr_save0  |
                    {32{csr_num == `CSR_SAVE1}}  & csr_save1  |
                    {32{csr_num == `CSR_SAVE2}}  & csr_save2  |
                    {32{csr_num == `CSR_SAVE3}}  & csr_save3  |
                    {32{csr_num == `CSR_ECFG}}   & csr_ecfg   |
                    {32{csr_num == `CSR_BADV}}   & csr_badv   |
                    {32{csr_num == `CSR_TID}}    & csr_tid    |
                    {32{csr_num == `CSR_TCFG}}   & csr_tcfg   |
                    {32{csr_num == `CSR_TVAL}}   & csr_tval   |
                    {32{csr_num == `CSR_TICLR}}  & csr_ticlr  |
                    {32{csr_num == `CSR_TLBIDX}}  & csr_tlbidx |
                    {32{csr_num == `CSR_TLBEHI}}  & csr_tlbehi |
                    {32{csr_num == `CSR_TLBELO0}} & csr_tlbelo0 |
                    {32{csr_num == `CSR_TLBELO1}} & csr_tlbelo1 |
                    {32{csr_num == `CSR_ASID}}    & csr_asid   |
                    {32{csr_num == `CSR_TLBRENTRY}}  & csr_tlbrentry |
                    {32{csr_num == `CSR_DMW0}}  & csr_dmw0 |
                    {32{csr_num == `CSR_DMW1}}  & csr_dmw1;

assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) && (csr_crmd_ie == 1'b1);

endmodule 