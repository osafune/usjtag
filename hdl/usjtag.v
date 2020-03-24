// ===================================================================
// TITLE : USB-Serial to Soft core JTAG I/O with SFL
//
//     DESIGN : s.osafune@j7system.jp (J-7SYSTEM WORKS LIMITED)
//     DATE   : 2020/02/27 -> 2020/03/25
//
// ===================================================================
//
// The MIT License (MIT)
// Copyright (c) 2020 J-7SYSTEM WORKS LIMITED.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//


`default_nettype none

// SUPPORTED_DEVICE_FAMILIES {"MAX 10" "Cyclone IV E" "Cyclone IV GX" "Cyclone 10 LP" "Cyclone V"}

module usjtag #(
	parameter DEVICE_FAMILY		= "Cyclone IV E",
	parameter CLOCK_FREQUENCY	= 50000000,
	parameter UART_BAUDRATE		= 2000000,
	parameter TCK_FREQUENCY		= 25000000,
	parameter USE_SOFTCORE_JTAG	= "ON",
	parameter USE_SERIAL_FLASH_LOADER = "OFF"
) (
	// clock and system reset
	input wire		reset,
	input wire		clock,

	// FT234X serial in/out
	input wire		ft_rxd,
	output wire		ft_txd,

	// JTAG access signal
	output wire		active,

	// JTAG signal (Invalid, when USE_SOFTCORE_JTAG is "ON")
	output wire		jtag_tck,
	output wire		jtag_tms,
	output wire		jtag_tdi,
	input wire		jtag_tdo,

	// Serial Flash Loader signal (Valid, when USE_SOFTCORE_JTAG and USE_SERIAL_FLASH_LOADER is "ON")
	input wire		sfl_enable,
	input wire		asmi_nsco_in,
	input wire		asmi_dclk_in,
	input wire		asmi_asdo_in,
	output wire		asmi_data0_out
);


/* ===== 外部変更可能パラメータ ========== */



/* ----- 内部パラメータ ------------------ */

	localparam TCK_KEEPCYCLE = (((CLOCK_FREQUENCY / 2) + TCK_FREQUENCY - 1) / TCK_FREQUENCY) - 1;


/* ※以降のパラメータ宣言は禁止※ */

/* ===== ノード宣言 ====================== */
				/* 内部は全て正論理リセットとする。ここで定義していないノードの使用は禁止 */
	wire			reset_sig = reset;		// モジュール内部駆動非同期リセット 

				/* 内部は全て正エッジ駆動とする。ここで定義していないクロックノードの使用は禁止 */
	wire			clock_sig = clock;		// モジュール内部駆動クロック 

	wire			rx_ready_sig;
	wire			rx_valid_sig;
	wire [7:0]		rx_data_sig;
	wire			tx_ready_sig;
	wire			tx_valid_sig;
	wire [7:0]		tx_data_sig;
	wire			tck_sig;
	wire			tms_sig;
	wire			tdi_sig;
	wire			tdo_sig;


/* ※以降のwire、reg宣言は禁止※ */

/* ===== テスト記述 ============== */



/* ===== モジュール構造記述 ============== */

	peridot_phy_rxd #(
		.CLOCK_FREQUENCY	(CLOCK_FREQUENCY),
		.UART_BAUDRATE		(UART_BAUDRATE)
	)
	u_rxd (
		.reset		(reset_sig),
		.clk		(clock_sig),
		.out_ready	(rx_ready_sig),
		.out_valid	(rx_valid_sig),
		.out_data	(rx_data_sig),
		.out_error	(),
		.rxd		(ft_rxd)
	);

	peridot_phy_txd #(
		.CLOCK_FREQUENCY	(CLOCK_FREQUENCY),
		.UART_BAUDRATE		(UART_BAUDRATE)
	)
	u_txd (
		.reset		(reset_sig),
		.clk		(clock_sig),
		.in_ready	(tx_ready_sig),
		.in_valid	(tx_valid_sig),
		.in_data	(tx_data_sig),
		.txd		(ft_txd)
	);

	avalonst_byte_to_ubjtag #(
		.TCK_KEEPCYCLE		(TCK_KEEPCYCLE)
	)
	u_jtag (
		.reset		(reset_sig),
		.clock		(clock_sig),

		.in_ready	(rx_ready_sig),
		.in_valid	(rx_valid_sig),
		.in_data	(rx_data_sig),
		.out_ready	(tx_ready_sig),
		.out_valid	(tx_valid_sig),
		.out_data	(tx_data_sig),

		.jtag_tck	(tck_sig),
		.jtag_tms	(tms_sig),
		.jtag_tdi	(tdi_sig),
		.jtag_tdo	(tdo_sig),
		.jtag_oe	(active)
	);


generate
	if (USE_SOFTCORE_JTAG == "ON") begin
		altera_soft_core_jtag_io #(
			.ENABLE_JTAG_IO_SELECTION	(0)
		)
		u_scjtagio (
			.tck		(tck_sig),
			.tms		(tms_sig),
			.tdi		(tdi_sig),
			.tdo		(tdo_sig),
			.select_this	(1'b0)
		);

		assign jtag_tck = 1'b0;
		assign jtag_tms = 1'b0;
		assign jtag_tdi = 1'b0;
	end
	else begin
		assign jtag_tck = tck_sig;
		assign jtag_tms = tms_sig;
		assign jtag_tdi = tdi_sig;
		assign tdo_sig = jtag_tdo;
	end
endgenerate

generate
	if (USE_SOFTCORE_JTAG == "ON" && USE_SERIAL_FLASH_LOADER == "ON" && DEVICE_FAMILY != "MAX 10") begin
		altserial_flash_loader #(
			.enable_quad_spi_support	(0),
			.enable_shared_access		("ON"),
			.enhanced_mode				(1),
			.intended_device_family		(DEVICE_FAMILY),
			.ncso_width					(1)
		)
		u_sfl (
			.scein		(asmi_nsco_in),
			.dclkin		(asmi_dclk_in),
			.sdoin		(asmi_asdo_in),
			.data0out	(asmi_data0_out),
			.asmi_access_granted	(sfl_enable),
			.asmi_access_request	(),
			.data_in	(),
			.data_oe	(),
			.data_out	(),
			.noe		(1'b0)
		);
	end
	else begin
		assign asmi_data0_out = 1'b0;
	end
endgenerate

endmodule
