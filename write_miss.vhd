when WRITE_MISS =>
  -- implement write allocate here
  -- write the value to main memory
  -- write the block into the cache

  if dirty == '1' then

    store_cache_data <= cache_array(row_location)(BLOCK_NUMBER-1 downto 0)

    -- store dirty memory into main memory
    m_addr <= to_integer(unsigned(s_addr));
    m_read <= '0';
    m_write <= '1';
    m_writedata <= store_cache_data(31 downto 23);
    next_state <= STORE_1;
  end if;

  -- set dirty bit
  cache_valid_dirty(row_location)(0) <= '1';

  -- try the cache again
  next_state <= FIND_COMPARE;

when STORE_1 =>
  if m_waitrequest == '0' then
    m_write <= '0';
    m_addr <= to_integer(unsigned(s_addr) + 1);
    m_writedata <= store_cache_data(23 downto 15);

    m_write <= '1';
    next_state <= STORE_2;
  else
    next_state <= STORE_1;
  end if;

when STORE_2 =>
  if m_waitrequest == '0' then
    m_write <= '0';
    m_addr <= to_integer(unsigned(s_addr) + 2);
    m_writedata <= store_cache_data(15 downto 7);

    m_write <= '1';
    next_state <= STORE_3;
  else
    next_state <= STORE_2;
  end if;

when STORE_3 =>
  if m_waitrequest == '0' then
    m_write <= '0';
    m_addr <= to_integer(unsigned(s_addr) + 2);
    m_writedata <= store_cache_data(7 downto 0);

    m_write <= '1';
    next_state <= STORE_FINISHED;
  else
    next_state <= STORE_3;
  end if;

when STORE_FINISHED =>
  if m_waitrequest == '0' then
    m_write <= '0';

    -- TODO : Anything here
    next_state <= FIND_COMPARE;
  else
    next_state <= STORE_FINISHED;
  end if;
