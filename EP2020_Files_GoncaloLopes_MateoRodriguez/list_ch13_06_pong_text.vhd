-- Listing 13.6
library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
entity pong_text is
   port(
      clk, reset: in std_logic;
      pixel_x, pixel_y: in std_logic_vector(9 downto 0);
      dig0, dig1: in std_logic_vector(3 downto 0);
      ball: in std_logic_vector(1 downto 0);
      text_on: out std_logic_vector(4 downto 0);
      text_rgb: out std_logic_vector(2 downto 0)
   );
end pong_text;

architecture arch of pong_text is
   signal pix_x, pix_y: unsigned(9 downto 0);
   signal rom_addr: std_logic_vector(10 downto 0);
   signal char_addr, char_addr_s, char_addr_l, char_addr_r,
          char_addr_o, char_addr_w: std_logic_vector(6 downto 0);
   signal row_addr, row_addr_s, row_addr_l,row_addr_r,
          row_addr_o, row_addr_w: std_logic_vector(3 downto 0);
   signal bit_addr, bit_addr_s, bit_addr_l,bit_addr_r,
          bit_addr_o, bit_addr_w: std_logic_vector(2 downto 0);
   signal font_word: std_logic_vector(7 downto 0);
   signal font_bit: std_logic;
   signal score_on, logo_on, rule_on, over_on, win_on: std_logic;
   signal rule_rom_addr: unsigned(5 downto 0);
   type rule_rom_type is array (0 to 63) of
       std_logic_vector (6 downto 0);
   -- rull text ROM definition
   constant RULE_ROM: rule_rom_type :=
   (
      -- row 1
      "1010010", -- R
      "1010101", -- U
      "1001100", -- L
      "1000101", -- E
      "0111010", -- :
      "0000000", --
      "1010101", -- U
      "1110011", -- s
      "1100101", -- e
      "0000000", --
      "1100110", -- f
      "1101111", -- o
      "1110101", -- u
      "1110010", -- r
      "0000000", --
      "0000000", --
      -- row 2
      "1100010", -- b
      "1110101", -- u
      "1110100", -- t
      "1110100", -- t
      "1101111", -- o
      "1101110", -- n
      "1110011", -- s
      "0000000", --
      "1110100", -- t
      "1101111", -- o
		"0000000", --
      "1101101", -- m
      "1101111", -- o
      "1110110", -- v
      "1100101", -- e
		"0000000", --
      -- row 3
      "1100001", -- a
      "1101110", -- n
      "1100100", -- d
      "0000000", -- 
      "1101111", -- o
      "1101110", -- n
      "1100101", -- e
      "0000000", --
      "1110100", -- t
      "1101111", -- o
      "0000000", -- 
      "0000000", -- 
      "0000000", -- 
      "0000000", -- 
      "0000000", -- 
      "0000000", -- 
      -- row 4
      "1110011", -- s 
      "1101000", -- h 
      "1101111", -- o 
      "1101111", -- o
      "1110100", -- t
      "0101110", -- .
      "0000000", -- 
      "0000000", -- 
      "0000000", -- 
      "0000000", -- 
      "0000000", -- 
      "0000000", -- 
      "0000000", --
      "0000000", --
      "0000000", --
      "0000000"  --
		
   );
