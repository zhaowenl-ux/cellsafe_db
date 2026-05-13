-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION  cells.can_fill_order(
	IN  p_user	    integer,
    IN  p_batch_id  integer
)
RETURNS text
LANGUAGE 'plpgsql'
AS $BODY$
declare
    v_count integer;
    rec     integer;
BEGIN
    -- check if the box belongs to a group
    -- find the inventory data
    For rec in SELECT distinct box_owner  FROM cells.cell_v_inventory where mat_id = p_batch_id loop
        select count(user_id) into v_count
            from cells.user_group_member
                where group_id = rec
                    and user_id = p_user;
        if (v_count > 0){
            return 'Y';
        }
    end loop;
    
    return 'N';
END;
$BODY$;
ALTER FUNCTION cells.can_fill_order(integer,integer)
    OWNER TO cell;
