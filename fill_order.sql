-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE  cells.fill_order(
	IN  p_id	    integer,
    IN  p_user      integer,
    IN  p_msg       text
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_what  text;
BEGIN
   -- record the decision in the history table
   insert into cells.history 
        ("type", entity_id, who, "when", what) values
        ('ORDER', p_id, p_user, CURRENT_DATE, 'Fill Order ' || COALESCE(p_msg, ''));
    update cells.cell_order set status = 'FILLED' where id = p_id;
    commit;
END;
$BODY$;
ALTER PROCEDURE cells.fill_order(integer,integer, text)
    OWNER TO cell;