begin
   pix_x <= unsigned(pixel_x);
   pix_y <= unsigned(pixel_y);
   -- instantiate font rom
   font_unit: entity work.font_rom
      port map(clk=>clk, reset=>reset, addr=>rom_addr, data=>font_word);

   ---------------------------------------------
   -- score region
   --  - display two-digit score, ball on top left
   --  - scale to 16-by-32 font
   --  - line 1, 16 chars: "Score:DD Ball:D"
   ---------------------------------------------
   score_on <=
      '1' when pix_y(9 downto 5)=14 and
               (3<= pix_x(9 downto 6) and pix_x(9 downto 6)<=6) else --pix_x(9 downto 4)<16 else 
      '0';
   row_addr_s <= std_logic_vector(pix_y(4 downto 1));
   bit_addr_s <= std_logic_vector(pix_x(3 downto 1));
   with pix_x(7 downto 4) select
     char_addr_s <=
		  "1001100" when "1101", -- L x4c
        "1101001" when "1110", -- i x69
		  "1100110" when "1111", -- f x66
        "1100101" when "0000", -- e x65
        "0111010" when "0001", -- :
		  "01100" & ball when "0010",
        "1001100" when "0100", -- L x4c
        "1100101" when "0101", -- e x65
        "1110110" when "0110", -- v x76
        "1100101" when "0111", -- e x65
        "1101100" when "1000", -- l x6c
        "0111010" when "1001", -- : x3a
        "011" & dig1 when "1010", -- digit 10
        "011" & dig0 when "1011", -- digit 1
        "0000000" when "1100",
        "0000000" when others;
        
        
        

   ---------------------------------------------
   -- logo region:
   --   - display logo "PONG" on top center
   --   - used as background
   --   - scale to 64-by-128 font
   ---------------------------------------------
   logo_on <=
      '1' when pix_y(9 downto 7)=2 and
         (3<= pix_x(9 downto 6) and pix_x(9 downto 6)<=6) else
      '0';
   row_addr_l <= std_logic_vector(pix_y(6 downto 3));
   bit_addr_l <= std_logic_vector(pix_x(5 downto 3));
   with pix_x(8 downto 6) select
     char_addr_l <=
        "0110010" when "011", -- P x50 2
        "0110000" when "100", -- O x4f 0
        "0110010" when "101", -- N x4e 2
        "0110000" when others; --G x47 0
   ---------------------------------------------
   -- rule region
   --   - display rule (4-by-16 tiles)on center
   --   - rule text:
   --        Rule:
   --        Use two buttons
   --        to move paddle
   --        up and down
   ---------------------------------------------
   rule_on <= '1' when pix_x(9 downto 7) = "010" and
                       pix_y(9 downto 6)=  "0010"  else
              '0';
   row_addr_r <= std_logic_vector(pix_y(3 downto 0));
   bit_addr_r <= std_logic_vector(pix_x(2 downto 0));
   rule_rom_addr <= pix_y(5 downto 4) & pix_x(6 downto 3);
   char_addr_r <= RULE_ROM(to_integer(rule_rom_addr));
   ---------------------------------------------
   -- game over region
   --  - display }Game Over" on center
   --  - scale to 32-by-64 fonts
   ---------------------------------------------
   over_on <=
      '1' when pix_y(9 downto 6)=3 and
         5<= pix_x(9 downto 5) and pix_x(9 downto 5)<=13 else
      '0';
   row_addr_o <= std_logic_vector(pix_y(5 downto 2));
   bit_addr_o <= std_logic_vector(pix_x(4 downto 2));
   with pix_x(8 downto 5) select
     char_addr_o <=
        "1000111" when "0101", -- G x47
        "1100001" when "0110", -- a x61
        "1101101" when "0111", -- m x6d
        "1100101" when "1000", -- e x65
        "0000000" when "1001", --
        "1001111" when "1010", -- O x4f
        "1110110" when "1011", -- v x76
        "1100101" when "1100", -- e x65
        "1110010" when others; -- r x72
	   ---------------------------------------------
   -- win region
   --  - display "WIN" on center
   --  - scale to 32-by-64 fonts
   ---------------------------------------------
   win_on <=
      '1' when pix_y(9 downto 6)=1 and
         5<= pix_x(9 downto 5) and pix_x(9 downto 5)<=13 else
      '0';
   row_addr_w <= std_logic_vector(pix_y(5 downto 2));
   bit_addr_w <= std_logic_vector(pix_x(4 downto 2));
   with pix_x(8 downto 5) select
     char_addr_w <=
		  "0010000" when "0101", -- < x10
        "1010111" when "0110", -- W x57
        "1101001" when "0111", -- i x69
        "1101110" when "1000", -- n x6e
        "1101110" when "1001", -- n x6e
        "1100101" when "1010", -- e x65
        "1110010" when "1011", -- r x72
        "0010011" when "1100", -- !! x13
        "0010001" when others; -- > x11
   ---------------------------------------------
   -- mux for font ROM addresses and rgb
   ---------------------------------------------
   process(win_on,score_on,logo_on,rule_on,pix_x,pix_y,font_bit,
           char_addr_s,char_addr_l,char_addr_r,char_addr_o, char_addr_w,
           row_addr_s,row_addr_l,row_addr_r,row_addr_o, row_addr_w,
           bit_addr_s,bit_addr_l,bit_addr_r,bit_addr_o, bit_addr_w)
   begin
      text_rgb <= "001";  -- background, blue
      if score_on='1' then
         char_addr <= char_addr_s;
         row_addr <= row_addr_s;
         bit_addr <= bit_addr_s;
         if font_bit='1' then
            text_rgb <= "111";
         end if;
      elsif rule_on='1' then
         char_addr <= char_addr_r;
         row_addr <= row_addr_r;
         bit_addr <= bit_addr_r;
         if font_bit='1' then
            text_rgb <= "111";
         end if;
      elsif logo_on='1' then
         char_addr <= char_addr_l;
         row_addr <= row_addr_l;
         bit_addr <= bit_addr_l;
         if font_bit='1' then
            text_rgb <= "111";
         end if;
		elsif win_on='1' then
         char_addr <= char_addr_w;
         row_addr <= row_addr_w;
         bit_addr <= bit_addr_w;
         if font_bit='1' then
            text_rgb <= "110";
         end if;
      else -- game over
         char_addr <= char_addr_o;
         row_addr <= row_addr_o;
         bit_addr <= bit_addr_o;
         if font_bit='1' then
            text_rgb <= "100";
         end if;
      end if;
   end process;
   text_on <= win_on & score_on & logo_on & rule_on & over_on ;
   ---------------------------------------------
   -- font rom interface
   ---------------------------------------------
   rom_addr <= char_addr & row_addr;
   font_bit <= font_word(to_integer(unsigned(not bit_addr)));
end arch;