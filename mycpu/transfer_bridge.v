module transfer_bridge (

    /*AXI SIGNALS!*/
    //clk and reset
    input aclk,
    input aresetn,

    //Read request channel
    output [ 3:0] arid,
    output [31:0] araddr,
    output [ 7:0] arlen,
    output [ 2:0] arsize,
    output [ 1:0] arburst,
    output [ 1:0] arlock,
    output [ 3:0] arcache,
    output [ 2:0] arprot,
    output        arvalid,
    input         arready,

    //Read response channel
    input [ 3:0] rid,
    input [31:0] rdata,
    input [ 1:0] rresp,
    input        rlast,
    input        rvalid,
    output       rready,

    //Write request channel
    output [ 3:0] awid,
    output [31:0] awaddr,
    output [ 7:0] awlen,
    output [ 2:0] awsize,
    output [ 1:0] awburst,
    output [ 1:0] awlock,
    output [ 3:0] awcache,
    output [ 2:0] awprot,
    output        awvalid,
    input         awready,

    //Write data channel
    output [ 3:0] wid,
    output [31:0] wdata,
    output [ 3:0] wstrb,
    output        wlast,
    output        wvalid,
    input         wready,

    //Write response
    input [ 3:0] bid,
    input [ 1:0] bresp,
    input        bvalid,
    output       bready,

    /*SRAM SIGNALS*/
    //Inst SRAM
    input         inst_sram_req,
    input         inst_sram_wr,
    input  [ 1:0] inst_sram_size,
    input  [31:0] inst_sram_addr,
    input  [ 3:0] inst_sram_wstrb,
    input  [31:0] inst_sram_wdata,
    output        inst_sram_addr_ok,
    output        inst_sram_data_ok,
    output [31:0] inst_sram_rdata,

    //Data SRAM
    input         data_sram_req,
    input         data_sram_wr,
    input  [ 1:0] data_sram_size,
    input  [31:0] data_sram_addr,
    input  [ 3:0] data_sram_wstrb,
    input  [31:0] data_sram_wdata,
    output        data_sram_addr_ok,
    output        data_sram_data_ok,
    output [31:0] data_sram_rdata

);

/*Some signals remain constant*/
//Read request channel
assign arlen   = 8'b0;
assign arburst = 2'b01;
assign arlock  = 2'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;

//Write request channel
assign awid    = 4'h1;
assign awlen   = 8'b0;
assign awburst = 2'b01;
assign awlock  = 2'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;

//Write data channel
assign wlast = 1'b1;
assign wid   = 4'h1;

//State Machine Parameter
parameter WAIT_REQ    =   10'b0000000001;
parameter RECV_REQ    =   10'b0000000010;
parameter SEND_W_ADDR =   10'b0000000100;
parameter SEND_DATA   =   10'b0000001000;
parameter WAIT_W_RES  =   10'b0000010000;
parameter RECV_W_RES  =   10'b0000100000;
parameter RECV_INSTR_REQ = 10'b0001000000;
parameter RECV_DATAR_REQ = 10'b0010000000;
parameter RECV_INSTR_RES = 10'b0100000000;
parameter RECV_DATAR_RES = 10'b1000000000;
parameter SEN_REQ        = 10'b1100000000;

/*--------------The first state machine ---> write request & write data-------*/

//Write request & write response
reg [9:0] wreq_cstate;
reg [9:0] wreq_nstate;
reg [9:0] wres_cstate;
reg [9:0] wres_nstate;

