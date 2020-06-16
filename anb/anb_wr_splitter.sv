//------------------------------------------------------------------------------
//
//
//
//
//------------------------------------------------------------------------------

`include "common.svh"

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
//   
//
module automatic anb_wr_splitter_m
#(
    parameter type ADDR_T,
    parameter type LEN_T,
    parameter type DATA_T
)
(
    input  logic   clk,
    input  logic   rst,
    
    anb_addr_channel_if.s    m_a,
    anb_addr_channel_if.m    s_a,
    
    anb_data_channel_if.s    m_d,
    anb_data_channel_if.m    s_d
);
    
//------------------------------------------------------------------------------
//
//    Settings
//
localparam PAGE_SIZE  = 4096;                       // bytes    
localparam PCIE_DW_W  = 32;                         // bits
localparam PCIE_BYTES = PCIE_DW_W/8;                // bytes
localparam PAGE_DWC   = PAGE_SIZE/PCIE_BYTES;       // PCIe DWs
localparam ANB_DWC    = $bits(DATA_T)/PCIE_DW_W;    // ANB data bus Double Word Count (PCIe DWs)
localparam ANB_DWC_W  = clog2(ANB_DWC);             //
localparam ANB_BC     = $bits(DATA_T)/8;            // ANB data bus byte count
localparam ANB_BC_W   = clog2(ANB_BC);              //
    
    
//------------------------------------------------------------------------------
//
//    Types
//
typedef struct packed
{
    ADDR_T  addr;    
    LEN_T   len;     
}
adata_t;

typedef struct packed
{
    DATA_T data;   
    logic last;       
}
ddata_t;

typedef struct
{
    logic   valid;
    logic   ready;
    adata_t data;
}
addr_ch_t;

typedef struct
{
    logic      valid;
    logic      ready;
    ddata_t    data;    
}
data_ch_t;

typedef enum logic [1:0]
{
    cbfsmPATH,
    cbfsmSEG
}
control_block_fsm_t;

//typedef logic [clog2(PCIE_BYTES)-1:0] dw_byte_addr_t;
typedef logic [ANB_DWC_W-1:0] anb_dwc_t;
typedef logic [ ANB_BC_W-1:0] anb_bc_t;

typedef logic [clog2(PAGE_SIZE)-1:0] inpage_addr_t;
typedef logic [ bits(PAGE_SIZE)-1:0] seg_len_t;
typedef logic [ clog2(PAGE_DWC)-1:0] seg_len_dw_t;

//------------------------------------------------------------------------------
//
//    Objects
//
addr_ch_t           ars_in;           // Address (channel) Register Slice Input
addr_ch_t           ars_out;          // Address (channel) Register Slice Output
                    
data_ch_t           drs_in;           // Data (channel) Register Slice Input
data_ch_t           drs_out;          // Data (channel) Register Slice Output

control_block_fsm_t cbfsm = cbfsmPATH;
control_block_fsm_t cbfsm_next;

ADDR_T              curr_addr;
ADDR_T              curr_addr_reg;
LEN_T               rlen;               // residual length
seg_len_t           max_seg_len;
seg_len_t           curr_len;
anb_dwc_t           ds_offset;          // 'ds' means 'data shifter'
anb_dwc_t           ds_offset_reg;      // 'ds' means 'data shifter'
anb_dwc_t           ds_last_word_len;   // 'ds' means 'data shifter'
                    
logic               avalid = 0;

//------------------------------------------------------------------------------
//
//    Functions and tasks
//
function ADDR_T get_boundary(input ADDR_T addr, int bound);

    return (addr + bound) & ~(bound - 1);

endfunction

//------------------------------------------------
function seg_len_t seg_len(input inpage_addr_t addr);
    
    return PAGE_SIZE - addr;
    
endfunction
//------------------------------------------------
function seg_len_dw_t seg_len_dw(input inpage_addr_t addr);
    
    return ( PAGE_SIZE - (addr & ~2'b11) )/PCIE_BYTES;
    
endfunction
//------------------------------------------------
function anb_dwc_t last_word_dw_len(input anb_bc_t len);

    //return len/ANB_BC_W + |len[0 +:ANB_BC_W];
    return len/PCIE_BYTES + |len[0 +:clog2(PCIE_BYTES)];

endfunction
//------------------------------------------------
//function offset_t offset(input dw_byte_addr_t addr,
//                         input LEN_T          len);
//endfunction
//------------------------------------------------
//task gen_seg(input ADDR_T addr, input LEN_T len);
//
//    ADDR_T    curr_addr       = addr;
//    ADDR_T    next_addr;
//    seg_len_t max_seg_len;
//    seg_len_t curr_len;
//    int       ds_offset       = 0;
//    int       next_ds_offset;
//    int       ds_len;
//    int       N               = 0;
//
//    enum logic [1:0] { PATH, SEG } fsm = PATH;
//
//    $display("");
//    $display("[%t], -------- Start processing ---------", $realtime);
//
//    forever begin
//
//        case(fsm)
//        //----------------------------------------
//        PATH: begin
//            max_seg_len    = seg_len(curr_addr);
//            ds_offset      = 0;
//            next_ds_offset = ANB_DWC - seg_len_dw(curr_addr)%ANB_DWC;
//            ds_len         = seg_len_dw(curr_addr);
//            if(max_seg_len) begin
//                if(max_seg_len < len) begin
//                    curr_len = max_seg_len;
//                    fsm      = SEG;
//                end
//                else begin
//                    curr_len = len;
//                end
//            end
//            else begin
//                next_addr = curr_addr + PAGE_SIZE;
//                len      -= PAGE_SIZE;
//            end
//
//            next_addr  = curr_addr + curr_len;
//            len       -= curr_len;
//
//
//        end
//        //----------------------------------------
//        SEG: begin
//            ds_offset   = next_ds_offset;
//
//            if(len > PAGE_SIZE) begin
//                curr_len   = PAGE_SIZE;
//                next_addr  = curr_addr + PAGE_SIZE;
//                len       -= PAGE_SIZE;
//            end
//            else begin
//                curr_len = len;
//                len      = 0;
//            end
//
//
//        end
//        //----------------------------------------
//        endcase
//
//
//        $display("[%t], Seg%1d, curr_addr: %x, max_seg_len: %5d, curr_len: %5d, ds_offset: %1d, ds_len: %4d, next_addr: %x, next_ds_offset: %1d, len: %5d",
//                 $realtime,
//                 N++,
//                 curr_addr,
//                 max_seg_len,
//                 curr_len,
//                 ds_offset,
//                 ds_len,
//                 next_addr,
//                 next_ds_offset,
//                 len);
//
//        curr_addr = next_addr;
//
//        if(!len) begin
//            $display("[%t], -------- End processing ---------\n ", $realtime, );
//            break;
//        end
//    end
//
//endtask

//------------------------------------------------

//initial begin
//
//    $display("[%t], seg_len(64'hfffa_e000): %4d", $realtime, seg_len(64'hfffa_e000));
//    $display("[%t], seg_len(64'hfffa_1001): %4d", $realtime, seg_len(64'hfffa_1001));
//    $display("[%t], seg_len(64'hfffa_1ffa): %4d", $realtime, seg_len(64'hfffa_1ffa));
//    $display("[%t], seg_len(64'hfffa_1ff2): %4d", $realtime, seg_len(64'hfffa_1ff2));
//    $display("[%t], seg_len(64'hfffa_1ff4): %4d", $realtime, seg_len(64'hfffa_1ff4));
//    $display("[%t], seg_len(64'hfffa_100f): %4d", $realtime, seg_len(64'hfffa_100f));
//    $display("");
//    $display("[%t], seg_len_dw(64'hfffa_e000): %4d", $realtime, seg_len_dw(64'hfffa_e000));
//    $display("[%t], seg_len_dw(64'hfffa_1001): %4d", $realtime, seg_len_dw(64'hfffa_1001));
//    $display("[%t], seg_len_dw(64'hfffa_1ffa): %4d", $realtime, seg_len_dw(64'hfffa_1ffa));
//    $display("[%t], seg_len_dw(64'hfffa_1ff2): %4d", $realtime, seg_len_dw(64'hfffa_1ff2));
//    $display("[%t], seg_len_dw(64'hfffa_1ff4): %4d", $realtime, seg_len_dw(64'hfffa_1ff4));
//    $display("[%t], seg_len_dw(64'hfffa_100f): %4d", $realtime, seg_len_dw(64'hfffa_100f));
//
////  gen_seg(64'hfffa_1ffa, 16);
////  gen_seg(64'hfffa_1ffa, 16+4096);
////  gen_seg(64'hfffa_1ffc, 5000);
////
////  $stop(2);
//
//end


//------------------------------------------------------------------------------
//
//    Logic
//

always_comb begin
    ars_in.valid     = m_a.avalid;
    m_a.aready       = ars_in.ready;
    ars_in.data.addr = m_a.addr;
    ars_in.data.len  = m_a.len;
    
    s_a.avalid       = ars_out.valid;
    ars_out.ready    = s_a.aready;
    s_a.addr         = ars_out.data.addr;
    s_a.len          = ars_out.data.len;
end

always_comb begin
    drs_in.valid     = m_d.valid;
    m_d.ready        = drs_in.ready;
    drs_in.data.data = m_d.data;
    drs_in.data.last = m_d.last;

    s_d.valid        = drs_out.valid;
    drs_out.ready    = s_d.ready;
    s_d.data         = drs_out.data.data;
    s_d.last         = drs_out.data.last;
end

//----------------------------------------------------------
//
//    Control Block FSM
//
always_ff @(posedge clk) begin
    cbfsm <= cbfsm_next;
end

always_comb begin
    cbfsm_next = cbfsm;
    
    case(cbfsm)
    //--------------------------------------------
    cbfsmPATH: begin
        max_seg_len = seg_len(ars_out.data.addr);
        if(ars_out.valid) begin
            if(max_seg_len) begin  // addr not aligned to page boundary
                if(max_seg_len < ars_out.data.len) begin
                    cbfsm_next = cbfsmSEG;
                end
            end
        end
    end
    //--------------------------------------------
    cbfsmSEG: begin
        if(rlen == curr_len) begin
            cbfsm_next = cbfsmPATH;
        end
    end
    //--------------------------------------------
    endcase
        
end

always_comb begin
    avalid = 0;
    case(cbfsm)
    //--------------------------------------------
    cbfsmPATH: begin
        curr_addr        = ars_out.data.addr;
        curr_len         = cbfsm_next == cbfsmSEG ? max_seg_len : ars_out.data.len;
        ds_offset        = 0;
        ds_last_word_len = 'x; // last_word_dw_len(curr_len);
        avalid           = cbfsm_next == cbfsmSEG ? 1 : ars_out.valid;
    end
    //--------------------------------------------
    cbfsmSEG: begin
        avalid    = 1;                 // ???
        curr_addr = curr_addr_reg;
        ds_offset = ds_offset_reg;
        if(rlen < PAGE_SIZE) begin
            curr_len = rlen;
        end
        else begin
            curr_len = PAGE_SIZE;
        end
        ds_last_word_len = last_word_dw_len(curr_len);
        
    end
    //--------------------------------------------
    endcase
end

always_ff @(posedge clk) begin
    case(cbfsm)
    //--------------------------------------------
    cbfsmPATH: begin
        curr_addr_reg <= ars_out.data.addr + curr_len;
        //ds_offset_reg <= ANB_DWC - seg_len_dw(ars_out.data.addr)%ANB_DWC;
        ds_offset_reg <= seg_len_dw(ars_out.data.addr)%ANB_DWC;
        if(ars_out.valid) begin
            rlen <= ars_out.data.len - curr_len;
        end
        
    end
    //--------------------------------------------
    cbfsmSEG: begin
        if(avalid) begin
            curr_addr_reg <= curr_addr_reg + curr_len;
            rlen          <= rlen < PAGE_SIZE ? rlen - curr_len : rlen - PAGE_SIZE;
        end
    end
    //--------------------------------------------
    endcase
end

int N = 0;
always_ff @(posedge clk) begin
    if(avalid) begin
        $display("[%t], SEG%1d, fsm: %x -> %x curr_addr: %x, curr_len: %5d, rlen: %5d, ds_offset: %1d, ds_last_word_len: %1d", 
                 $realtime, 
                 N++,
                 cbfsm,
                 cbfsm_next,
                 curr_addr,
                 curr_len,
                 cbfsm == cbfsmPATH ? ars_out.data.len - curr_len : rlen < PAGE_SIZE ? rlen - curr_len : rlen - PAGE_SIZE,
                 ds_offset,
                 //ds_offset_reg,
                 ds_last_word_len );
    end
end



//------------------------------------------------------------------------------
//
//    Instances
//
reg_stage_m
#(
    .DATA_T ( adata_t )
)
addr_ch_reg_slice
(
    .clk       ( clk           ),
    .valid_src ( ars_in.valid  ),
    .ready_src ( ars_in.ready  ),
    .src       ( ars_in.data   ),
    .valid_dst ( ars_out.valid ),
    .ready_dst ( ars_out.ready ),
    .dst       ( ars_out.data  )
);
//------------------------------------------------------------------------------
reg_stage_m
#(
    .DATA_T ( ddata_t )
)
data_ch_reg_slice
(
    .clk       ( clk           ),
    .valid_src ( drs_in.valid  ),
    .ready_src ( drs_in.ready  ),
    .src       ( drs_in.data   ),
    .valid_dst ( drs_out.valid ),
    .ready_dst ( drs_out.ready ),
    .dst       ( drs_out.data  )
);
//------------------------------------------------------------------------------

endmodule : anb_wr_splitter_m
//------------------------------------------------------------------------------

