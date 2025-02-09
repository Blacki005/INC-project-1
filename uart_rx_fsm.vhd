-- uart_rx_fsm.vhd: UART controller - finite state machine controlling RX side

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;



entity UART_RX_FSM is
    port(
		CLK : in std_logic;
		RST : in std_logic;
		START_BIT : in std_logic;
		WORD_END : in std_logic;
		SAMPLE_IN : in std_logic;
		SHIFT_EN : out std_logic := '0';
		RST_CNT : out std_logic := '0';
		SAMPLE_OUT : out std_logic := '0';
		VALID : out std_logic := '0'
    );
end entity;



architecture behavioral of UART_RX_FSM is

	--definice signalu:
	--signal indikujici momentalni stav Q(i):
    type t_state is (IDLE, START, DATA, STOP);
    signal state : t_state := IDLE;
	--signal pro nasledujici stav Q(i+1):
    signal next_state : t_state;
	--signal napojeny na ENABLED port shift registru
	signal shiftenabled : std_logic := '0';
	--signal resetujici countery pro pocitani vzorku a konce slova
	signal rstcnt : std_logic := '0';

begin

	--vypocet nasledujiciho stavu automatu
	nstate_logic: process(CLK, RST)
	begin
	--vychozi hodnoty signalu, na kterych zavisi pocitani Q(i+1):
	shiftenabled <= '0';
	--automat defaultne zustava ve stejnem stavu
	next_state <= state;
        	case state is
            		when IDLE =>
                		if START_BIT = '1' and shiftenabled = '0' then
								--pokud je DIN=0 a neprobiha vysilani, prejde do stavu START a zapne rezim prijmani vysilani (shift enabled)
                    			next_state <= START;
								shiftenabled <= '1';
                		end if;
            		when START =>
                    	if rstcnt = '1' then
							--po resetu pocitadel vzorkovani a prijatych bitu se prejde do stavu DATA, kde se prijmaji data bity
							next_state <= DATA;
						end if;
            		when DATA =>
                		if WORD_END = '1' then
								--pri signalu indikujicim prijeti posledniho bitu se prejde do stavu STOP
                    			next_state <= STOP;
                		end if;
            		when STOP =>
							--ve stavu stop se setrva jeden cyklus hodin a prechazi se automaticky do stavu IDLE
                    		next_state <= IDLE;
			end case;
			--pri resetu se resetuje i nasledujici stav na IDLE
			if RST = '1' then
				next_state <= IDLE;
			end if;
	end process;

	--registr ukladajici momentalni stav
	pstatereg: process(CLK)
	begin
		if rising_edge(CLK) then
        		if RST = '1' then
						--pri resetu se stav vrati do IDLE
                		state <= IDLE;
            		else
						--kazdy cyklus CLK updatuje momentalni stav
                		state <= next_state;
            		end if;
        	end if;
	end process;

	--vystupy automatu pro jednotlive stavy
	output_logic: process(state)
	begin
		--defaultni hodnoty vystupu automatu:
    	SHIFT_EN	<= '1';
		RST_CNT		<= '0';
		SAMPLE_OUT	<= '0';
		VALID		<= '0';
		rstcnt 		<= '0';

        	case state is
            		when IDLE =>
                		SHIFT_EN <= '0';
            		when START =>
                		RST_CNT	<= '1';
						rstcnt <= '1';
            		when DATA =>
						if (SAMPLE_IN = '1' and WORD_END = '0') then
							--pri prijmuti signalu ohlasujiciho prostredek prijmaneho bitu nahraje hodnotu DIN do registru,
							--pokud nebylo jiz prijmuto vsech 8 bbytu
                			SAMPLE_OUT	<= '1';
						end if;
            		when STOP =>
						--ve stavu stop potvrdi signalem VALID korektnost vystupu
						valid <= '1';						
        	end case;
	end process;

end architecture;
