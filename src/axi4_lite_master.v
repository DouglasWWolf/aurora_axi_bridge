`timescale 1ns / 1ps

//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
//              This RTL core is a fully-functional AXI4-Lite Master
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 09-Sep-22  DWW  1000  Initial creation
//====================================================================================


module axi4_lite_master#
(
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ADDR_WIDTH = 32
)
(

    input wire clk, resetn,


    //==================  The AXI Master Control Interface  ====================

    // AMCI signals for performing AXI writes
    input[AXI_ADDR_WIDTH-1:0]      AMCI_WADDR,
    input[AXI_DATA_WIDTH-1:0]      AMCI_WDATA,
    input                          AMCI_WRITE,
    output reg[1:0]                AMCI_WRESP,
    output                         AMCI_WIDLE,
    
    // AMCI signals for performing AXI reads
    input[AXI_ADDR_WIDTH-1:0]      AMCI_RADDR,
    input                          AMCI_READ,
    output reg[AXI_DATA_WIDTH-1:0] AMCI_RDATA,
    output reg[1:0]                AMCI_RRESP,
    output                         AMCI_RIDLE,

    //==========================================================================


    //====================  An AXI-Lite Master Interface  ======================

    // "Specify write address"          -- Master --    -- Slave --
    output reg [AXI_ADDR_WIDTH-1:0]     AXI_AWADDR,   
    output reg                          AXI_AWVALID,  
    output     [2:0]                    AXI_AWPROT,
    input                                               AXI_AWREADY,

    // "Write Data"                     -- Master --    -- Slave --
    output reg [AXI_DATA_WIDTH-1:0]     AXI_WDATA,      
    output reg                          AXI_WVALID,
    output     [(AXI_DATA_WIDTH/8)-1:0] AXI_WSTRB,
    input                                               AXI_WREADY,

    // "Send Write Response"            -- Master --    -- Slave --
    input      [1:0]                                    AXI_BRESP,
    input                                               AXI_BVALID,
    output reg                          AXI_BREADY,

    // "Specify read address"           -- Master --    -- Slave --
    output reg [AXI_ADDR_WIDTH-1:0]     AXI_ARADDR,     
    output reg                          AXI_ARVALID,
    output     [2:0]                    AXI_ARPROT,     
    input                                               AXI_ARREADY,

    // "Read data back to master"       -- Master --    -- Slave --
    input [AXI_DATA_WIDTH-1:0]                          AXI_RDATA,
    input                                               AXI_RVALID,
    input [1:0]                                         AXI_RRESP,
    output reg                          AXI_RREADY
    //==========================================================================

);
    // Assign all of the "write transaction" signals that are constant
    assign AXI_AWPROT =  0;  // Normal
    assign AXI_WSTRB  = -1;  // All data bytes are valid

    // Assign all of the "read transaction" signals that are constant
    assign AXI_ARPROT = 0;   // Normal
 
    // Define the handshakes for all 5 AXI channels
    wire B_HANDSHAKE  = AXI_BVALID  & AXI_BREADY;
    wire R_HANDSHAKE  = AXI_RVALID  & AXI_RREADY;
    wire W_HANDSHAKE  = AXI_WVALID  & AXI_WREADY;
    wire AR_HANDSHAKE = AXI_ARVALID & AXI_ARREADY;
    wire AW_HANDSHAKE = AXI_AWVALID & AXI_AWREADY;

    // These are the state variables for the read and write state machines
    reg[1:0] write_state, read_state;

    // The "state machine is idle" signals for the two AMCI interfaces
    assign AMCI_WIDLE = (AMCI_WRITE == 0) && (write_state == 0);
    assign AMCI_RIDLE = (AMCI_READ  == 0) && ( read_state == 0);

    //=========================================================================================================
    // FSM logic used for writing to the slave device.
    //
    //  To start:   AMCI_WADDR = Address to write to
    //              AMCI_WDATA = Data to write 
    //              AMCI_WRITE = Pulsed high for one cycle
    //
    //  At end:     Write is complete when "AMCI_WIDLE" goes high
    //              AMCI_WRESP = AXI_BRESP "write response" signal from slave
    //=========================================================================================================
    always @(posedge clk) begin

        // If we're in RESET mode...
        if (resetn == 0) begin
            write_state <= 0;
            AXI_AWVALID <= 0;
            AXI_WVALID  <= 0;
            AXI_BREADY  <= 0;
        end        
        
        // Otherwise, we're not in RESET and our state machine is running
        else case (write_state)
            
            // Here we're idle, waiting for someone to raise the 'AMCI_WRITE' flag.  Once that happens,
            // we'll place the user specified address and data onto the AXI bus, along with the flags that
            // indicate that the address and data values are valid
            0:  if (AMCI_WRITE) begin
                    AXI_AWADDR  <= AMCI_WADDR;  // Place our address onto the bus
                    AXI_WDATA   <= AMCI_WDATA;  // Place our data onto the bus
                    AXI_AWVALID <= 1;           // Indicate that the address is valid
                    AXI_WVALID  <= 1;           // Indicate that the data is valid
                    AXI_BREADY  <= 1;           // Indicate that we're ready for the slave to respond
                    write_state <= 1;           // On the next clock cycle, we'll be in the next state
                end
                
           // Here, we're waiting around for the slave to acknowledge our request by asserting AXI_AWREADY
           // and AXI_WREADY.  Once that happens, we'll de-assert the "valid" lines.  Keep in mind that we
           // don't know what order AWREADY and WREADY will come in, and they could both come at the same
           // time.      
           1:   begin   
                    // Keep track of whether we have seen the slave raise AWREADY or WREADY
                    if (AW_HANDSHAKE) AXI_AWVALID <= 0;
                    if (W_HANDSHAKE ) AXI_WVALID  <= 0;

                    // If we've seen AWREADY (or if its raised now) and if we've seen WREADY (or if it's raised now)...
                    if ((~AXI_AWVALID || AW_HANDSHAKE) && (~AXI_WVALID || W_HANDSHAKE)) begin
                        write_state <= 2;
                    end
                end
                
           // Wait around for the slave to assert "AXI_BVALID".  
           2:   if (B_HANDSHAKE) begin
                    AMCI_WRESP  <= AXI_BRESP;
                    AXI_BREADY  <= 0;
                    write_state <= 0;
                end

        endcase
    end
    //=========================================================================================================





    //=========================================================================================================
    // FSM logic used for reading from a slave device.
    //
    //  To start: AMCI_RADDR = Address to read from
    //            AMCI_READ  = Pulsed high for one cycle
    //
    //  At end:   Read is complete when "AMCI_RIDLE" goes high.
    //            AMCI_RDATA = The data that was read
    //            AMCI_RRESP = The AXI "read response" that is used to indicate success or failure
    //=========================================================================================================
    always @(posedge clk) begin
         
        if (resetn == 0) begin
            read_state  <= 0;
            AXI_ARVALID <= 0;
            AXI_RREADY  <= 0;
        end else case (read_state)

            // Here we are waiting around for someone to raise "AMCI_READ", which signals us to begin
            // a AXI read at the address specified in "AMCI_RADDR"
            0:  if (AMCI_READ) begin
                    AXI_ARADDR   <= AMCI_RADDR; 
                    AXI_ARVALID  <= 1;
                    AXI_RREADY   <= 1;
                    read_state   <= 1;
                end else begin
                    AXI_ARADDR   <= 0;
                    AXI_ARVALID  <= 0;
                    AXI_RREADY   <= 0;
                    read_state   <= 0;
                end
            
            // Wait around for the slave to raise AXI_RVALID, which tells us that AXI_RDATA
            // contains the data we requested
            1:  begin
                    if (AR_HANDSHAKE) begin
                        AXI_ARVALID <= 0;
                    end

                    // If the slave has provided us the data we asked for...
                    if (R_HANDSHAKE) begin
                        
                        // save the read-data so our user can get it
                        AMCI_RDATA <= AXI_RDATA;
                        
                        // Save the read-response so our user can get it
                        AMCI_RRESP <= AXI_RRESP;
                        
                        // Lower the ready signal to make it obvious that we're done
                        AXI_RREADY <= 0;

                        // And go back to idle state
                        read_state <= 0;
                    end
                end

        endcase
    end
    //=========================================================================================================


endmodule
