//Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2021.1 (lin64) Build 3247384 Thu Jun 10 19:36:07 MDT 2021
//Date        : Fri Sep  9 16:05:06 2022
//Host        : simtool5-2 running 64-bit Ubuntu 20.04.5 LTS
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (CLK100MHZ,
    CPU_RESETN,
    GPIO_LED_tri_o,
    GPIO_SW_tri_i,
    UART_rxd,
    UART_txd);
  input CLK100MHZ;
  input CPU_RESETN;
  output [15:0]GPIO_LED_tri_o;
  input [15:0]GPIO_SW_tri_i;
  input UART_rxd;
  output UART_txd;

  wire CLK100MHZ;
  wire CPU_RESETN;
  wire [15:0]GPIO_LED_tri_o;
  wire [15:0]GPIO_SW_tri_i;
  wire UART_rxd;
  wire UART_txd;

  design_1 design_1_i
       (.CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .GPIO_LED_tri_o(GPIO_LED_tri_o),
        .GPIO_SW_tri_i(GPIO_SW_tri_i),
        .UART_rxd(UART_rxd),
        .UART_txd(UART_txd));
endmodule
