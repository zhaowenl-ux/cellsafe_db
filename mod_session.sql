-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_session(
	INOUT p_id	    text,
    IN  p_email	    text,
    IN  p_expired   integer
)
LANGUAGE 'plpgsql'
AS $BODY$
declare 
    v_existed integer;
    v_user_id integer;
BEGIN
    select count(id) into v_existed
        from cells.app_session
        where id = p_id
            and email = p_email;
    
    SELECT id into v_user_id
        FROM cells."user" 
        where lower(email) = lower(p_email);

    if (v_existed > 0) THEN
        update cells.app_session
            set user_id = v_user_id
            ,   expired = current_date + p_expired
            where id = p_id
                and email  = p_email;
    ELSE
        insert into cells.app_session(id, user_id, email, expired)
            values(p_id, v_user_id, p_email, current_date + p_expired);
    end if;
END;
$BODY$;
ALTER PROCEDURE cells.mod_session(text, text, integer)
    OWNER TO cell;
