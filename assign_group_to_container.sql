-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.assign_group_to_container(
	INOUT p_container_id	integer,
    IN    p_group_id	    integer
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_name  text;
    v_type  text;
BEGIN
    select group_name into v_name from cells.user_group where id = p_group_id;
    select type into v_type from cells.inv_container where id = p_container_id;

    if v_type = 'TANK' then
        update cells.inv_container
            set n1 = p_group_id
            ,   t1 = v_name
            where id in (select id from cells.inv_container 
                            where parent_id in 
                            (select id from cells.inv_container where parent_id = p_container_id))
                and n1 is null;
    elsif v_type = 'RACK' then
        update cells.inv_container
            set n1 = p_group_id
            ,   t1 = v_name
            where id in (select id from cells.inv_container where parent_id = p_container_id)
                and n1 is null;
        
    elsif  v_type = 'BOX' then
        -- update group no matter if the group is assigned
        update cells.inv_container 
            set   n1 = p_group_id
                , t1 = v_name
            where id = p_container_id;
        
    end if;
	commit;
END;
$BODY$;
ALTER PROCEDURE cells.assign_group_to_container(integer, integer)
    OWNER TO cell;
