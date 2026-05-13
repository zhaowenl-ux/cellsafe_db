-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE  cells.cancel_order(
	IN  p_id	    integer,
    IN  p_user      integer
)
LANGUAGE 'plpgsql'
AS $BODY$

BEGIN
   -- record the decision in the history table
   insert into cells.history 
        ("type", entity_id, who, "when", what) values
        ('ORDER', p_id, p_user, CURRENT_DATE, 'Cancel Order');
    update cells.cell_order set status = 'CANCELLED' where id = p_id;
    commit;
END;
$BODY$;
ALTER PROCEDURE cells.cancel_order(integer,integer)
    OWNER TO cell;
