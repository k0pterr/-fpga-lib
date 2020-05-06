//------------------------------------------------------------------------------
//
//    Project:     Any
//
//    Description: Inferred Distibuted Single-Port RAM module
//
//------------------------------------------------------------------------------

module dist_ram_sp_m
                #(
                   parameter int ADDR_WIDTH,
                   parameter int WORD_WIDTH,
                   parameter int RAM_SIZE = 2**ADDR_WIDTH,
                   parameter     OUT_REGISTERED = "YES",
                   parameter     INIT_FILE = ""  
                 )
(
    //---
    input  logic                  clk,
    
    //---
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [WORD_WIDTH-1:0] data_in,
    output logic [WORD_WIDTH-1:0] data_out
);

//==============================================================================
//    Objects
//==============================================================================

(* ram_style="distributed" *)
logic [WORD_WIDTH-1:0] ram[RAM_SIZE];

//==============================================================================
//     Logic
//==============================================================================

//------------------------------------------------------------------------------
initial begin
    if(INIT_FILE != "") begin
        $readmemh(INIT_FILE, ram, 0);
    end
end

//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if(we) begin
        ram[addr] <= data_in;
    end
end

//------------------------------------------------------------------------------
if(OUT_REGISTERED == "YES") begin
    always_ff @(posedge clk) begin
        data_out <= ram[addr];
    end
end
else begin
    assign data_out = ram[addr];
end

endmodule : dist_ram_sp_m

