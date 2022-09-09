`timescale 1ns / 1ps

//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//    This RTL core is a demonstration of how to use the AXI4 non-bursting master
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 18-Aug-22  DWW  1000  Initial creation
//====================================================================================


module axi4_noburst_master_example #
(
    parameter integer M_AXI_DATA_WIDTH = 32,
    parameter integer M_AXI_ADDR_WIDTH = 32
)
(
    // Clock, reset, and the button input   
    input clk, resetn, BUTTON,

    //======================  An AXI Master Interface  =========================

    // "Specify write address"         -- Master --    -- Slave --
    output[M_AXI_ADDR_WIDTH-1:0]       M_AXI_AWADDR,   
    output                             M_AXI_AWVALID,  
    output[2:0]                        M_AXI_AWPROT,
    output[3:0]                        M_AXI_AWID,
    output[7:0]                        M_AXI_AWLEN,
    output[2:0]                        M_AXI_AWSIZE,
    output[1:0]                        M_AXI_AWBURST,
    output                             M_AXI_AWLOCK,
    output[3:0]                        M_AXI_AWCACHE,
    output[3:0]                        M_AXI_AWQOS,
    input                                              M_AXI_AWREADY,


    // "Write Data"                    -- Master --    -- Slave --
    output[M_AXI_DATA_WIDTH-1:0]       M_AXI_WDATA,      
    output                             M_AXI_WVALID,
    output[(M_AXI_DATA_WIDTH/8)-1:0]   M_AXI_WSTRB,
    output                             M_AXI_WLAST,
    input                                              M_AXI_WREADY,


    // "Send Write Response"           -- Master --    -- Slave --
    input [1:0]                                        M_AXI_BRESP,
    input                                              M_AXI_BVALID,
    output                             M_AXI_BREADY,

    // "Specify read address"          -- Master --    -- Slave --
    output[M_AXI_ADDR_WIDTH-1:0]       M_AXI_ARADDR,     
    output                             M_AXI_ARVALID,
    output[2:0]                        M_AXI_ARPROT,     
    output                             M_AXI_ARLOCK,
    output[3:0]                        M_AXI_ARID,
    output[7:0]                        M_AXI_ARLEN,
    output[2:0]                        M_AXI_ARSIZE,
    output[1:0]                        M_AXI_ARBURST,
    output[3:0]                        M_AXI_ARCACHE,
    output[3:0]                        M_AXI_ARQOS,
    input                                              M_AXI_ARREADY,

    // "Read data back to master"      -- Master --    -- Slave --
    input [M_AXI_DATA_WIDTH-1:0]                       M_AXI_RDATA,
    input                                              M_AXI_RVALID,
    input [1:0]                                        M_AXI_RRESP,
    input                                              M_AXI_RLAST,
    output                             M_AXI_RREADY
    //==========================================================================


);

    // This is the width of the AXI fields AWSIZE and ARSIZE
    localparam AXI_SIZE_WIDTH = 3;
    
    // This is the width of the AXI fields RRESP and BRESP
    localparam AXI_RESP_WIDTH = 2;

    //==========================================================================
    //     This is an AXI master and its AMCI control registers
    //==========================================================================
    reg [M_AXI_ADDR_WIDTH-1:0] m_amci_waddr;
    reg [M_AXI_DATA_WIDTH-1:0] m_amci_wdata;
    reg [  AXI_SIZE_WIDTH-1:0] m_amci_wsize;
    reg                        m_amci_write;
    wire[  AXI_RESP_WIDTH-1:0] m_amci_wresp;
    wire                       m_amci_widle;
    

    reg [M_AXI_ADDR_WIDTH-1:0] m_amci_raddr;
    reg [  AXI_SIZE_WIDTH-1:0] m_amci_rsize;
    reg                        m_amci_read;
    wire[M_AXI_DATA_WIDTH-1:0] m_amci_rdata;
    wire[  AXI_RESP_WIDTH-1:0] m_amci_rresp;
    wire                       m_amci_ridle;

    axi4_noburst_master#
    (
        .AXI_ADDR_WIDTH(M_AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(M_AXI_DATA_WIDTH)
    ) axi_master
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (M_AXI_AWADDR),
        .AXI_AWVALID    (M_AXI_AWVALID),   
        .AXI_AWPROT     (M_AXI_AWPROT),
        .AXI_AWREADY    (M_AXI_AWREADY),
        .AXI_AWID       (M_AXI_AWID),
        .AXI_AWLEN      (M_AXI_AWLEN),
        .AXI_AWSIZE     (M_AXI_AWSIZE),
        .AXI_AWBURST    (M_AXI_AWBURST),
        .AXI_AWLOCK     (M_AXI_AWLOCK),
        .AXI_AWCACHE    (M_AXI_AWCACHE),
        .AXI_AWQOS      (M_AXI_AWQOS),
        
        // AXI W channel
        .AXI_WDATA      (M_AXI_WDATA),
        .AXI_WVALID     (M_AXI_WVALID),
        .AXI_WSTRB      (M_AXI_WSTRB),
        .AXI_WLAST      (M_AXI_WLAST),
        .AXI_WREADY     (M_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (M_AXI_BRESP),
        .AXI_BVALID     (M_AXI_BVALID),
        .AXI_BREADY     (M_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (M_AXI_ARADDR), 
        .AXI_ARVALID    (M_AXI_ARVALID),
        .AXI_ARPROT     (M_AXI_ARPROT),
        .AXI_ARLOCK     (M_AXI_ARLOCK),
        .AXI_ARID       (M_AXI_ARID),
        .AXI_ARLEN      (M_AXI_ARLEN),
        .AXI_ARSIZE     (M_AXI_ARSIZE),
        .AXI_ARBURST    (M_AXI_ARBURST),
        .AXI_ARCACHE    (M_AXI_ARCACHE),
        .AXI_ARQOS      (M_AXI_ARQOS),
        .AXI_ARREADY    (M_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (M_AXI_RDATA),
        .AXI_RVALID     (M_AXI_RVALID),
        .AXI_RRESP      (M_AXI_RRESP),
        .AXI_RLAST      (M_AXI_RLAST),
        .AXI_RREADY     (M_AXI_RREADY),

        // AMCI-write register
        .AMCI_WADDR     (m_amci_waddr),
        .AMCI_WDATA     (m_amci_wdata),
        .AMCI_WSIZE     (m_amci_wsize),
        .AMCI_WRITE     (m_amci_write),
        .AMCI_WRESP     (m_amci_wresp),
        .AMCI_WIDLE     (m_amci_widle),

        // AMCI-read registers
        .AMCI_RADDR     (m_amci_raddr),
        .AMCI_RDATA     (m_amci_rdata),
        .AMCI_RSIZE     (m_amci_rsize),
        .AMCI_READ      (m_amci_read ),
        .AMCI_RRESP     (m_amci_rresp),
        .AMCI_RIDLE     (m_amci_ridle)
    );
    //==========================================================================


    // The ARSIZE and AWSIZE value for reading/writing the full data width
    localparam AXI4_FULL = $clog2(M_AXI_DATA_WIDTH / 8);
    
    // The ARSIZE and AWSIZE value for reading/writing 32-bit AXI4-Lite
    localparam AXI4_LITE = $clog2(4);

    // The state of the state machine below    
    reg[7:0] state;

    always @(posedge clk) begin
        
        // When these flags are raised, they should pulse high for exactly 1 cycle
        m_amci_read  <= 0;
        m_amci_write <= 0;

        if (resetn == 0) begin
            state <= 0;
        end else case(state)

        // If the user presses the button, write 32-bit 0xA1B1C1D1 to 0xC000_0004
        0:  if (BUTTON) begin
                m_amci_wdata <= 32'hA1B1C1D1;
                m_amci_wsize <= AXI4_LITE;
                m_amci_waddr <= 32'hC000_0004;
                m_amci_write <= 1;
                state        <= state + 1;
            end
            
        // When that finishes, write 32-bit 0xA2B2C2D2 to 0xC000_0008
        1:  if (m_amci_widle) begin
                m_amci_wdata <= 32'hA2B2C2D2;
                m_amci_wsize <= AXI4_LITE;
                m_amci_waddr <= 32'hC000_0008;
                m_amci_write <= 1;
                state        <= state + 1;
            end


        // Now read a full bus-width word from 0xC000_0000     
        2: if (m_amci_widle) begin
                m_amci_raddr <= 32'hC000_0000;
                m_amci_rsize <= AXI4_FULL;
                m_amci_read  <= 1;
                state        <= state + 1;
            end

        // Now read a 32-bit word from 0xC000_0004
        3:  if (m_amci_ridle) begin
                m_amci_raddr <= 32'hC000_0004;
                m_amci_rsize <= AXI4_LITE;
                m_amci_read  <= 1;
                state        <= state + 1;
            end

        // Do a full width write to address 0xC000_0100
        4:  if (m_amci_ridle) begin
                m_amci_wdata <= 256'h00112233445566778899AABBCCDDEEFF00112233445566778899AABBCCDDEEFF;
                m_amci_wsize <= AXI4_FULL;
                m_amci_waddr <= 32'hC000_0100;
                m_amci_write <= 1;
                state        <= state + 1;
            end 

        // When that last read is done, return to idle state
        5:  if (m_amci_ridle && m_amci_widle) state <= 0;
        
        endcase
    end


endmodule
