-- uart_rx.vhd: UART controller - receiving (RX) side
-- Author(s): Name Surname (xlogin00)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;



-- Entity declaration (DO NOT ALTER THIS PART!)
entity UART_RX is
    port(
        CLK      : in std_logic;
        RST      : in std_logic;
        DIN      : in std_logic;
        DOUT     : out std_logic_vector(7 downto 0);
        DOUT_VLD : out std_logic
    );
end entity;



-- Architecture implementation (INSERT YOUR IMPLEMENTATION HERE)
architecture behavioral of UART_RX is

	--definition of signals--
	--oznamuje automatu, zacatek vysilani v polovine start bitu
	signal broadcast_start : std_logic := '0';
	--oznamuje automatu prijeti posledniho bitu sekvence
	signal broadcast_end : std_logic := '0';
	--oznamuje automatu prostredek kazdeho bitu - carry citace 0-15
	signal midbit : std_logic := '0';
	--pokud je aktivni, je zapnute nahravani hodnot do registru
	signal shift_enabled : std_logic;
	--resetuje citace prostredku bitu a prijatych bitu
	signal cycle_rst : std_logic;
	--signal napojeny na CLK shift registru, na jeho nabezne hodnote se nahrava hodnota
	signal sample : std_logic;
	--vystupni vektor shift registeru
	signal register_out : std_logic_vector(7 downto 0);
	--signal pro citani poloviny start bitu, pri jeho carry se odesle automatu signal broadcast_start
	signal count : std_logic_vector(2 downto 0) := "000";
	--signal pro pocitani 0-15 - produkuje carry v prostredku kazdeho prijmaneho bitu
	signal countto16 : std_logic_vector(3 downto 0) := "0000";
	--signal pocitajici pocet prijatych bitu
	signal countword : std_logic_vector(3 downto 0) := "0000";
	--signal vysilany, pokud vsech 8 bitu bylo prijato
	signal valid : std_logic := '0';
	--signaly pro uvodni KO-D slouzici pro eliminaci metastabilniho stavu
	signal DIN_stable1 : std_logic := '1';
	signal DIN_stable : std_logic := '1';

begin

   	-- Instance of RX FSM
    	fsm: entity work.UART_RX_FSM
    	port map (
		CLK => CLK,
		RST => RST,
		START_BIT => broadcast_start,
		WORD_END => broadcast_end,
		SAMPLE_IN => midbit,
		SHIFT_EN => shift_enabled,
		RST_CNT => cycle_rst,
		VALID => valid
	);

	--==========================================
	--TODO LIST:
	-- * fix sampling offset
	--==========================================

	--dva KO typu D na zacatku obvodu pro eliminaci pravdepodobnosti metastabilniho stavu
	Dflipflop1 : process(CLK)
	begin
		if (rising_edge(CLK)) then
			DIN_stable1 <= DIN;
		end if;
	end process;

	Dflipflop2 : process(CLK)
	begin
		if(rising_edge(CLK)) then
			DIN_stable <= DIN_stable1;
		end if;
	end process;

	--shift register
	shiftregister : process (sample, DIN_stable, shift_enabled)
	begin
	  if rising_edge(sample) and shift_enabled = '1' then
		-- Shift the register left by one bit and concatenates DIN_stable bit--
		register_out <= DIN_stable & register_out(7 downto 1);
		-- Store the current state of the register--
	  end if;
	end process;

	--citac pocitajici prostredek start bitu pro zajisteni vzorkovani uprostred kazdeho bytu
	startcounter : process (CLK, DIN_stable)
	begin
		if rising_edge(CLK) then
			--implicitni hodnota signalu:
			broadcast_start <= '0';

			--pokud je DIN_stable = '1' a neprobiha vysilani, zacne pocitat
			if (DIN_stable = '0' and shift_enabled = '0') then
				count <= count + 1;
			end if;
			--pri carry posila signal automatu a probouzi ho ze stavu IDLE (a nuluje signal)
			if count = "111" then
				broadcast_start <= '1';
				count <= (others => '0');
			end if;

		end if;
	end process;


	--citac pocitajici prostredek kazdeho bytu - midbit
	counterto16 : process (CLK)
	begin

		if rising_edge(CLK) then
			--implicitni hodnoty:
			midbit <= '0';
			sample <= '0';

			--pri carry posila signal midbit automatu a nuluje citac, jinak pricita 1 kazdy CLK
			if countto16 = "1111" then
				midbit <= '1';
				countto16 <= (others => '0');
				sample <= '1';
			else
				countto16 <= countto16 + 1;
			end if;

			--reset na zacatku vysilani
			if cycle_rst = '1' then
				countto16 <= "0000";
			end if;

		end if;
	end process;

	--citac pocitajici prijem 8 bitu
	counterto8 : process (CLK)
	begin
		if rising_edge(CLK) then
			broadcast_end <= '0';

			--pri napocitani do 8 vysle automatu signal broadcast_end a nuluje citac, jinak inkrementuje pri kazdem midbitu
			if countword = "1000" then
				broadcast_end <= '1';
				countword <= (others => '0');
			elsif midbit = '1' then
				countword <= countword + 1;
			end if;

			--reset na zacatku vysilani
			if cycle_rst = '1' then
				countword <= "0000";
			end if;
		end if;
	end process;

    DOUT <= register_out;
	DOUT_VLD <= valid;
end architecture;
