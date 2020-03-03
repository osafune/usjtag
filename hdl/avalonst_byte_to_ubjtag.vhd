-- ===================================================================
-- TITLE : AvalonST <-> JTAGインターフェース(UB bytecode) 
--
--     DESIGN : s.osafune@j7system.jp (J-7SYSTEM WORKS LIMITED)
--     DATE   : 2020/02/27 -> 2020/03/03
--
-- ===================================================================

-- The MIT License (MIT)
-- Copyright (c) 2020 J-7SYSTEM WORKS LIMITED.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


-- * Description
--
-- UBバイトコードのAvalonSTバイトストリームからJTAGビットストリームにブリッジする

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity avalonst_byte_to_ubjtag is
	generic(
		TCK_KEEPCYCLE	: integer := 0			-- TCK clock = clock / ((TCK_KEEPCYCLE + 1) * 2), TCK up to 25MHz.
	);
	port(
		-- Interface: clock
		reset			: in  std_logic;
		clock			: in  std_logic;		-- 24MHz typ (FT240X CBUS5/6 or External OSC).

		-- Interface: ST in
		in_ready		: out std_logic;
		in_valid		: in  std_logic;
		in_data			: in  std_logic_vector(7 downto 0);

		-- Interface: ST out
		out_ready		: in  std_logic;
		out_valid		: out std_logic;
		out_data		: out std_logic_vector(7 downto 0);

		-- External: JTAG-master
		jtag_tck		: out std_logic;
		jtag_tms		: out std_logic;
		jtag_tdi		: out std_logic;
		jtag_tdo		: in  std_logic;
		jtag_oe			: out std_logic
	);
end avalonst_byte_to_ubjtag;

architecture RTL of avalonst_byte_to_ubjtag is
	type UB_STATE is (DATA_RX, DATA_TX, BITSET, TCKSET, BYTEDONE);
	signal state : UB_STATE := DATA_RX;
	signal tckkeepcount		: integer range 0 to TCK_KEEPCYCLE;
	signal dir_reg			: std_logic := '0';
	signal bitcount_reg		: std_logic_vector(8 downto 0) := (others=>'0');
	signal shift_reg		: std_logic_vector(7 downto 0);

	signal tck_reg			: std_logic := '0';
	signal tms_reg			: std_logic := '0';
	signal tdi_reg			: std_logic := '0';
	signal active_reg		: std_logic := '0';

	attribute altera_attribute : string;
	attribute altera_attribute of RTL : architecture is
	(
		"-name SDC_STATEMENT ""create_clock -period 40 [get_registers *avalonst_byte_to_ubjtag:*\|tck_reg]"""
	);

begin

	----------------------------------------------
	-- UBバイトコード to JTAGステートマシン 
	----------------------------------------------

	process (clock, reset) begin
		if (reset = '1') then
			state <= DATA_RX;
			dir_reg <= '0';
			bitcount_reg <= (others=>'0');
			tck_reg <= '0';
			tms_reg <= '0';
			tdi_reg <= '0';
			active_reg <= '0';

		elsif rising_edge(clock) then
			case state is
			when DATA_RX =>
				if (in_valid = '1') then
					if (bitcount_reg(8 downto 3) /= 0) then
						state <= BITSET;
						tckkeepcount <= 0;
						shift_reg <= in_data;

					elsif (in_data(7) = '1') then
						dir_reg <= in_data(6);
						bitcount_reg <= in_data(5 downto 0) & "000";

					else
						if (in_data(6) = '1') then
							state <= DATA_TX;
						end if;

						tck_reg <= in_data(0);
						tms_reg <= in_data(1);
						tdi_reg <= in_data(4);
						active_reg <= in_data(5);
						shift_reg <= (0=>jtag_tdo, others=>'0');
					end if;
				end if;

			when DATA_TX =>
				if (out_ready = '1') then
					state <= DATA_RX;
				end if;


			when BITSET =>
				if (TCK_KEEPCYCLE = 0 or tckkeepcount = 0) then
					state <= TCKSET;
					tckkeepcount <= TCK_KEEPCYCLE;
					bitcount_reg <= bitcount_reg - 1;
					tck_reg <= '0';
					tdi_reg <= shift_reg(0);
				else
					tckkeepcount <= tckkeepcount - 1;
				end if;

			when TCKSET =>
				if (TCK_KEEPCYCLE = 0 or tckkeepcount = 0) then
					if (bitcount_reg(2 downto 0) /= 0) then
						state <= BITSET;
					else
						state <= BYTEDONE;
					end if;

					tckkeepcount <= TCK_KEEPCYCLE;
					tck_reg <= '1';
					shift_reg <= jtag_tdo & shift_reg(7 downto 1);
				else
					tckkeepcount <= tckkeepcount - 1;
				end if;

			when BYTEDONE =>
				if (TCK_KEEPCYCLE = 0 or tckkeepcount = 0) then
					if (dir_reg = '1') then
						state <= DATA_TX;
					else
						state <= DATA_RX;
					end if;

					tck_reg <= '0';
				else
					tckkeepcount <= tckkeepcount - 1;
				end if;

			end case;
		end if;
	end process;


	in_ready <= '1' when(state = DATA_RX) else '0';

	out_data <= shift_reg;
	out_valid <= '1' when(state = DATA_TX) else '0';

	jtag_tck <= tck_reg;
	jtag_tms <= tms_reg;
	jtag_tdi <= tdi_reg;
	jtag_oe <= active_reg;



end RTL;
