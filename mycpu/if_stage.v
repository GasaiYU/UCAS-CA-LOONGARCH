`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //ertn
    input  [31                 :0] csr_epc        ,
    input  [31                 :0] csr_eentry     ,
    input  [0                  :0] ws_ertn      ,
    input  [0                  :0] ws_ex          ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_req   ,
    output        inst_sram_wr    ,
    //output        inst_sram_en    ,
    output [1:0]  inst_sram_size  ,
    output [3:0]  inst_sram_wstrb ,
    //output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr   ,
    output [31:0] inst_sram_wdata  ,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok, 
    input  [31:0] inst_sram_rdata, 
    //from ws
    input  [31:0] csr_crmd,
    input  [13:0] ws_csr_num_to_fs,
    input  [ 4:0] ws_tlbop,
    //from ms
    input  [13:0] ms_csr_num,
    input  [ 4:0] ms_tlbop,
    //from es
    input  [13:0] es_csr_num,
    //from ds
    input  [13:0] ds_csr_num 
);
reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire        fs_clear;

wire        inst_sram_en;
wire [3: 0] inst_sram_wen;

wire [31:0] seq_pc;
wire [31:0] nextpc;
reg  [31:0] fs_pc;
wire [31:0] fs_inst;
reg         fs_inst_invalid;
reg  [31:0] inst_buf;
reg         inst_buf_valid;  

wire        br_taken;
wire        br_stall;
wire [31:0] br_target;
wire [31:0] br_target_pc;
reg         br_valid;
reg  [31:0] br_target_buff;

reg         in_req;
wire        pre_if_ready_go;

reg         ex_waiting;
reg [31:0]  exception_entry;
wire        has_adef;
wire        has_adef_o;

assign fs_to_ds_bus = {fs_tlb_ex,    //67:65
                       has_adef_o,   //64:64
                       fs_inst ,     //63:32
                       fs_pc         //31:0
                       };
assign {br_taken,
        br_stall,
        br_target
        } = br_bus;
// pre-IF stage
// There need to be changed in Lab 8
//Some REG
//in_req 
always @(posedge clk) begin
    if (reset) begin
        in_req <= 1'b0;
    end 
    else if (inst_sram_req & inst_sram_addr_ok) begin       //Shake hands
        in_req <= 1'b0;
    end 
    else if (fs_allowin) begin                               //Only if fs_allowin can send request.
        in_req <= 1'b1;
    end
end
//Clear all r(1-bit register) 
/*reg [0:0] fs_clear_r;
always @(posedge clk) begin
    if(reset) begin
        fs_clear_r <= 1'b0;
    end
    else if(fs_clear) begin
        fs_clear_r <= 1'b1;
    end
    else if(inst_sram_addr_ok & inst_sram_req) begin
        fs_clear_r <= 1'b0;
    end
end*/
//Some Control Signals, Need to be changed in Lab 10
always@(posedge clk)begin
    if (reset) begin
        ex_waiting <= 1'b0;
    end
    else if (ws_ex | ws_ertn) begin
        ex_waiting <= 1'b1;
    end
    else if (to_fs_valid) begin
        ex_waiting <= 1'b0;
    end
end
always @(posedge clk) begin
    if (reset) begin
        exception_entry <= 32'b0;
    end
    else if (ws_ex) begin
        exception_entry <= csr_eentry;
    end
    else if (ws_ertn) begin
        exception_entry <= csr_epc;
    end
end

//Search tlb. ADD CODE HERE AND SEARCH TLB! I do not realize MMU!
wire [ 9:0] fs_s0_asid;
wire [18:0] fs_s0_vppn;
wire        fs_va_bit12;

wire        fs_s0_found;
wire [ 3:0] fs_s0_index;
wire [19:0] fs_s0_ppn;
wire [ 5:0] fs_s0_ps;
wire [ 1:0] fs_s0_plv;
wire [ 1:0] fs_s0_mat;
wire        fs_s0_d;
wire        fs_s0_v;

//tlb exceptions
wire        fs_tlb_refill;
wire        fs_fetch_inv;
wire        fs_plv_inv;
wire        plv_blocked;
wire  [1:0] fs_csr_plv;
wire  [2:0] fs_tlb_ex;

assign fs_tlb_refill = ~fs_s0_found & fs_valid;        //Cannot find this page
assign fs_fetch_inv  = ~fs_s0_v & fs_valid & fs_s0_found;            //Page invalid
//plv invalid
assign fs_csr_plv    = csr_crmd[1:0];
assign fs_plv_inv    = ((fs_s0_plv == 0) && ((fs_csr_plv == 1) || (fs_csr_plv == 2) || (fs_csr_plv == 3))) & fs_valid & fs_s0_found & fs_s0_v;
assign plv_blocked   = (ws_csr_num_to_fs == `CSR_CRMD || ms_csr_num == `CSR_CRMD || es_csr_num == `CSR_CRMD || ds_csr_num == `CSR_CRMD) & fs_valid;

//Inst_ram
assign fs_tlb_ex       = {fs_tlb_refill, fs_fetch_inv, fs_plv_inv};
assign inst_sram_req   = in_req & ~br_stall;
assign pre_if_ready_go = (inst_sram_addr_ok & inst_sram_req & ~plv_blocked);         //Shake Hands

assign to_fs_valid  = (~reset & pre_if_ready_go);
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = ws_ertn                ? csr_epc:
                      ws_ex                  ? csr_eentry: 
                      ex_waiting             ? exception_entry:
                      (br_taken & ~br_stall) ? br_target : 
                      br_valid               ? br_target_buff:
                                               seq_pc; 
// IF stage
//We need to set a REG to store EXCETION! 
assign fs_clear       = ws_ex | ws_ertn;
assign fs_ready_go    = (inst_buf_valid | inst_sram_data_ok) & ~fs_inst_invalid;
assign fs_allowin     = !fs_valid | fs_ready_go & ds_allowin;
assign fs_to_ds_valid = fs_valid & fs_ready_go & ~ws_ertn & ~ws_ex;
//Reg fs_inst_invalid to cancel invalid inst.
always @(posedge clk) begin
    if (reset) begin
        fs_inst_invalid <= 1'b0;
    end 
    else if (fs_clear & to_fs_valid) begin
        fs_inst_invalid <= 1'b1;
    end
    else if (fs_clear & ~fs_allowin & ~fs_ready_go) begin
        fs_inst_invalid <= 1'b1;
    end
    else if (inst_sram_data_ok) begin
        fs_inst_invalid <= 1'b0;
    end
end
//Inst Buffer Signals   
/*Inst_buf_valid*/
always @(posedge clk) begin
    if (reset) begin
        inst_buf_valid <= 1'b0;
    end
    else if (fs_clear) begin
        inst_buf_valid <= 1'b0;
    end
    else if (fs_valid & ~ds_allowin & inst_sram_data_ok) begin
        inst_buf_valid <= 1'b1;
    end
    else if (fs_to_ds_valid & ds_allowin) begin
        inst_buf_valid <= 1'b0;
    end
end
/*Inst_buf*/
always @(posedge clk) begin
    if(reset) begin
        inst_buf <= 32'b0;
    end
    else if(fs_valid & ~ds_allowin & inst_sram_data_ok) begin
        inst_buf <= inst_sram_rdata;
    end
end
//fs_valid    When inst cancel, we need set the signal 'valid' 0
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_clear) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end 
    else if (br_taken /*|| ~ws_ertn || ~ws_ex*/) begin
        fs_valid <= 1'b0;    //add code
    end

    if (reset) begin
        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    end
    /*else if (ws_ex | ws_ertn) begin
        fs_pc <= nextpc;
    end*/
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end
//Master ---> Slave Signals
assign inst_sram_en    = to_fs_valid & fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'd2;
assign inst_sram_wstrb = 4'b0;

assign fs_inst         = (fs_valid & inst_buf_valid)? inst_buf:
                                                      inst_sram_rdata;
//lab 9 add adef
assign has_adef = ~(nextpc[1:0] == 2'b0);
assign has_adef_o = has_adef & fs_valid;
//lab 10 br_buf
always @(posedge clk) begin
    if (reset | to_fs_valid) begin
        br_valid <= 1'b0;
    end
    else if (ws_ertn | ws_ex) begin
        br_valid <= 1'b0;
    end
    else if (br_taken) begin
        br_valid <= 1'b1;
    end
end
always @(posedge clk) begin
    if (br_taken) begin
        br_target_buff <= br_target;
    end
end




endmodule