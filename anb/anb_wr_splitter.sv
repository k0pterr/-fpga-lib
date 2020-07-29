//------------------------------------------------------------------------------
//
//     Project:     Any
//
//     Description: ANB Write Transaction 4k Memory Page Boundary Splitter. 
//
//     Version: 1.0
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
    parameter type ADDR_T = logic [ 63:0],
    parameter type LEN_T  = logic [ 13:0],
    parameter type DATA_T = logic [127:0]
)
(
    input  logic           clk,
    input  logic           rst,

    anb_addr_channel_if.s  m_a,
    anb_addr_channel_if.m  s_a,

    anb_data_channel_if.s  m_d,
    anb_data_channel_if.m  s_d
);

//------------------------------------------------------------------------------
//
//    Settings
//
localparam PAGE_SIZE        = 4096;                       // bytes
localparam PCIE_DW_W        = 32;                         // bits
localparam PCIE_BYTES       = PCIE_DW_W/8;                // bytes
localparam PCIE_BYTE_ADDR_W = clog2(PCIE_BYTES);          // 
localparam PAGE_DWC         = PAGE_SIZE/PCIE_BYTES;       // PCIe DWs
localparam ANB_DWC          = $bits(DATA_T)/PCIE_DW_W;    // ANB data bus Double Word Count (PCIe DWs)
localparam ANB_DWC_W        = clog2(ANB_DWC);             //
localparam ANB_BC           = $bits(DATA_T)/8;            // ANB data bus byte count
localparam ANB_BC_W         = clog2(ANB_BC);              //

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

//typedef struct
//{
//    ddata_t  tail;
//    ddata_t  head;
//    logic    push;
//    logic    pop;
//    logic    full;
//    logic    empty;
//    logic    wr_rst_busy;
//    logic    rd_rst_busy;
//}
//drs_t;

typedef enum logic [0:0]
{
    afsmIDLE,
    afsmSEG
}
address_channel_fsm_t;

typedef enum logic [0:0]
{
    dfsmIDLE,
    dfsmRUN
}
data_channel_fsm_t;

typedef logic [             ANB_DWC_W-1:0] anb_dwc_t;
typedef logic [              ANB_BC_W-1:0] anb_bc_t;
typedef logic [      clog2(PAGE_SIZE)-1:0] inpage_addr_t;
typedef logic [       bits(PAGE_SIZE)-1:0] seg_len_t;
typedef logic [       clog2(PAGE_DWC)-1:0] seg_len_dw_t;
typedef logic [bits(PAGE_SIZE/ANB_BC)-1:0] seg_len_anbw_t;
typedef logic [      PCIE_BYTE_ADDR_W-1:0] pcie_byte_addr_t;

typedef struct packed
{
    logic            seg_tail_flag; // 'tail': part of the last ANB word in segment that is not fit to current transaction
    logic            seg;           // set if transaction cross 4k page boundary
    seg_len_t        len;
    anb_dwc_t        last_word_len;
    anb_dwc_t        ds_offset;
    pcie_byte_addr_t addr_offset;
`ifdef SIMULATOR
    ADDR_T           addr;
    LEN_T            task_len;
`endif
}
ds_control_item_t;

typedef struct
{
    ds_control_item_t  tail;
    ds_control_item_t  head;
    logic              push;
    logic              pop;
    logic              full;
    logic              empty;
    logic              wr_rst_busy;
    logic              rd_rst_busy;
}
dsci_queue_t;

//------------------------------------------------------------------------------
//
//    Objects
//
addr_ch_t              ars_in;                // Address (channel) Register Slice Input
addr_ch_t              ars_out;               // Address (channel) Register Slice Output
                                              
data_ch_t              drs_in;                // Data (channel) Register Slice Input
data_ch_t              drs_out;               // Data (channel) Register Slice Output

//drs_t                  drs;

                                              
address_channel_fsm_t  afsm = afsmIDLE;       
address_channel_fsm_t  afsm_next;             
address_channel_fsm_t  afsm_next1;            
                                              
data_channel_fsm_t     dfsm = dfsmIDLE;       
data_channel_fsm_t     dfsm_next;             
                                              
