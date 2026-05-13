-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE  cells.approve_order(
	IN  p_id	    integer,
    IN  p_user      integer,
    IN  p_flag      integer
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_what  text;
BEGIN
   -- record the decision in the history table
   if (p_flag < 1 ) then
        v_what = 'Approve order';
   elsif (p_flag = 1) then
        v_what = 'Approve order with override one flag';
    else
        v_what = 'Approve order with override '||  p_flag || ' flag';
   end if;
   insert into cells.history 
        ("type", entity_id, who, "when", what) values
        ('ORDER', p_id,p_user, CURRENT_DATE, v_what);
    update cells.cell_order set status = 'APPROVED' where id=p_id;

    commit;
END;
$BODY$;
ALTER PROCEDURE cells.approve_order(integer,integer, integer)
    OWNER TO cell;
