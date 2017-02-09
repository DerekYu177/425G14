when READ_MISS =>
    m_addr <= to_integer(unsigned(s_addr));
    m_read <= '1';
    m_write <= '0';
    next_state <= LOAD_1;

when LOAD_1 =>
  if m_waitrequest == '0' then
    -- we assume a mapping of left->right in cache to top->down in memory
    read_data(31 downto 23) <= m_writedata;
    m_addr <= to_integer(unsigned(s_addr) + 1);
    next_state <= LOAD_2;
  else
    next_state <= LOAD_1;
  end if;

when LOAD_2 =>
  if m_waitrequest == '0' then
    read_data(23 downto 15) <= m_writedata;
    m_addr <= to_integer(unsigned(s_addr) + 2);
    next_state <= LOAD_3;
  else
    next_state <= LOAD_2;
  end if;

when LOAD_3 =>
  if m_waitrequest == '0' then
    read_data(15 downto 7) <= m_writedata;
    m_addr <= to_integer(unsigned(s_addr) + 3);
    next_state <= LOAD_FINISHED;
  else
    next_state <= LOAD_3;
  end if;

when LOAD_FINISHED =>
  if m_waitrequest == '0' then
    m_read <= '0';
    read_data(7 downto 0) <= m_writedata;
    -- we want to use the same process for reads AND writes
    if command_read == '1' then
      next_state <= READ_TO_USER;
    else -- write
      next_state <= WRITE_MISS;
    end if;
  else
    next_state <= LOAD_FINISHED;
  end if;