ADDR_T                 curr_addr;             
ADDR_T                 curr_addr_reg;         
logic                  seg_tail_flag_reg = 0;
LEN_T                  rlen;                  // residual length
seg_len_t              max_seg_len;
seg_len_t              curr_len;
seg_len_t              curr_len_reg;
seg_len_anbw_t         curr_len_anbw;         // ANB  word count send to data shifter
seg_len_anbw_t         curr_len_anbw_cnt = 0;
anb_dwc_t              ds_offset;             // 'ds' means 'data shifter'
anb_dwc_t              ds_offset_reg;         // 'ds' means 'data shifter'
anb_dwc_t              ds_last_word_len;      // 'ds' means 'data shifter'
logic                  aready;
dsci_queue_t           dsci_queue;

anb_data_channel_if #( .DATA_T( DATA_T) ) ds_data_in();
anb_data_channel_if #( .DATA_T( DATA_T) ) ds_data_out();

assign afsm_next1 = afsm_next;

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

    return len/PCIE_BYTES + |len[0 +:clog2(PCIE_BYTES)];

endfunction
//------------------------------------------------
function seg_len_anbw_t seg_len_anbw(input seg_len_t len);

    return len/ANB_BC + |len[ANB_BC_W-1:0];

endfunction

//------------------------------------------------------------------------------
//
//    Logic
//
always_comb begin
    ars_in.valid     = m_a.avalid;
    m_a.aready       = ars_in.ready;
    ars_in.data.addr = m_a.addr;
    ars_in.data.len  = m_a.len;

    s_a.avalid       = dsci_queue.push;
    ars_out.ready    = aready;
    s_a.addr         = curr_addr;
    s_a.len          = curr_len;
end

always_comb begin
    drs_in.valid      = m_d.valid;
    m_d.ready         = drs_in.ready;
    drs_in.data.data  = m_d.data;
    drs_in.data.last  = m_d.last;

    s_d.valid         = ds_data_out.valid;
    ds_data_out.ready = s_d.ready;
    s_d.data          = ds_data_out.data;
    s_d.last          = ds_data_out.last;
end

//--------------------------------------------------------------------
//
//    Address Channel FSM
//
always_ff @(posedge clk) begin
    afsm <= afsm_next;
end

always_comb begin : afsm_comb_b
    
    automatic address_channel_fsm_t next;
    
    next = afsm;

    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        if(ars_out.valid && aready) begin
            if(ars_out.data.len > max_seg_len ) begin
                next = afsmSEG;
            end
        end
    end
    //--------------------------------------------
    afsmSEG: begin : afsmSEG_b
        if(!dsci_queue.full && rlen && s_a.aready) begin
            if(rlen <= PAGE_SIZE) begin
                next = afsmIDLE;
            end
        end
    end : afsmSEG_b
    //--------------------------------------------
    endcase
    
    afsm_next = next;

end : afsm_comb_b
//--------------------------------------------------------------------
always_comb begin
    
    automatic logic push = 0;
    
    aready                        = s_a.aready && !dsci_queue.full && afsm == afsmIDLE;
    max_seg_len                   = seg_len(ars_out.data.addr);
    curr_addr                     = ars_out.data.addr;
    curr_len                      = afsm_next == afsmSEG ? min(ars_out.data.len, max_seg_len) : ars_out.data.len;

    dsci_queue.tail.addr_offset   = curr_addr[0 +: PCIE_BYTE_ADDR_W];
    dsci_queue.tail.ds_offset     = 0;
    dsci_queue.tail.last_word_len = 'x;
    dsci_queue.tail.len           = curr_len;
    dsci_queue.tail.seg           = afsm_next == afsmSEG;
    dsci_queue.tail.seg_tail_flag = afsm_next == afsmSEG && curr_addr[0 +: ANB_BC_W] >= PCIE_BYTES;
`ifdef SIMULATOR
    dsci_queue.tail.addr          = curr_addr;
    dsci_queue.tail.task_len      = curr_len;
`endif
    
    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        push = ars_out.valid && s_a.aready && !dsci_queue.full;
    end
    //--------------------------------------------
    afsmSEG: begin
        curr_addr = curr_addr_reg;
        if(rlen < PAGE_SIZE) begin
            curr_len = rlen;
        end
        else begin
            curr_len = PAGE_SIZE;
        end
        dsci_queue.tail.addr_offset   = 0;
        dsci_queue.tail.ds_offset     = ds_offset_reg;
        dsci_queue.tail.last_word_len = last_word_dw_len(curr_len);
        dsci_queue.tail.len           = curr_len;
        dsci_queue.tail.seg_tail_flag = afsm_next == afsmSEG ? seg_tail_flag_reg : 0;
    `ifdef SIMULATOR
        dsci_queue.tail.addr          = curr_addr;
        dsci_queue.tail.task_len      = curr_len;
    `endif
        push                          = s_a.aready && !dsci_queue.full; // aready;
    end
    //--------------------------------------------
    endcase
    
    dsci_queue.push = push;
