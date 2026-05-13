-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_user(
	INOUT p_id	integer,
    IN  p_full_name	text,
    IN  p_email	text,
    IN  p_alt_id	text
)
LANGUAGE 'plpgsql'
AS $BODY$
BEGIN

    IF (p_id < 0) THEN
		insert into cells.user ( full_name, email, alt_id, is_active)
			values ( p_full_name, p_email, p_alt_id,  true)
			returning id into p_id;
	ELSE
		update cells.user
        set     full_name	= p_full_name
            ,   email	    = p_email
            ,   alt_id	    = p_alt_id
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_user(integer, text, text, text)
    OWNER TO cell;
