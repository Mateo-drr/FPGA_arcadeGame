-- Listing 13.10
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity pong_top is
   port(
      clock, reset: in std_logic;
      btn: in std_logic_vector (3 downto 0);
		shoot: in std_logic;
      hsync, vsync, led: out std_logic;
      rgb: out   std_logic_vector (2 downto 0);
	  outred: out std_logic_vector(2 downto 0);
	  outgreen: out std_logic_vector(2 downto 0);
	  outblue: out std_logic_vector(1 downto 0);
	  ps2d,ps2c: in std_logic
   );
end pong_top;

architecture arch of pong_top is
   type state_type is (newgame, play, playII, playIII, over, win, newball, miss_state);	--, next_lvl
   signal state_reg, state_next: state_type;	
   signal clk: std_logic;
	signal video_on, pixel_tick: std_logic;
   signal pixel_x, pixel_y: std_logic_vector (9 downto 0);
	--signal graph_on, gra_still, hit, miss: std_logic;
   signal graph_on, gra_still, miss: std_logic;
   signal text_on: std_logic_vector(4 downto 0);
   signal graph_rgb, text_rgb: std_logic_vector(2 downto 0);
   signal rgb_reg, rgb_next: std_logic_vector(2 downto 0);
   signal dig1: std_logic_vector(3 downto 0);
   signal d_inc, d_clr: std_logic;
	signal lvl_reg, lvl_next: std_logic_vector(1 downto 0);
   signal timer_tick, timer_start, timer_up: std_logic;
   signal life_reg, life_next: unsigned(1 downto 0);
	signal dig0_next, dig0_reg : unsigned(2 downto 0);
   signal ball: std_logic_vector(1 downto 0);
	signal lvld: std_logic_vector(3 downto 0);
	signal hiteI, hiteII, hiteIII: std_logic;
	--signal level: std_logic_vector(1 downto 0);
	signal restart_enemy: std_logic_vector(2 downto 0):= "111";
	
	--signal key_code: std_logic_vector(7 downto 0);
	signal arrows: std_logic_vector(4 downto 0);
	signal kb_buf_empty: std_logic;
	--signal ps2d, ps2c: std_logic;
	signal rd_key_code: std_logic;
	
begin

   -- instantiate clock manager unit
	-- this unit converts the 25MHz input clock to the expected 50MHz clock
	ClockManager_unit: entity work.clockmanager 
	  port map(
		CLKIN_IN => clock,
		RST_IN => reset,
		CLK2X_OUT => clk,
		LOCKED_OUT => led);

   -- instantiate video synchonization unit
   vga_sync_unit: entity work.vga_sync
      port map(clk=>clk, reset=>reset, 
               hsync=>hsync, vsync=>vsync,
               pixel_x=>pixel_x, pixel_y=>pixel_y,
               video_on=>video_on, p_tick=>pixel_tick);
   -- instantiate text module
   ball <= std_logic_vector(life_reg);  --type conversion
	lvld <= "00" & lvl_reg;
   text_unit: entity work.pong_text
      port map(clk=>clk, reset=>reset,
               pixel_x=>pixel_x, pixel_y=>pixel_y,
               dig0=>lvld, dig1=>dig1, ball=>ball,
               text_on=>text_on, text_rgb=>text_rgb);
   -- instantiate graph module
   graph_unit: entity work.pong_graph
      port map(clk=>clk, reset=>reset, btn=>btn, shoot=>shoot,
              pixel_x=>pixel_x, pixel_y=>pixel_y,
              gra_still=>gra_still, miss=>miss, rst_enemy=> restart_enemy,
              graph_on=>graph_on,rgb=>graph_rgb, d_inc=> d_inc, d_clr=>d_clr,
				  hiteI=>hiteI, hiteII=>hiteII, hiteIII=>hiteIII, arrows=>arrows);
   -- instantiate 2 sec timer
   timer_tick <=  -- 60 Hz tick
      '1' when pixel_x="0000000000" and
               pixel_y="0000000000" else
      '0';
   timer_unit: entity work.timer
      port map(clk=>clk, reset=>reset,
               timer_tick=>timer_tick,
               timer_start=>timer_start,
               timer_up=>timer_up);
					