//We perhaps send two issues. ---> avoid addr changing!
reg write_num;
always @(posedge aclk) begin
    if(~aresetn) begin
        write_num <= 1'b0;
    end
    else if(wreq_cstate == RECV_REQ && wres_cstate == RECV_W_RES) begin
        write_num <= write_num;
    end
    else if(wreq_cstate == RECV_REQ && write_num == 1'b0) begin
        write_num <= write_num + 1'd1;
    end
    else if(wres_cstate == RECV_W_RES && write_num == 1'b1) begin
        write_num <= write_num - 1'd1;
    end
end


//The first para
always @(posedge aclk) begin
    if(~aresetn) begin
        wreq_cstate <= WAIT_REQ;
    end
    else begin
        wreq_cstate <= wreq_nstate;
    end
end

//The second para
always @(*) begin
    case(wreq_cstate)
        WAIT_REQ:
            if(data_sram_req && data_sram_wr && write_num != 1'd1) begin
                wreq_nstate = RECV_REQ;
            end else begin
                wreq_nstate = WAIT_REQ;
            end
        RECV_REQ:
            wreq_nstate = SEND_W_ADDR;
        SEND_W_ADDR:
            if(awvalid & awready) begin
                wreq_nstate = SEND_DATA;
            end else begin
                wreq_nstate = SEND_W_ADDR;
            end
        SEND_DATA:
            if(wready & wvalid) begin
                wreq_nstate = WAIT_REQ;
            end else begin
                wreq_nstate = SEND_DATA;
            end
        default:
            wreq_nstate = WAIT_REQ;
    endcase
end

//Third para
reg [31:0] awaddr_r;
reg [ 2:0] awsize_r;
reg [31:0] wdata_r;
reg [ 3:0] wstrb_r;

always @(posedge aclk) begin
    if(data_sram_req && data_sram_wr && write_num != 1'd1) begin
        awaddr_r <= data_sram_addr;
        awsize_r <= {1'b0, data_sram_size};
        wdata_r  <= data_sram_wdata;
        wstrb_r  <= data_sram_wstrb;
    end
end

reg awvalid_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        awvalid_r <= 1'b0;
    end else if(wreq_cstate == SEND_W_ADDR && wreq_nstate != SEND_DATA) begin
        awvalid_r <= 1'b1;
    end else if(wreq_cstate == SEND_W_ADDR && wreq_nstate == SEND_DATA) begin
        awvalid_r <= 1'b0;
    end else begin
        awvalid_r <= 1'b0;
    end
end

reg wvalid_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        wvalid_r <= 1'b0;
    end else if(wreq_cstate == SEND_DATA && wreq_nstate != WAIT_REQ) begin
        wvalid_r <= 1'b1;
    end else if(wreq_cstate == SEND_DATA && wreq_nstate == WAIT_REQ) begin
        wvalid_r <= 1'b0;
    end else begin
        wvalid_r <= 1'b0;
    end
end

assign awaddr  = awaddr_r;
assign awsize  = awsize_r;
//When reset ---> awvalid = 0. When there is req, we set awvalid =  1
assign awvalid = awvalid_r; 
assign wdata   = wdata_r;
assign wstrb   = wstrb_r;
assign wvalid  = wvalid_r;

/*---------------------The second state machine ---> write response-----*/

//The first para
always @(posedge aclk) begin
    if(~aresetn) begin
        wres_cstate <= WAIT_W_RES;
    end else begin
        wres_cstate <= wres_nstate;
    end
end 

//The second para
always @(*) begin
    case(wres_cstate)
        WAIT_W_RES:
            if(bvalid && bready && write_num != 1'b0) begin
                wres_nstate = RECV_W_RES;
            end else begin
                wres_nstate = WAIT_W_RES;
            end
        RECV_W_RES:
            wres_nstate = WAIT_W_RES;
        default:
            wres_nstate = WAIT_W_RES;
    endcase
end

//The third para
//assign bready = aresetn && (wres_cstate == WAIR_RES);
reg bready_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        bready_r <= 1'b0;
    end else if(wres_cstate == WAIT_W_RES && wres_nstate != RECV_W_RES) begin
        bready_r <= 1'b1;
    end else if(wres_cstate == WAIT_W_RES && wres_nstate == RECV_W_RES) begin
        bready_r <= 1'b0;
    end else begin
        bready_r <= 1'b0;
    end
end
assign bready = bready_r;

/*------------------------The third state machine ---> Read request-------*/
reg id0_rnum;
reg id1_rnum;

reg [9:0] rreq_cstate;
reg [9:0] rreq_nstate;
reg [9:0] rres_cstate;
reg [9:0] rres_nstate;

always @(posedge aclk) begin
    if(~aresetn) begin
        id0_rnum <= 1'b0;
    end else if(rreq_cstate == RECV_INSTR_REQ && rres_cstate == RECV_INSTR_RES) begin
        id0_rnum <= id0_rnum;
    end else if(rreq_cstate == RECV_INSTR_REQ && id0_rnum == 1'b0) begin
        id0_rnum <= id0_rnum + 1'd1;
    end else if(rres_cstate == RECV_INSTR_RES && id0_rnum == 1'b1) begin
        id0_rnum <= id0_rnum - 1'd1;
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        id1_rnum <= 1'b0;
    end else if(rreq_cstate == RECV_DATAR_REQ && rres_cstate == RECV_DATAR_RES) begin
        id1_rnum <= id1_rnum;
    end else if(rreq_cstate == RECV_DATAR_REQ) begin
        id1_rnum <= id1_rnum + 1'd1;
    end else if(rres_cstate == RECV_DATAR_RES) begin
        id1_rnum <= id1_rnum - 1'd1;
    end
end

//The first para
always @(posedge aclk) begin
    if(~aresetn) begin
        rreq_cstate <= WAIT_REQ;
    end else begin
        rreq_cstate <= rreq_nstate;
    end
end
//The second para
always @(*) begin
    case(rreq_cstate)
        WAIT_REQ:
            //Note: data read is priority to inst read
            if(data_sram_req && ~data_sram_wr && id1_rnum != 1'd1) begin
                rreq_nstate = RECV_DATAR_REQ;
            end
            else if(inst_sram_req && ~inst_sram_wr && id0_rnum != 1'd1) begin
                rreq_nstate = RECV_INSTR_REQ;
            end else begin
                rreq_nstate = WAIT_REQ;
            end
        RECV_DATAR_REQ:
            rreq_nstate = SEN_REQ;
        RECV_INSTR_REQ:
            rreq_nstate = SEN_REQ;
        SEN_REQ:
            if(arvalid & arready) begin
                rreq_nstate = WAIT_REQ;
            end else begin
                rreq_nstate = SEN_REQ;
            end
        default:
            rreq_nstate = WAIT_REQ;
    endcase
end
//The third para
reg [3:0] arid_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        arid_r <= 4'b0;
    end else if(rreq_cstate == RECV_DATAR_REQ) begin
        arid_r <= 4'h1;
    end else if(rreq_cstate == RECV_INSTR_REQ) begin
        arid_r <= 4'h0;
    end
end

reg [31:0] inst_araddr_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        inst_araddr_r <= 32'b0;
    end else if(inst_sram_req && ~inst_sram_wr && id0_rnum != 1'd1) begin
        inst_araddr_r <= inst_sram_addr;
    end 
end

reg [ 2:0] inst_arsize_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        inst_arsize_r <= 3'b0;
    end else if(inst_sram_req && ~inst_sram_wr && id0_rnum != 1'd1) begin
        inst_arsize_r <= {1'b0, inst_sram_size};
    end
end

reg [31:0] data_araddr_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        data_araddr_r <= 32'b0;
    end else if(data_sram_req && ~data_sram_wr && id1_rnum != 1'd1) begin
        data_araddr_r <= data_sram_addr;
    end
end

reg  [ 2:0] data_arsize_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        data_arsize_r <= 3'b0;
    end else if(data_sram_req && ~data_sram_wr && id1_rnum != 1'd1) begin
        data_arsize_r <= {1'b0, data_sram_size};
    end
end

reg arvalid_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        arvalid_r <= 1'b0;
    end else if(rreq_cstate == SEN_REQ && rreq_nstate != WAIT_REQ) begin
        arvalid_r <= 1'b1;
    end else if(rreq_cstate == SEN_REQ && rreq_nstate == WAIT_REQ) begin
        arvalid_r <= 1'b0;
    end else begin
        arvalid_r <= 1'b0;
    end
end 

assign arid = arid_r;
assign araddr = {32{arid == 4'b0}} & inst_araddr_r |
                {32{arid == 4'h1}} & data_araddr_r;
assign arsize = {3{arid == 4'b0}} & inst_arsize_r |
                {3{arid == 4'b0}} & data_arsize_r;
assign arvalid = arvalid_r;

/*-------------------The fourth state machie ---> read responze TO DO YOUR CODE HERE!!!----*/

//The first para
always @(posedge aclk) begin
    if(~aresetn) begin
        rres_cstate <= WAIT_W_RES;
    end else begin
        rres_cstate <= rres_nstate;
    end
end 

//The second para
always@(*) begin
	case(rres_cstate)
	WAIT_W_RES:
        if(rvalid && rready && id1_rnum != 1'b0 && rid == 4'b1) begin
			rres_nstate = RECV_DATAR_RES;
		end
		else if(rvalid && rready && id0_rnum != 1'b0 && rid == 4'b0) begin
			rres_nstate = RECV_INSTR_RES;
		end
		else begin
			rres_nstate = WAIT_W_RES;
		end
	RECV_DATAR_RES: 
    	if(rvalid && rready && id0_rnum != 1'b0 && rid == 4'b0) begin
			rres_nstate = RECV_INSTR_RES;
		end
        else begin    
            rres_nstate = WAIT_W_RES;
        end
	RECV_INSTR_RES:
	   if(rvalid && rready && id1_rnum != 1'b0 && rid == 4'b1) begin
			rres_nstate = RECV_DATAR_RES;
	   end
	   else begin
            rres_nstate = WAIT_W_RES;
       end
	default:
		rres_nstate = WAIT_W_RES;
	endcase
end

//The third para
reg rready_r;
always @(posedge aclk) begin
    if(~aresetn) begin
        rready_r <= 1'b0;
    end else if(rres_cstate == WAIT_W_RES && (rres_nstate != RECV_DATAR_RES || rres_nstate != RECV_INSTR_RES)) begin
        rready_r <= 1'b1;
    end else if(rres_cstate == WAIT_W_RES && (rres_nstate == RECV_DATAR_RES || rres_nstate == RECV_INSTR_RES)) begin
        rready_r <= 1'b0;
    end else begin
        rready_r <= 1'b0;
    end
end
assign rready = rready_r;

//Sram interface
reg [31:0] res_rdata;
always@(posedge aclk) begin
	if(rready && rvalid) begin
		res_rdata <= rdata;
    end
end

assign inst_sram_addr_ok = (rreq_cstate == RECV_INSTR_REQ);
assign data_sram_addr_ok = (wreq_cstate == RECV_REQ) || (rreq_cstate == RECV_DATAR_REQ);
assign inst_sram_data_ok = (rres_cstate == RECV_INSTR_RES);
assign data_sram_data_ok = (wres_cstate == RECV_W_RES) || (rres_cstate == RECV_DATAR_RES);
assign inst_sram_rdata = res_rdata;
assign data_sram_rdata = res_rdata;
endmodule //transfer_bridge