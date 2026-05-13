-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION  cells.can_access_box(
	IN  p_box_id	integer,
    IN  p_user_id   integer
)
RETURNS text
LANGUAGE 'plpgsql'
AS $BODY$
declare
    v_group_id  integer;
    v_count     integer;
BEGIN
    -- check if the box belongs to a group
    select n1 into v_group_id
        from cells.inv_container
        where id = p_box_id;

    -- check if there is a group assigned
    if v_group_id is not null then
        -- check if the user belongs to the group
        select count(*) into v_count
            from cells.user_group_member
            where group_id = v_group_id
              and user_id = p_user_id;

        if v_count = 0 then
            return 'N';
        else
            return 'Y';
        end if;
    else
        return 'Y'; -- no group assigned, everyone has access
    end if;
    
END;
$BODY$;
ALTER FUNCTION cells.can_access_box(integer,integer)
    OWNER TO cell;
