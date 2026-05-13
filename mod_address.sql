-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_address(
	INOUT p_id	integer,
    IN  p_name	text,
    IN  p_company	text,
    IN  p_address	text,
    IN  p_email	text,
    IN  p_phone	text
)
LANGUAGE 'plpgsql'
AS $BODY$

BEGIN
/*  
     id        | integer                |           | not null | nextval('cells.lst_address_id_seq'::regclass)
 name      | character varying(64)  |           | not null |
 company   | character varying(64)  |           |          |
 address   | character varying(512) |           |          |
 email     | character varying(128) |           |          |
 phone     | character varying(32)  |           |          |
*/
    IF (p_id < 0) THEN
		insert into cells.lst_address ( name, company, address, email, phone, is_active)
			values ( p_name, p_company, p_address, p_email, p_phone, true)
			returning id into p_id;
	ELSE
		update cells.lst_address
        set name	    = p_name
            ,   company	    = p_company
            ,   address	    = p_address
            ,   email	    = p_email
            ,   phone	    = p_phone
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_address(integer, text, text, text, text, text)
    OWNER TO cell;
