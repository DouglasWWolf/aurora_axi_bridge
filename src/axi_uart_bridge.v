`timescale 1ns / 1ps
//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 26-Aug-22  DWW  1000  Initial creation
//====================================================================================

`define AXI_DATA_WIDTH 32 
`define AXI_ADDR_WIDTH 64

module axi_uart_bridge # (parameter CLOCK_FREQ = 100000000)
(
  
    // Define the input clock
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF M_UART:M_AXI, ASSOCIATED_RESET aresetn" *) input aclk,
    
    // Active-low reset
    input aresetn,

    // This is the interrupt from the UART 
    input UART_INT,

    //================ From here down is the AXI4-Lite interface ===============
        
    // "Specify write address"              -- Master --    -- Slave -- 
    output reg[31:0]                        M_UART_AWADDR,   
    output reg                              M_UART_AWVALID,  
    input                                                   M_UART_AWREADY,
    output[2:0]                             M_UART_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    output reg[31:0]                        M_UART_WDATA,      
    output reg                              M_UART_WVALID,
    output[3:0]                             M_UART_WSTRB,
    input                                                   M_UART_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    input[1:0]                                              M_UART_BRESP,
    input                                                   M_UART_BVALID,
    output reg                              M_UART_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    output reg[31:0]                        M_UART_ARADDR,     
    output reg                              M_UART_ARVALID,
    output[2:0]                             M_UART_ARPROT,     
    input                                                   M_UART_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    input[31:0]                                             M_UART_RDATA,
    input                                                   M_UART_RVALID,
    input[1:0]                                              M_UART_RRESP,
    output reg                              M_UART_RREADY,
    //==========================================================================


    //============== From here down is main AXI master interface ===============
       
    // "Specify write address"              -- Master --    -- Slave --
    output reg[`AXI_ADDR_WIDTH-1:0]         M_AXI_AWADDR,   
    output reg                              M_AXI_AWVALID,  
    input                                                   M_AXI_AWREADY,
    output[2:0]                             M_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    output reg[`AXI_DATA_WIDTH-1:0]         M_AXI_WDATA,      
    output reg                              M_AXI_WVALID,
    output[(`AXI_DATA_WIDTH/8)-1:0]         M_AXI_WSTRB,
    input                                                   M_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    input[1:0]                                              M_AXI_BRESP,
    input                                                   M_AXI_BVALID,
    output reg                              M_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    output reg[`AXI_ADDR_WIDTH-1:0]         M_AXI_ARADDR,     
    output reg                              M_AXI_ARVALID,
    output[2:0]                             M_AXI_ARPROT,
    input  wire                                             M_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    input[`AXI_DATA_WIDTH-1:0]                              M_AXI_RDATA,
    input                                                   M_AXI_RVALID,
    input[1:0]                                              M_AXI_RRESP,
    output reg                              M_AXI_RREADY
    //==========================================================================


);

    // Interface to the UART "transmit" FIFO
    reg        tx_fifo_wren;
    reg        tx_fifo_rden;
    reg  [7:0] tx_fifo_din;
    wire [7:0] tx_fifo_dout;    
    wire       tx_fifo_empty;
    wire       tx_fifo_full;    

    // Interface to the UART "receive" FIFO
    reg        rx_fifo_wren;
    reg        rx_fifo_rden;
    reg  [7:0] rx_fifo_din;
    wire [7:0] rx_fifo_dout;    
    wire       rx_fifo_empty;
    wire       rx_fifo_full;    


    // Define the handshakes for all 5 AXI channels
    wire M_UART_B_HANDSHAKE  = M_UART_BVALID  & M_UART_BREADY;
    wire M_UART_R_HANDSHAKE  = M_UART_RVALID  & M_UART_RREADY;
    wire M_UART_W_HANDSHAKE  = M_UART_WVALID  & M_UART_WREADY;
    wire M_UART_AR_HANDSHAKE = M_UART_ARVALID & M_UART_ARREADY;
    wire M_UART_AW_HANDSHAKE = M_UART_AWVALID & M_UART_AWREADY;

    // States of the two state machines that manage the UART AXI bus
    reg[1:0] uart_write_state;
    reg      uart_read_state;

    // AMCI interface that manages the UART AXI pins
    reg[31:0]     uart_amci_raddr;  // Read address
    reg[31:0]     uart_amci_rdata;  // Read data
    reg[1:0]      uart_amci_rresp;  // Read response
    reg           uart_amci_read;   // Start read signal
    reg[31:0]     uart_amci_waddr;  // Write address
    reg[31:0]     uart_amci_wdata;  // Write data
    reg[1:0]      uart_amci_wresp;  // Write response
    reg           uart_amci_write;  // Start write signal
    wire          uart_amci_widle = (uart_write_state == 0 && uart_amci_write == 0);     
    wire          uart_amci_ridle = (uart_read_state  == 0 && uart_amci_read  == 0);     

    //=========================================================================================================
    // FSM logic used for writing to the slave device.
    //
    //  To start:   uart_amci_waddr = Address to write to
    //              uart_amci_wdata = Data to write at that address
    //              uart_amci_write = Pulsed high for one cycle
    //
    //  At end:     Write is complete when "uart_amci_widle" goes high
    //              uart_amci_wresp = AXI_BRESP "write response" signal from slave
    //=========================================================================================================
    assign M_UART_AWPROT  = 3'b000;
    assign M_UART_WSTRB   = 4'b1111;
    //=========================================================================================================
    always @(posedge aclk) begin

        // If we're in RESET mode...
        if (aresetn == 0) begin
            uart_write_state <= 0;
            M_UART_AWVALID   <= 0;
            M_UART_WVALID    <= 0;
            M_UART_BREADY    <= 0;
        end        
        
        // Otherwise, we're not in RESET and our state machine is running
        else case (uart_write_state)
            
            // Here we're idle, waiting for someone to raise the 'uart_amci_write' flag.  Once that happens,
            // we'll place the user specified address and data onto the AXI bus, along with the flags that
            // indicate that the address and data values are valid
            0:  if (uart_amci_write) begin
                    M_UART_AWADDR    <= uart_amci_waddr;  // Place our address onto the bus
                    M_UART_WDATA     <= uart_amci_wdata;  // Place our data onto the bus
                    M_UART_AWVALID   <= 1;                // Indicate that the address is valid
                    M_UART_WVALID    <= 1;                // Indicate that the data is valid
                    M_UART_BREADY    <= 1;                // Indicate that we're ready for the slave to respond
                    uart_write_state <= 1;                // On the next clock cycle, we'll be in the next state
                end
                
           // Here, we're waiting around for the slave to acknowledge our request by asserting M_UART_AWREADY
           // and M_UART_WREADY.  Once that happens, we'll de-assert the "valid" lines.  Keep in mind that we
           // don't know what order AWREADY and WREADY will come in, and they could both come at the same
           // time.      
           1:   begin   
                    // Keep track of whether we have seen the slave raise AWREADY or WREADY
                    if (M_UART_AW_HANDSHAKE) M_UART_AWVALID <= 0;
                    if (M_UART_W_HANDSHAKE ) M_UART_WVALID  <= 0;

                    // If we've seen AWREADY (or if its raised now) and if we've seen WREADY (or if it's raised now)...
                    if ((~M_UART_AWVALID || M_UART_AW_HANDSHAKE) && (~M_UART_WVALID || M_UART_W_HANDSHAKE)) begin
                        uart_write_state <= 2;
                    end
                end
                
           // Wait around for the slave to assert "M_UART_BVALID".  When it does, we'll capture M_UART_BRESP
           // and go back to idle state
           2:   if (M_UART_B_HANDSHAKE) begin
                    uart_amci_wresp   <= M_UART_BRESP;
                    M_UART_BREADY     <= 0;
                    uart_write_state  <= 0;
                end

        endcase
    end
    //=========================================================================================================





    //=========================================================================================================
    // FSM logic used for reading from a slave device.
    //
    //  To start:   uart_amci_raddr = Address to read from
    //              uart_amci_read  = Pulsed high for one cycle
    //
    //  At end:   Read is complete when "uart_amci_ridle" goes high.
    //            uart_amci_rdata = The data that was read
    //            uart_amci_rresp = The AXI "read_response" that is used to indicate success or failure
    //=========================================================================================================
    // Wire up the AXI interface outputs
    assign M_UART_ARPROT  = 3'b001;
    //=========================================================================================================
    
    always @(posedge aclk) begin
          
        if (aresetn == 0) begin
            uart_read_state <= 0;
            M_UART_ARVALID  <= 0;
            M_UART_RREADY   <= 0;
        end else case (uart_read_state)

            // Here we are waiting around for someone to raise "uart_amci_read", which signals us to begin
            // a AXI read at the address specified in "uart_amci_raddr"
            0:  if (uart_amci_read) begin
                    M_UART_ARADDR   <= uart_amci_raddr;
                    M_UART_ARVALID  <= 1;
                    M_UART_RREADY   <= 1;
                    uart_read_state <= 1;
                end else begin
                    M_UART_ARVALID  <= 0;
                    M_UART_RREADY   <= 0;
                    uart_read_state <= 0;
                end
            
            // Wait around for the slave to raise M_UART_RVALID, which tells us that M_UART_RDATA
            // contains the data we requested
            1:  begin
                    if (M_UART_AR_HANDSHAKE) begin
                        M_UART_ARVALID <= 0;
                    end

                    if (M_UART_R_HANDSHAKE) begin
                        uart_amci_rdata <= M_UART_RDATA;
                        uart_amci_rresp <= M_UART_RRESP;
                        M_UART_RREADY   <= 0;
                        uart_read_state <= 0;
                    end
                end

        endcase
    end
    //=========================================================================================================



    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //                               End of AXI4 Lite Master state machines
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    localparam UART_ADDR = 0;
    
    // These are the registers in a Xilinx AXI UART-Lite
    localparam UART_RX   = UART_ADDR +  0; 
    localparam UART_TX   = UART_ADDR +  4;
    localparam UART_STAT = UART_ADDR +  8;
    localparam UART_CTRL = UART_ADDR + 12;


    //-------------------------------------------------------------------------------------------------
    // State machine that manages the TX side of the UART
    //-------------------------------------------------------------------------------------------------
    reg[1:0] tx_state;   
    always @(posedge aclk) begin
        
        tx_fifo_rden    <= 0;
        uart_amci_write <= 0;

        if (aresetn == 0) begin
            tx_state <= 0;
        end else case(tx_state)

        // Initialize the UART by enabling interrupts
        0:  begin
                uart_amci_waddr <= UART_CTRL;
                uart_amci_wdata <= (1<<4);
                uart_amci_write <= 1;
                tx_state        <= 1;
            end

        // Here we wait for a character to arrive in the incoming TX fifo.   When one does, 
        // we will send it to the UART, acknowledge the TX fifo, and go wait for the AXI
        // transaction to complete.
        1:  if (uart_amci_widle && !tx_fifo_empty) begin
                uart_amci_waddr <= UART_TX;
                uart_amci_wdata <= tx_fifo_dout;
                uart_amci_write <= 1;
                tx_fifo_rden    <= 1;
                tx_state        <= 2;
            end

        // Here we are waiting for the AXI write transaction to complete. 
        2:  if (uart_amci_widle) begin
                if (uart_amci_wresp == 0) begin
                    tx_state <= 1;
                end else begin
                    uart_amci_write <= 1;
                end
            end
       
        endcase
    end
    //-------------------------------------------------------------------------------------------------



    //-------------------------------------------------------------------------------------------------
    // State machine that manages the RX side of the UART
    //-------------------------------------------------------------------------------------------------
    reg[1:0] rx_state; 
    always @(posedge aclk) begin
        
        rx_fifo_wren    <= 0;
        uart_amci_read  <= 0;
   
        if (aresetn == 0) begin
            rx_state <= 0;
        end else case(rx_state)

        // Here we are waiting for an interrupt from the UART.  When one happens, we will
        // start a uart_read_state of the UART status register
        0:  if (UART_INT) begin
                uart_amci_raddr <= UART_STAT;
                uart_amci_read  <= 1;
                rx_state        <= 1;
            end

        // Wait for the read of the UART status register to complete.  When it does, if 
        // it tells us that there is an incoming character waiting for us, start a read
        // of the UART's RX register
        1:  if (uart_amci_ridle) begin
                if (uart_amci_rdata[0]) begin
                    uart_amci_raddr <= UART_RX;
                    uart_amci_read  <= 1;
                    rx_state        <= 2;
                end else
                    rx_state        <= 0;
            end

        // Here we wait for the read of the UART RX register to complete.  If it completes
        // succesfully, we will stuff the received byte into the RX FIFO so it can be fetched
        // by the user
        2:  if (uart_amci_ridle) begin
                if (uart_amci_rresp == 0) begin
                    rx_fifo_din  <= uart_amci_rdata[7:0];
                    rx_fifo_wren <= 1;
                end
                rx_state <= 0;
            end
        endcase
    end
    //-------------------------------------------------------------------------------------------------


    //=========================================================================================================
    // From here down is the code that parses and follows AXI read/write commands
    //=========================================================================================================

    localparam AXI_DATA_WIDTH  = `AXI_DATA_WIDTH;
    localparam AXI_ADDR_WIDTH  = `AXI_ADDR_WIDTH; 

    // Define the handshakes for all 5 AXI channels
    wire B_HANDSHAKE  = M_AXI_BVALID  & M_AXI_BREADY;
    wire R_HANDSHAKE  = M_AXI_RVALID  & M_AXI_RREADY;
    wire W_HANDSHAKE  = M_AXI_WVALID  & M_AXI_WREADY;
    wire AR_HANDSHAKE = M_AXI_ARVALID & M_AXI_ARREADY;
    wire AW_HANDSHAKE = M_AXI_AWVALID & M_AXI_AWREADY;

    // States for the two state machines
    reg         read_state;
    reg[1:0]    write_state;

    //----------------------------------------------------------------------------------
    // Define an AMCI interface to the main AXI bus
    //----------------------------------------------------------------------------------
    reg[AXI_ADDR_WIDTH-1:0] amci_raddr;
    reg                     amci_read;
    reg[AXI_DATA_WIDTH-1:0] amci_rdata;
    reg[1:0]                amci_rresp;
    reg[AXI_ADDR_WIDTH-1:0] amci_waddr;
    reg[AXI_DATA_WIDTH-1:0] amci_wdata;
    reg                     amci_write;
    reg[1:0]                amci_wresp;
    wire                    amci_widle = (write_state == 0 && amci_write == 0);     
    wire                    amci_ridle = (read_state  == 0 && amci_read  == 0);     
    //----------------------------------------------------------------------------------


    //=========================================================================================================
    // FSM logic used for writing to the slave device.
    //
    //  To start:   amci_waddr = Address to write to
    //              amci_wdata = Data to write at that address
    //              amci_write = Pulsed high for one cycle
    //
    //  At end:     Write is complete when "amci_widle" goes high
    //              amci_wresp = AXI_BRESP "write response" signal from slave
    //=========================================================================================================
    assign M_AXI_AWPROT  = 3'b000;
    assign M_AXI_WSTRB   = (1 << (AXI_DATA_WIDTH/8)) - 1; 
    //=========================================================================================================
    always @(posedge aclk) begin

        // If we're in RESET mode...
        if (aresetn == 0) begin
            write_state   <= 0;
            M_AXI_AWVALID <= 0;
            M_AXI_WVALID  <= 0;
            M_AXI_BREADY  <= 0;
        end        
        
        // Otherwise, we're not in RESET and our state machine is running
        else case (write_state)
            
            // Here we're idle, waiting for someone to raise the 'amci_write' flag.  Once that happens,
            // we'll place the user specified address and data onto the AXI bus, along with the flags that
            // indicate that the address and data values are valid
            0:  if (amci_write) begin
                    M_AXI_AWADDR    <= amci_waddr;  // Place our address onto the bus
                    M_AXI_WDATA     <= amci_wdata;  // Place our data onto the bus
                    M_AXI_AWVALID   <= 1;           // Indicate that the address is valid
                    M_AXI_WVALID    <= 1;           // Indicate that the data is valid
                    M_AXI_BREADY    <= 1;           // Indicate that we're ready for the slave to respond
                    write_state     <= 1;           // On the next clock cycle, we'll be in the next state
                end
                
           // Here, we're waiting around for the slave to acknowledge our request by asserting M_AXI_AWREADY
           // and M_AXI_WREADY.  Once that happens, we'll de-assert the "valid" lines.  Keep in mind that we
           // don't know what order AWREADY and WREADY will come in, and they could both come at the same
           // time.      
           1:   begin   
                    // Keep track of whether we have seen the slave raise AWREADY or WREADY
                    if (AW_HANDSHAKE) M_AXI_AWVALID <= 0;
                    if (W_HANDSHAKE ) M_AXI_WVALID  <= 0;

                    // If we've seen AWREADY (or if its raised now) and if we've seen WREADY (or if it's raised now)...
                    if ((~M_AXI_AWVALID || AW_HANDSHAKE) && (~M_AXI_WVALID || W_HANDSHAKE)) begin
                        write_state <= 2;
                    end
                end
                
           // Wait around for the slave to assert "M_AXI_BVALID".  When it does, we'll capture M_AXI_BRESP
           // and go back to idle state
           2:   if (B_HANDSHAKE) begin
                    amci_wresp   <= M_AXI_BRESP;
                    M_AXI_BREADY <= 0;
                    write_state  <= 0;
                end

        endcase
    end
    //=========================================================================================================





    //=========================================================================================================
    // FSM logic used for reading from a slave device.
    //
    //  To start:   amci_raddr = Address to read from
    //              amci_read  = Pulsed high for one cycle
    //
    //  At end:   Read is complete when "amci_ridle" goes high.
    //            amci_rdata = The data that was read
    //            amci_rresp = The AXI "read response" that is used to indicate success or failure
    //=========================================================================================================
    assign M_AXI_ARPROT  = 3'b001;
    //=========================================================================================================
    always @(posedge aclk) begin
         
        if (aresetn == 0) begin
            read_state    <= 0;
            M_AXI_ARVALID <= 0;
            M_AXI_RREADY  <= 0;
        end else case (read_state)

            // Here we are waiting around for someone to raise "amci_read", which signals us to begin
            // a AXI read at the address specified in "amci_raddr"
            0:  if (amci_read) begin
                    M_AXI_ARADDR  <= amci_raddr;
                    M_AXI_ARVALID <= 1;
                    M_AXI_RREADY  <= 1;
                    read_state    <= 1;
                end else begin
                    M_AXI_ARVALID <= 0;
                    M_AXI_RREADY  <= 0;
                    read_state    <= 0;
                end
            
            // Wait around for the slave to raise M_AXI_RVALID, which tells us that M_AXI_RDATA
            // contains the data we requested
            1:  begin
                    if (AR_HANDSHAKE) begin
                        M_AXI_ARVALID <= 0;
                    end

                    if (R_HANDSHAKE) begin
                        amci_rdata    <= M_AXI_RDATA;
                        amci_rresp    <= M_AXI_RRESP;
                        M_AXI_RREADY  <= 0;
                        read_state    <= 0;
                    end
                end

        endcase
    end
    //=========================================================================================================

 
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    // From here down is the logic that manages messages on the UART and instantiates AXI read/write transactions
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    //<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    
    localparam INP_BUFF_SIZE     = 13;
    localparam CMD_READ32        = 1;
    localparam CMD_WRITE32       = 2;
    localparam CMD_READ64        = 3;
    localparam CMD_WRITE64       = 4;

    localparam RESET_STRETCH_MAX = 16;
    localparam HUNDRED_MSEC      = CLOCK_FREQ / 10;
    localparam FIFO_READ_DELAY   = 1;

    localparam csm_NEW_COMMAND        = 0;
    localparam csm_WAIT_NEXT_CHAR     = 1;
    localparam csm_WAIT_FOR_STATUS    = 2;
    localparam csm_FETCH_BYTE         = 3;
    localparam csm_START_READ32       = 4;
    localparam csm_START_READ64       = 5;
    localparam csm_PUSH_RRESP_TO_FIFO = 6;
    localparam csm_PUSH_RDATA_TO_FIFO = 7;         
    localparam csm_START_WRITE32      = 8;
    localparam csm_START_WRITE64      = 9;
    localparam csm_PUSH_WRESP_TO_FIFO = 10;

    reg[ 4:0] csm_state;                     // State of the command-state-machine
    reg[ 3:0] inp_count;                     // The number of bytes stored in inp_buff;
    reg[ 3:0] inp_last_idx;                  // Number of bytes that make up the current command
    reg[ 7:0] inp_buff[0:INP_BUFF_SIZE-1];   // Buffer of bytes rcvd from the UART
    reg[ 7:0] reset_stretch;                 // # of consecutive "X" characters received
    reg[31:0] reset_clk_counter;             // Counts down clock cycles since last byte rcvd from UART
    
    // After we strobe rx_fifo_rden, this is the number of clocks to wait before we trust rx_fifo_empty again
    reg[ 1:0] inp_read_delay;

    // This holds the data we read during an AXI-Read transaction.   The assign statements
    // are a convenient way to make the bit-packed register byte-addressable
    reg[31:0] read_data;        
    wire[7:0] read_data_char[0:3];
    assign read_data_char[0] = read_data[31:24];
    assign read_data_char[1] = read_data[23:16];
    assign read_data_char[2] = read_data[15: 8];
    assign read_data_char[3] = read_data[ 7: 0];


    // This FSM reads data from the UART FIFO, performs the requested AXI transaction, and send a response
    always @(posedge aclk) begin
        amci_write   <= 0;
        amci_read    <= 0;
        tx_fifo_wren <= 0;
        rx_fifo_rden <= 0;
        
        // Countdown since the last time a character was received
        if (reset_clk_counter) reset_clk_counter <= reset_clk_counter - 1;

        // Countdown the # of clocks to wait until we trust tx_fifo_empty
        if (inp_read_delay) inp_read_delay <= inp_read_delay - 1;

        // If the RESET line is active...
        if (aresetn == 0) begin
            csm_state         <= csm_NEW_COMMAND;
            inp_read_delay    <= 0;
            reset_stretch     <= 0;
            reset_clk_counter <= 0;
        end else case(csm_state)

        // Initialize variables in expectation of a new command arriving
        csm_NEW_COMMAND:
            begin
                inp_count <= 0;
                csm_state <= csm_WAIT_NEXT_CHAR;
            end 

        csm_WAIT_NEXT_CHAR:
            begin
                // If 100 milliseconds elapses since receiving the last character and the reset_stretch
                // is at max, empty our buffer to prepare for a new incoming command.  This mechanism
                // exists to provide a method to place the input buffer in a known state.
                if (reset_clk_counter == 1) begin
                    if (reset_stretch == RESET_STRETCH_MAX) begin
                        inp_count <= 0;
                    end
                end
        
                // If a byte has arrived from the UART...
                if (!rx_fifo_empty && inp_read_delay == 0) begin 
                    rx_fifo_rden        <= 1;                    //   Acknowledge that we've read the FIFO
                    inp_read_delay      <= FIFO_READ_DELAY;      //   It will be a moment before we can trust rx_fifo_empty
                    reset_clk_counter   <= HUNDRED_MSEC;         //   Reset the "clocks since char received" 
                    inp_buff[inp_count] <= rx_fifo_dout;         //   Save the byte we just received

                    // Keep track of how many times in a row we receive "X"
                    if (rx_fifo_dout == "X") begin
                        if (reset_stretch != RESET_STRETCH_MAX)
                            reset_stretch <= reset_stretch + 1;
                    end else reset_stretch <= 0;

                    // If this is the first byte of a new command...
                    if (inp_count == 0) case(rx_fifo_dout)
                        CMD_READ32:  begin
                                        inp_last_idx <= 4;
                                        inp_count    <= 1;
                                     end
                            
                        CMD_WRITE32: begin
                                        inp_last_idx <= 8;
                                        inp_count    <= 1;
                                     end

                        CMD_READ64:  begin
                                        inp_last_idx <= 8;
                                        inp_count    <= 1;
                                     end
                            
                        CMD_WRITE64: begin
                                        inp_last_idx <= 12;
                                        inp_count    <= 1;
                                     end
                    endcase

                
                    // Otherwise, if it's the last byte of a command..
                    else if (inp_count == inp_last_idx) case(inp_buff[0])
                        CMD_READ32:  csm_state <= csm_START_READ32;
                        CMD_READ64:  csm_state <= csm_START_READ64;
                        CMD_WRITE32: csm_state <= csm_START_WRITE32;
                        CMD_WRITE64: csm_state <= csm_START_WRITE64;                        
                    endcase

                    // Otherwise, just keep track of how many bytes we've received from the UART
                    else inp_count <= inp_count + 1;
                end
            end


        // Start an AXI read from a 32-bit address
        csm_START_READ32:
            if (amci_ridle) begin
                amci_raddr[63:32] <= 0;
                amci_raddr[31:24] <= inp_buff[1];
                amci_raddr[23:16] <= inp_buff[2];
                amci_raddr[15:8]  <= inp_buff[3];
                amci_raddr[7:0]   <= inp_buff[4];
                amci_read         <= 1;
                csm_state         <= csm_PUSH_RRESP_TO_FIFO;
            end

        // Start an AXI read from a 64-bit address
        csm_START_READ64:
            if (amci_ridle) begin
                amci_raddr[63:56] <= inp_buff[1];
                amci_raddr[55:48] <= inp_buff[2];
                amci_raddr[47:40] <= inp_buff[3];
                amci_raddr[39:32] <= inp_buff[4];
                amci_raddr[31:24] <= inp_buff[5];
                amci_raddr[23:16] <= inp_buff[6];
                amci_raddr[15:8]  <= inp_buff[7];
                amci_raddr[7:0]   <= inp_buff[8];
                amci_read         <= 1;
                csm_state         <= csm_PUSH_RRESP_TO_FIFO;
            end


        // Push the AXI read-response byte into the FIFO
        csm_PUSH_RRESP_TO_FIFO:
            if (amci_ridle) begin
                read_data    <= amci_rdata;
                tx_fifo_din  <= amci_rresp;
                tx_fifo_wren <= 1;
                inp_count    <= 0;
                csm_state    <= csm_PUSH_RDATA_TO_FIFO;
            end

        // Push the 4-bytes of read-data into the FIFO, one byte at a time
        csm_PUSH_RDATA_TO_FIFO:
            if (inp_count == 4)
                csm_state <= csm_NEW_COMMAND;
            else begin
                tx_fifo_din  <= read_data_char[inp_count];
                tx_fifo_wren <= 1;
                inp_count    <= inp_count + 1;
            end 

        // Start an AXI write to a 32-bit address
        csm_START_WRITE32:
            if (amci_widle) begin
                amci_waddr[63:32] <= 0;
                amci_waddr[31:24] <= inp_buff[1];
                amci_waddr[23:16] <= inp_buff[2];
                amci_waddr[15:8]  <= inp_buff[3];
                amci_waddr[7:0]   <= inp_buff[4];
                amci_wdata <= (inp_buff[5] << 24) | (inp_buff[6] << 16) | (inp_buff[7] << 8) | inp_buff[8];
                amci_write <= 1;
                csm_state  <= csm_PUSH_WRESP_TO_FIFO;
            end

        // Start an AXI write to a 64-bit address
        csm_START_WRITE64:
            if (amci_widle) begin
                amci_waddr[63:56] <= inp_buff[1];
                amci_waddr[55:48] <= inp_buff[2];
                amci_waddr[47:40] <= inp_buff[3];
                amci_waddr[39:32] <= inp_buff[4];
                amci_waddr[31:24] <= inp_buff[5];
                amci_waddr[23:16] <= inp_buff[6];
                amci_waddr[15:8]  <= inp_buff[7];
                amci_waddr[7:0]   <= inp_buff[8];
                amci_wdata <= (inp_buff[9] << 24) | (inp_buff[10] << 16) | (inp_buff[11] << 8) | inp_buff[12];
                amci_write <= 1;
                csm_state  <= csm_PUSH_WRESP_TO_FIFO;
            end


        // Wait for that transaction to complete.  When it does, push the write-response info the FIFO
        csm_PUSH_WRESP_TO_FIFO:
            if (amci_widle) begin
                tx_fifo_din  <= amci_wresp;
                tx_fifo_wren <= 1;
                csm_state    <= csm_NEW_COMMAND;
            end

        endcase
    
    end




    //====================================================================================
    // The two FIFO's that the two halves of this module use to communicate
    //====================================================================================
    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (16),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (8),
      .READ_MODE            ("fwft"),          
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("0000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (8), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_xmit_fifo 
    (
        .rst        (~aresetn     ),                      
        .full       (tx_fifo_full ),              
        .din        (tx_fifo_din  ),                 
        .wr_en      (tx_fifo_wren ),            
        .wr_clk     (aclk         ),          
        .dout       (tx_fifo_dout ),              
        .empty      (tx_fifo_empty),            
        .rd_en      (tx_fifo_rden ),            

      //------------------------------------------------------------
      // This only exists in xpm_fifo_async, not in xpm_fifo_sync
      // .rd_clk    (CLK               ),                     
      //------------------------------------------------------------
        .data_valid     (),  
        .sleep          (),                        
        .injectdbiterr  (),                
        .injectsbiterr  (),                
        .overflow       (),                     
        .prog_empty     (),                   
        .prog_full      (),                    
        .rd_data_count  (),                
        .rd_rst_busy    (),                  
        .sbiterr        (),                      
        .underflow      (),                    
        .wr_ack         (),                       
        .wr_data_count  (),                
        .wr_rst_busy    (),                  
        .almost_empty   (),                 
        .almost_full    (),                  
        .dbiterr        ()                       
    );

    xpm_fifo_sync #
    (
      .CASCADE_HEIGHT       (0),       
      .DOUT_RESET_VALUE     ("0"),    
      .ECC_MODE             ("no_ecc"),       
      .FIFO_MEMORY_TYPE     ("auto"), 
      .FIFO_READ_LATENCY    (1),     
      .FIFO_WRITE_DEPTH     (16),    
      .FULL_RESET_VALUE     (0),      
      .PROG_EMPTY_THRESH    (10),    
      .PROG_FULL_THRESH     (10),     
      .RD_DATA_COUNT_WIDTH  (1),   
      .READ_DATA_WIDTH      (8),
      .READ_MODE            ("fwft"),         
      .SIM_ASSERT_CHK       (0),        
      .USE_ADV_FEATURES     ("0000"), 
      .WAKEUP_TIME          (0),           
      .WRITE_DATA_WIDTH     (8), 
      .WR_DATA_COUNT_WIDTH  (1)    

      //------------------------------------------------------------
      // These exist only in xpm_fifo_async, not in xpm_fifo_sync
      //.CDC_SYNC_STAGES(2),       // DECIMAL
      //.RELATED_CLOCKS(0),        // DECIMAL
      //------------------------------------------------------------
    )
    xpm_recv_fifo
    (
        .rst        (~aresetn     ),                      
        .full       (rx_fifo_full ),              
        .din        (rx_fifo_din  ),                 
        .wr_en      (rx_fifo_wren ),            
        .wr_clk     (aclk         ),          
        .dout       (rx_fifo_dout ),              
        .empty      (rx_fifo_empty),            
        .rd_en      (rx_fifo_rden ),            

      //------------------------------------------------------------
      // This only exists in xpm_fifo_async, not in xpm_fifo_sync
      // .rd_clk    (CLK               ),                     
      //------------------------------------------------------------

        .data_valid     (),  
        .sleep          (),                        
        .injectdbiterr  (),                
        .injectsbiterr  (),                
        .overflow       (),                     
        .prog_empty     (),                   
        .prog_full      (),                    
        .rd_data_count  (),                
        .rd_rst_busy    (),                  
        .sbiterr        (),                      
        .underflow      (),                    
        .wr_ack         (),                       
        .wr_data_count  (),                
        .wr_rst_busy    (),                  
        .almost_empty   (),                 
        .almost_full    (),                  
        .dbiterr        ()                       
    );



endmodule