end

always_ff @(posedge clk) begin
    case(afsm)
    //--------------------------------------------
    afsmIDLE: begin
        curr_addr_reg     <= ars_out.data.addr + curr_len;
        rlen              <= ars_out.data.len - curr_len;
        ds_offset_reg     <= seg_len_dw(ars_out.data.addr)%ANB_DWC;
        seg_tail_flag_reg <= afsm_next == afsmSEG && curr_addr[0 +: ANB_BC_W] >= PCIE_BYTES;
    end
    //--------------------------------------------
    afsmSEG: begin
        if(dsci_queue.push) begin
            curr_addr_reg <= curr_addr_reg + curr_len;
            rlen          <= rlen < PAGE_SIZE ? rlen - curr_len : rlen - PAGE_SIZE;
        end
    end
    //--------------------------------------------
    endcase
end

//--------------------------------------------------------------------
//
//    Data Channel FSM
//
always_ff @(posedge clk) begin
    dfsm <= dfsm_next;
end

always_comb begin : dfsm_comb_b

    automatic data_channel_fsm_t next = dfsm;
    
    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        if( !dsci_queue.empty && drs_out.valid && ds_data_in.ready ) begin
            next = dfsmRUN;
            if(curr_len_anbw == 1 && ds_data_in.valid && ds_data_in.ready) begin
                next = dfsmIDLE;
            end
        end
    end
    //--------------------------------------------
    dfsmRUN: begin
        if(ds_data_in.valid && ds_data_in.ready && curr_len_anbw_cnt == 1) begin
            next = dfsmIDLE;
        end
    end
    //--------------------------------------------
    endcase
    
    dfsm_next = next;
    
end : dfsm_comb_b
//--------------------------------------------------------------------

always_comb begin
    
    automatic logic            seg_tail_flag = dsci_queue.head.seg_tail_flag;
    automatic pcie_byte_addr_t addr_offset   = dsci_queue.head.addr_offset;
    
    ds_offset        = dsci_queue.head.ds_offset;
    ds_last_word_len = dsci_queue.head.last_word_len;
    
    if(dsci_queue.head.seg) begin
        curr_len_anbw = seg_len_anbw((seg_tail_flag ? addr_offset + ds_offset * PCIE_BYTES: ds_offset * PCIE_BYTES) + dsci_queue.head.len);
    end else
    begin
        curr_len_anbw = seg_len_anbw(addr_offset + ds_offset * PCIE_BYTES + dsci_queue.head.len);
    end
end

always_comb begin
    
    automatic logic valid = 0;
    automatic logic last  = 0;
    automatic logic ready = 0;
    
    ds_data_in.data  = drs_out.data.data;
    
    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        if( !dsci_queue.empty && drs_out.valid && curr_len_anbw == 1 ) begin
            last  = 1;
        end

        if( !dsci_queue.empty && drs_out.valid && ds_data_in.ready ) begin
            valid = 1;
            if( curr_len_anbw == 1 ) begin
                ready = dsci_queue.head.seg_tail_flag ? 0 : ds_data_in.ready;
            end
            else begin
                ready = ds_data_in.ready;
            end
        end
    end
    //--------------------------------------------
    dfsmRUN: begin
        ready = ds_data_in.ready;
        valid = drs_out.valid;
        
        if(valid ) begin
            if(curr_len_anbw_cnt == 1) begin
                last  = 1;
                ready = dsci_queue.head.seg_tail_flag ? 0 : ds_data_in.ready;
            end
        end
    end
    //--------------------------------------------
    endcase
    
    ds_data_in.valid = valid;
    ds_data_in.last  = last;
    drs_out.ready    = ready;
end

