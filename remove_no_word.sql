create or replace function cells.remove_no_word(instr text)
   returns text
   language plpgsql
  as
$$

begin
   if instr is null then
      return '';
    else
        return upper(replace(regexp_replace(instr, '\W', '', 'g'), '_', ''));
   end if;
end;
$$;