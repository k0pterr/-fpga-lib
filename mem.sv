//------------------------------------------------------------------------------
//  project:       Any
//
//  modules:       sdp_distributed_ram_m
//                 distributed_reg_rom_m
//
//  description:   inferred memory modules
//------------------------------------------------------------------------------

//******************************************************************************
//******************************************************************************
module sdp_distributed_ram_m
                #(
                   parameter int ADDR_WIDTH,
                   parameter int WORD_WIDTH,
                   parameter     OUT_REGISTERED = "YES"  
                 )
(
    input  logic                  clk,
    
    //--- write port
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [WORD_WIDTH-1:0] data_in,
    
    //--- read port
    input  logic [ADDR_WIDTH-1:0] raddr,
    output logic [WORD_WIDTH-1:0] data_out
);

//==============================================================================
//    Settings
//==============================================================================

localparam RAM_SIZE = 2**ADDR_WIDTH;

//==============================================================================
//    Objects
//==============================================================================

(* ram_style="distributed" *)
logic [WORD_WIDTH-1:0] ram [RAM_SIZE];

//==============================================================================
//     Logic
//==============================================================================

//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if(we) begin
        ram[waddr] <= data_in;
    end
end

//------------------------------------------------------------------------------
if(OUT_REGISTERED == "YES") begin
    always_ff @(posedge clk) begin
        data_out <= ram[raddr];
    end
end
else begin
    assign data_out = ram[raddr];
end

endmodule : sdp_distributed_ram_m


//******************************************************************************
//******************************************************************************
module distributed_reg_rom_m
                #(
                   parameter int ADDR_WIDTH,
                   parameter int WORD_WIDTH,
                   parameter int ROM_SIZE = 2**ADDR_WIDTH,
                   parameter logic [WORD_WIDTH-1:0] INIT_DATA [ROM_SIZE]    
                 )
(
    input  logic                  clk,
    
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [WORD_WIDTH-1:0] data
);

//==============================================================================
//    Objects
//==============================================================================

(* rom_style="distributed" *)
logic [WORD_WIDTH-1:0] rom [ROM_SIZE];

//==============================================================================
//     Logic
//==============================================================================

//------------------------------------------------------------------------------
initial begin
    for(int i = 0; i < ROM_SIZE; i++) begin
        rom[i] = INIT_DATA[i];
    end
end

//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    data <= rom[addr];
end

endmodule : distributed_reg_rom_m
