//------------------------------------------------------------------------------
//
//
//
//
//------------------------------------------------------------------------------

`include "common.svh"
`include "bmd_mc.svh"
`include "dpc_defs.svh"
`include "cfg_params_generated.svh"

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
//   
//
module automatic anb_wr_splitter_m
(
    input  logic   clk,
    input  logic   rst,
    
    anb_addr_channel_if.s    m_a,
    anb_addr_channel_if.m    s_a,
    
    anb_data_channel_if.s    m_d,
    anb_data_channel_if.m    s_d
);
    
import bmd_mc_defs::*;  
import dpc_defs::*;
    
//------------------------------------------------------------------------------
//
//    Settings
//

//------------------------------------------------------------------------------
//
//    Types
//
typedef struct packed
{
    smc_addr_t        addr;    
    task_data_len_t   len;     
}
adata_t;

typedef struct packed
{
    smc_data_t data;   
    logic      last;       
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

//------------------------------------------------------------------------------
//
//    Objects
//
addr_ch_t areg_slice_in;
addr_ch_t areg_slice_out;

data_ch_t dreg_slice_in;
data_ch_t dreg_slice_out;

//------------------------------------------------------------------------------
//
//    Functions and tasks
//

//------------------------------------------------------------------------------
//
//    Logic
//

always_comb begin
    areg_slice_in.valid     = m_a.avalid;
    m_a.aready              = areg_slice_in.ready;
    areg_slice_in.data.addr = m_a.addr;
    areg_slice_in.data.len  = m_a.len;
    
    s_a.avalid              = areg_slice_out.valid;
    areg_slice_out.ready    = s_a.aready;
    s_a.addr                = areg_slice_out.data.addr;
    s_a.len                 = areg_slice_out.data.len;
    
//  s_a.avalid  = m_a.avalid;
//  m_a.aready  = s_a.aready;
//  s_a.addr    = m_a.addr;
//  s_a.len     = m_a.len;
end

always_comb begin
    
    dreg_slice_in.valid     = m_d.valid;
    m_d.ready               = dreg_slice_in.ready;
    dreg_slice_in.data.data = m_d.data;
    dreg_slice_in.data.last = m_d.last;

    s_d.valid               = dreg_slice_out.valid;
    dreg_slice_out.ready    = s_d.ready;
    s_d.data                = dreg_slice_out.data.data;
    s_d.last                = dreg_slice_out.data.last;
    
    
//    s_d.valid = m_d.valid;
//    m_d.ready = s_d.ready;
//    s_d.data  = m_d.data;
//    s_d.last  = m_d.last;
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
    .clk       ( clk                  ),
    .valid_src ( areg_slice_in.valid  ),
    .ready_src ( areg_slice_in.ready  ),
    .src       ( areg_slice_in.data   ),
    .valid_dst ( areg_slice_out.valid ),
    .ready_dst ( areg_slice_out.ready ),
    .dst       ( areg_slice_out.data  )
);
//------------------------------------------------------------------------------
reg_stage_m
#(
    .DATA_T ( ddata_t )
)
data_ch_reg_slice
(
    .clk       ( clk                  ),
    .valid_src ( dreg_slice_in.valid  ),
    .ready_src ( dreg_slice_in.ready  ),
    .src       ( dreg_slice_in.data   ),
    .valid_dst ( dreg_slice_out.valid ),
    .ready_dst ( dreg_slice_out.ready ),
    .dst       ( dreg_slice_out.data  )
);
//------------------------------------------------------------------------------

endmodule : anb_wr_splitter_m
//------------------------------------------------------------------------------