----    instantiate 2-digit decade counter
--   counter_unit: entity work.m100_counter
--      port map(clk=>clk, reset=>reset,
--               d_inc=>d_inc, d_clr=>d_clr,
--               dig0=>dig0, dig1=>dig1);


		------------------
	
--	clk, reset: in  std_logic;
--      ps2d, ps2c: in  std_logic;
--      rd_key_code: in std_logic;
--      key_code: out std_logic_vector(7 downto 0);
--      kb_buf_empty: out std_logic
--		
	
	
--	font_unit: entity work.font_rom
--      port map(clk=>clk, reset=>reset, addr=>rom_addr, data=>font_word);
--	
	kb_code: entity work.kb_code 
	  port map(clk=>clk, reset=>reset,
					arrows=>arrows, kb_buf_empty=>kb_buf_empty,
					ps2c=>ps2c, ps2d=>ps2d, rd_key_code=>rd_key_code
		);
	
	------------------

   -- registers
   process (clk,reset)
   begin
      if reset='1' then
         state_reg <= newgame;
         life_reg <= (others=>'0');
         rgb_reg <= (others=>'0');
			lvl_reg <= (others => '0');
      elsif (clk'event and clk='1') then
         state_reg <= state_next;
         life_reg <= life_next;
			lvl_reg <= lvl_next;
         if (pixel_tick='1') then
           rgb_reg <= rgb_next;
         end if;
      end if;
   end process;
   -- fsmd next-state logic
   process(btn,miss,timer_up,state_reg,
           life_reg,life_next,hiteI,hiteII,hiteIII, dig0_reg)
	begin
		----
		gra_still <= '1';
		timer_start <= '0';
		d_inc <= '0';
		d_clr <= '0';
		state_next <= state_reg;
		life_next <= life_reg;
		lvl_next <= lvl_reg;
		---
		case state_reg is 
		
			when newgame =>
				lvl_next <= "01";
				life_next <= "11";
				lvl_next <= "01";
				d_clr <= '1';
				restart_enemy <= "110";
				
				if (btn /= "0000") or (arrows/="00000")then -- button pressed
						life_next <= life_reg - 1;
						state_next <= play;
						timer_start <= '1';  -- 2 sec timer
            end if;
				
			when play =>
				if timer_up = '1' then       
					restart_enemy <= "110";
					gra_still <= '0';
					if hiteI = '1' then       
						d_inc <= '1';
						state_next <= newball;
					elsif miss = '1' then
						state_next <= miss_state;
					end if;
				end if;
				
			when playII => 
				if timer_up = '1' then
					gra_still <= '0';
					
					if restart_enemy = "101" then
						restart_enemy <= "101";
					elsif restart_enemy = "110" then
						restart_enemy <= "110";
					else
						restart_enemy <= "100";
					end if;
			
					if (hiteI = '1' and restart_enemy = "110") or (hiteII ='1' and restart_enemy = "101") then
						d_inc <= '1';
						state_next <= newball;					
					elsif hiteI = '1' and restart_enemy = "100" then
						d_inc <= '1';
						restart_enemy <= "101";
					elsif hiteII = '1' and restart_enemy = "100" then
						d_inc <= '1';
						restart_enemy <= "110";
					end if;
					
					if miss = '1' then
						state_next <= miss_state;	
					end if;	
				end if;
				
			when playIII => 
				if timer_up = '1' then
				gra_still <= '0';
				
					if restart_enemy = "001" then
						restart_enemy <= "001";
					elsif restart_enemy = "010" then
						restart_enemy <= "010";
					elsif restart_enemy = "011" then
						restart_enemy <= "011";
					elsif restart_enemy = "100" then
						restart_enemy <= "100";
					elsif restart_enemy = "101" then
						restart_enemy <= "101";
					elsif restart_enemy = "110" then
						restart_enemy <= "110";
					else
						restart_enemy <= "000";	
					end if;
					
					if (hiteI = '1' and restart_enemy = "110") or (hiteII = '1' and restart_enemy = "101") or (hiteIII = '1' and restart_enemy = "011") then
						d_inc <= '1';
						state_next <= newball;
					elsif hiteI = '1' and restart_enemy = "100" then
						d_inc <= '1';
						restart_enemy <= "101";
					elsif hiteI = '1' and restart_enemy = "010" then
						d_inc <= '1';
						restart_enemy <= "011";
					elsif hiteI = '1' and restart_enemy = "000" then
						d_inc <= '1';
						restart_enemy <= "001";
						
					elsif hiteII = '1' and restart_enemy = "100" then
						d_inc <= '1';
						restart_enemy <= "110";
					elsif hiteII = '1' and restart_enemy = "001" then
						d_inc <= '1';
						restart_enemy <= "011";
					elsif hiteII = '1' and restart_enemy = "000" then
						d_inc <= '1';
						restart_enemy <= "010";

					elsif hiteIII = '1' and restart_enemy = "010" then
						d_inc <= '1';
						restart_enemy <= "110";
					elsif hiteIII = '1' and restart_enemy = "001" then
						d_inc <= '1';
						restart_enemy <= "101";
					elsif hiteIII = '1' and restart_enemy = "000" then
						d_inc <= '1';
						restart_enemy <= "100";
					end if;
						
					if miss = '1' then
						state_next <= miss_state;
					end if;
				end if;
				
			when newball =>
				gra_still <= '0';
				if lvl_reg = "01" then
					lvl_next <= "10";
					restart_enemy <= "100";
					timer_start <= '1';
					state_next <= playII;
					
				elsif lvl_reg = "10" then
					lvl_next <= "11";
					restart_enemy <= "000";
					timer_start <= '1';
					state_next <= playIII;
					
				elsif lvl_reg = "11" then
					timer_start <= '1';  -- 2 sec timer
					state_next <= win;
				end if;
				
			when miss_state =>
				d_clr <= '1';
				timer_start <= '1';-- 2 sec timer
				if (life_reg=0) then
					state_next <= over;
				else  
					lvl_next <= "01";
					life_next <= life_reg - 1;
					state_next <= play;
				end if;

		--------------------------------------------------
         when over =>
            -- wait for 2 sec to display game over
            if timer_up='1' then
                state_next <= newgame;
				end if;
		--------------------------------------------------
			when win =>
            -- wait for 2 sec to display win
            if timer_up='1' then
                state_next <= newgame;
				end if;
		--------------------------------------------------
			end case;
		end process;
		
--	dig0 <= dig0_reg +1 when d_inc = '1' else
--					"000" when d_clr = '0' else
--					dig0_reg;
		
	
		
   -- rgb multiplexing circuit
   process(state_reg,video_on,graph_on,graph_rgb,
           text_on,text_rgb)
   begin
      if video_on='0' then
         rgb_next <= "000"; -- blank the edge/retrace
      else
         -- display score, rule or game over
         if (text_on(3)='1') or
            (state_reg=newgame and text_on(1)='1') or -- rule
				(state_reg=newgame and text_on(2)='1') or -- logo
            (state_reg=over and text_on(0)='1') or -- game over
				(state_reg=win and text_on(4)='1') then -- win
            rgb_next <= text_rgb;
         elsif graph_on='1'  then -- display graph
				rgb_next <= graph_rgb;
         else
           rgb_next <= "111"; -- yellow background
         end if;
      end if;
   end process;
   
   outred <= rgb_reg(2) & rgb_reg(2) & rgb_reg(2);
   outgreen <= rgb_reg(1) & rgb_reg(1) & rgb_reg(1);
   outblue <= rgb_reg(0) & rgb_reg(0);
   rgb <= rgb_reg;
	
	
end arch;
