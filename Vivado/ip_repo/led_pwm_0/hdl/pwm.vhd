library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm is
  generic (
    G_DATA_WIDTH : integer := 32
  );
  port (
    -- Clock Signal
    f_aclk : in std_logic;
    -- Reset Signal. This Signal is Active LOW
    i_aresetn : in std_logic;
    i_pwm_module : in std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    i_pwm_width : in std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    -- The PWM-ed output
    o_pwm : out std_logic
  );
end pwm;

architecture arch_imp of pwm is

  signal s_max_count : unsigned(G_DATA_WIDTH - 1 downto 0);
  signal s_pwm_counter : unsigned(G_DATA_WIDTH - 1 downto 0);
  signal s_pwm_width : unsigned(G_DATA_WIDTH - 1 downto 0);
  signal s_tc_pwm_counter : std_logic;

begin
  s_tc_pwm_counter  <= '0' when(s_pwm_counter < s_max_count) else '1';  -- use to strobe new word

  p_state_out : process(f_aclk, i_aresetn)
  begin
    if (i_aresetn = '0') then
      s_max_count <= (others=>'0');
      s_pwm_width <= (others=>'0');
      s_pwm_counter <= (others=>'0');
      o_pwm <= '0';
    elsif (rising_edge(f_aclk)) then
      s_max_count <= unsigned(i_pwm_module);
      if (s_pwm_counter = 0) and (s_pwm_width /= s_max_count) then
        o_pwm <= '0';
      elsif (s_pwm_counter <= s_pwm_width) then
        o_pwm <= '1';
      else
        o_pwm <= '0';
      end if;
          
      if (s_tc_pwm_counter='1') then
        s_pwm_width <= unsigned(i_pwm_width);
      end if;
          
      if (s_pwm_counter = s_max_count) then
        s_pwm_counter <= to_unsigned(0, G_DATA_WIDTH);
      else
        s_pwm_counter <= s_pwm_counter + 1;
      end if;
    end if;
  end process p_state_out;
end arch_imp;
    