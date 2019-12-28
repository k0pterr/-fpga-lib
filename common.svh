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

//------------------------------------------------------------------------------
`define CONSTRUCT_DIR(path1,path2) { path1, "/", path2 }

`endif // COMMON_SVH