always_ff @(posedge clk) begin

    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        curr_len_anbw_cnt <= curr_len_anbw - 1;
    end
    //--------------------------------------------
    dfsmRUN: begin
        if(ds_data_in.valid && ds_data_in.ready) begin
            curr_len_anbw_cnt <= curr_len_anbw_cnt - 1;
        end
    end
    //--------------------------------------------
    endcase
end

always_comb begin
    
    automatic logic pop = 0;
    
    case(dfsm)
    //--------------------------------------------
    dfsmIDLE: begin
        if( !dsci_queue.empty && drs_out.valid  && ds_data_in.ready ) begin
            if(curr_len_anbw == 1) begin
                pop = 1;
            end
        end
    end
    //--------------------------------------------
    dfsmRUN: begin
        if(ds_data_in.valid && ds_data_in.ready && curr_len_anbw_cnt == 1) begin
            pop = 1;
        end
    end
    //--------------------------------------------
    endcase
    dsci_queue.pop = pop;
end

`ifdef SIMULATOR
int N = 0;
always_ff @(posedge clk) begin
    if(dsci_queue.push) begin
        $display("[%t], SEG%1d, fsm: %x -> %x curr_addr: %x, curr_len: %5d, curr_len_anbw: %4d, rlen: %5d, ds_offset: %1d, ds_last_word_len: %1d",
                 $realtime,
                 N++,
                 afsm,
                 afsm_next,
                 curr_addr,
                 curr_len,
                 curr_len_anbw,
                 afsm == afsmIDLE ? ars_out.data.len - curr_len : rlen < PAGE_SIZE ? rlen - curr_len : rlen - PAGE_SIZE,
                 ds_offset,
                 ds_last_word_len );
    end
    if(afsm_next == afsmIDLE) begin
        N = 0;
    end
end
`endif

//------------------------------------------------------------------------------
//
//    Instances
//
(* keep_hierarchy="yes" *)
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
(* keep_hierarchy="yes" *)
reg_stage2_m
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
//fifo_sc_m
//#(
//    .DATA_ITEM_TYPE ( ddata_t ),
//    .DEPTH          ( 32                ),
//    .MEMTYPE        ( "distributed"     )
//)
//reg_slice
//(
//    .clk         ( clk             ),
//    .rst         ( rst             ),
//    .tail        ( drs.tail        ),
//    .head        ( drs.head        ),
//    .push        ( drs.push        ),
//    .pop         ( drs.pop         ),
//    .full        ( drs.full        ),
//    .empty       ( drs.empty       ),
//    .wr_rst_busy ( drs.wr_rst_busy ),
//    .rd_rst_busy ( drs.rd_rst_busy )
//);
//
//assign drs.tail      = drs_in.data;
//assign drs.push      = drs_in.valid && !drs.full;
//assign drs_in.ready  = !drs.full;
//
//assign drs_out.data  = drs.head;
//assign drs_out.valid = !drs.empty;
//assign drs.pop       = drs_out.ready && !drs.empty;

//------------------------------------------------------------------------------
fifo_sc_m
#(
    .DATA_ITEM_TYPE ( ds_control_item_t ),
    .DEPTH          ( 32                ),
    .MEMTYPE        ( "distributed"     )
)
addr_queue
(
    .clk         ( clk                    ),
    .rst         ( rst                    ),
    .tail        ( dsci_queue.tail        ),
    .head        ( dsci_queue.head        ),
    .push        ( dsci_queue.push        ),
    .pop         ( dsci_queue.pop         ),
    .full        ( dsci_queue.full        ),
    .empty       ( dsci_queue.empty       ),
    .wr_rst_busy ( dsci_queue.wr_rst_busy ),
    .rd_rst_busy ( dsci_queue.rd_rst_busy )
);
//------------------------------------------------------------------------------
(* keep_hierarchy="yes" *)
anb_data_align_m
#(
    .DATA_W     ( ANB_BC     ),    // data units
    .MAX_OFFSET ( ANB_DWC    ),    // data units
    .SPAN       ( PCIE_BYTES )     // data unit size
)
data_shift
(
    .clk    ( clk              ),
    .offset ( ds_offset        ),
    .len    ( ds_last_word_len ),
    .m      ( ds_data_in       ),
    .s      ( ds_data_out      )
);

//------------------------------------------------------------------------------

endmodule : anb_wr_splitter_m
//------------------------------------------------------------------------------

