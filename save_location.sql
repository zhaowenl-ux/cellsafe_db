-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.save_location(
	IN  p_box_id    integer,
    IN  p_user      integer,
    IN  p_page      text
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_rack_id   integer;
    v_tank_id   integer;
    v_existed   integer;
    v_pref      text;
BEGIN
    select parent_id into v_rack_id from cells.inv_container where id = p_box_id;
    select parent_id into v_tank_id from cells.inv_container where id = v_rack_id;
    select count(pref) into v_existed from cells.app_user_pref
        where "user" = p_user
            and "page" = p_page;
    
    v_pref = '{"location":[' || v_tank_id || ',' || v_rack_id || ','
            || p_box_id || ']}';

    if (v_existed > 0) then
        -- update
        update cells.app_user_pref
            set pref = v_pref
            where "user" = p_user
                and "page" = p_page;
    else
        insert into cells.app_user_pref ("user", "page", pref)
            values(p_user, p_page, v_pref);
    end if;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.save_location(integer, integer,  text)
    OWNER TO cell;
