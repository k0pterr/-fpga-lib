//------------------------------------------------------------------------------
//
//    ANB common stuff
//
//
//------------------------------------------------------------------------------

`include "common.svh"
`include "cfg_params_generated.svh"

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
//     ANB Address Channel Interface
//
interface anb_addr_channel_if
#(
    parameter type ADDR_T = logic,
    parameter type LEN_T  = logic
);

ADDR_T   addr;    
LEN_T    len;     
logic    avalid;     
logic    aready;     

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
interface anb_wr_if
#(
    parameter type ADDR_T = logic,
    parameter type LEN_T  = logic,
    parameter type DATA_T = logic
);
    
ADDR_T   addr;    
LEN_T    len;     
logic    avalid;     
logic    aready;     

DATA_T   data;   
logic    last;       
logic    valid;      
logic    ready;   


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
interface anb_rd_if
#(
    parameter type ADDR_T = logic,
    parameter type LEN_T  = logic,
    parameter type DATA_T = logic
);

ADDR_T  addr;
LEN_T   len;
logic   avalid;
logic   aready;

DATA_T  data;
logic   last;
logic   valid;
logic   ready;

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
    parameter N = 1,
    parameter type ADDR_T = logic,
    parameter type LEN_T  = logic,
    parameter type DATA_T = logic
);

typedef logic [       clog2(N)-1:0] rd_id_t;
typedef logic [$bits(DATA_T)/8-1:0] data_be_t;

// Address channel
rd_id_t  aid;
ADDR_T   addr;
LEN_T    len;
logic    avalid;
logic    aready;


//  Data channel
rd_id_t    id;  
DATA_T     data;
data_be_t  strb;
logic      valid;     // slave valid
logic      ready;     // slave ready
logic      last;

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

