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
//     ANB Address Channel Interface
//
interface anb_addr_channel_if;

import bmd_mc_defs::*;
import dpc_defs::*;

smc_addr_t        addr;    
task_data_len_t   len;     
logic             avalid;     
logic             aready;     

modport m
(
    output addr,    
    output len,     
    output avalid,     
    input  aready     
);   

modport s
(
    input  addr,    
    input  len,     
    input  avalid,     
    output aready     
);   

endinterface : anb_addr_channel_if


//------------------------------------------------------------------------------
//
//     ANB Data Stream Byte-oriented Interface
//
interface anb_data_channel_if
#(
    parameter type DATA_T = logic
);

DATA_T  data;   
logic   last;       
logic   valid;      
logic   ready;   

modport m
(
    output data,   
    output last,       
    output valid,      
    input  ready
);   

modport s
(
    input  data,   
    input  last,       
    input  valid,      
    output ready
);   

endinterface : anb_data_channel_if
//------------------------------------------------------------------------------
//
//     ANB Write Interface
//
interface anb_wr_if;

import bmd_mc_defs::*;
import dpc_defs::*;

smc_addr_t        addr;    
task_data_len_t   len;     
logic             avalid;     
logic             aready;     

smc_data_t        data;   
logic             last;       
logic             valid;      
logic             ready;   


modport m
(
    output addr,    
    output len,     
    output avalid,     
    input  aready,     

    output data,   
    output last,       
    output valid,      
    input  ready
);   

modport s
(
    input  addr,    
    input  len,     
    input  avalid,     
    output aready,     

    input  data,   
    input  last,       
    input  valid,      
    output ready
);   

endinterface : anb_wr_if
//------------------------------------------------------------------------------
//
//     ANB Read Interface
//
interface anb_rd_if;

import bmd_mc_defs::*;
import dpc_defs::*;

smc_addr_t       addr;
task_data_len_t  len;
logic            avalid;
logic            aready;

smc_data_t       data;
logic            last;
logic            valid;
logic            ready;

modport m
(
    output addr,     
    output len,      
    output avalid,    
    input  aready,        

    input  data,     
    input  last,     
    input  valid,    
    output ready    
);

modport s
(
    input  addr,     
    input  len,      
    input  avalid,    
    output aready,        

    output data,     
    output last,     
    output valid,    
    input  ready    
);

endinterface : anb_rd_if
//------------------------------------------------------------------------------
//
//     ANB Read System Memory Controller interface
//
interface smc_rd_if
#(
    parameter N = 1
);

import bmd_mc_defs::*;    

typedef logic [clog2(N)-1:0] rd_id_t;


// Address channel
rd_id_t            aid;
smc_addr_t         addr;
smc_trn_max_len_t  len;
logic              avalid;
logic              aready;


//  Data channel
rd_id_t            id;  
smc_data_t         data;
smc_data_be_t      strb;
logic              valid;     // slave valid
logic              ready;     // slave ready
logic              last;

modport m
(
    output aid,
    output addr,
    output len,
    output avalid,
    input  aready,

    input  id,    
    input  data,  
    input  strb,  
    input  valid, 
    output ready, 
    input  last
);

modport s
(
    input  aid,
    input  addr,
    input  len,
    input  avalid,
    output aready,    

    output id,    
    output data,  
    output strb,  
    output valid, 
    input  ready, 
    output last
);

endinterface : smc_rd_if
//------------------------------------------------------------------------------

