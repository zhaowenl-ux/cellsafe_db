-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_user_pref(
	IN  p_user	integer,
    IN  p_page	text,
    IN  p_pref	text
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_existed integer;
BEGIN
    select count("user")  into v_existed from cells.app_user_pref 
        where "user" = p_user
            and "page" = p_page;
    if (v_existed > 0) THEN
        -- update
        update cells.app_user_pref
            set pref = p_pref
            where "user" = p_user
                and "page" = p_page;
	ELSE
        -- insert
		insert into cells.app_user_pref ("user", "page", pref)
            values(p_user, p_page, p_pref);	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_user_pref(integer, text, text)
    OWNER TO cell;
