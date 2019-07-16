//------------------------------------------------------------------------------
//  project:       any
//
//  description:   wrapper for common.pkg
//------------------------------------------------------------------------------

`ifndef COMMON_SVH
`define COMMON_SVH

`include "common.pkg"

//------------------------------------------------------------------------------
`define PRINT_MACRO_STATUS(x,y = "")                \
        `ifdef x                                    \
            $write("%-50s - ON  %s\n", `"x`", y);   \
        `else                                       \
            $write("%-50s - OFF %s\n", `"x`", y);   \
        `endif

`endif // COMMON_SVH

