//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 08-Sep-22  DWW  1000  Initial creation
//===================================================================================================

module aurora_lite
(

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 GT_DIFF_REFCLK1 CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF USER_DATA_S_AXIS_TX:USER_DATA_M_AXIS_RX:GT_SERIAL_TX:GT_SERIAL_RX" *)
    input GT_DIFF_REFCLK1,


    //=================================  AXI Input Stream interface  ================================
    input [255:0] USER_DATA_S_AXIS_TX_TDATA,
    input         USER_DATA_S_AXIS_TX_TVALID,
    input         USER_DATA_S_AXIS_TX_TLAST,
    output reg    USER_DATA_S_AXIS_TX_TREADY,
    //===============================================================================================



    //=================================  AXI Output Stream interface  ================================
    output reg[255:0] USER_DATA_M_AXIS_RX_TDATA,
    output reg        USER_DATA_M_AXIS_RX_TVALID,
    output reg        USER_DATA_M_AXIS_RX_TLAST,
    input             USER_DATA_M_AXIS_RX_TREADY,
    //===============================================================================================



    //================================  QSFP Input Stream interface  ================================
    input [255:0] GT_SERIAL_RX_TDATA,
    input         GT_SERIAL_RX_TVALID,
    input         GT_SERIAL_RX_TLAST,
    output reg    GT_SERIAL_RX_TREADY,
    //===============================================================================================



    //===============================  QSFP Output Stream interface  ================================
    output reg [255:0] GT_SERIAL_TX_TDATA,
    output reg         GT_SERIAL_TX_TVALID,
    output reg         GT_SERIAL_TX_TLAST,
    input              GT_SERIAL_TX_TREADY
    //===============================================================================================



);

    always @(posedge GT_DIFF_REFCLK1) begin

        // Connect the user-data TX input to the GT_SERIAL_TX interface
        GT_SERIAL_TX_TDATA  <= USER_DATA_S_AXIS_TX_TDATA;
        GT_SERIAL_TX_TVALID <= USER_DATA_S_AXIS_TX_TVALID;
        GT_SERIAL_TX_TLAST  <= USER_DATA_S_AXIS_TX_TLAST;
        USER_DATA_S_AXIS_TX_TREADY <= GT_SERIAL_TX_TREADY;

        // Connect the user-data RX output to the GT_SERIAL_RX interface
        USER_DATA_M_AXIS_RX_TDATA  <= GT_SERIAL_RX_TDATA;
        USER_DATA_M_AXIS_RX_TVALID <= GT_SERIAL_RX_TVALID;
        USER_DATA_M_AXIS_RX_TLAST  <= GT_SERIAL_RX_TLAST;
        GT_SERIAL_RX_TREADY        <= USER_DATA_M_AXIS_RX_TREADY;
    end

endmodule