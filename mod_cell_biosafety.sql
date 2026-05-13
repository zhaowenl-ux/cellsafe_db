-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_cell_biosafety(
    INOUT   p_id	integer,
    IN      p_accession_id	integer,
    IN      p_biosafety_level	integer,
    IN      p_gmo	text,
    IN      p_gentg_level	text,
    IN      p_expiration_date	text,
    IN      p_risk_group	text,
    IN      p_risk_accessment	text,
    IN      p_contact_person	integer,
    IN      p_comment	text,
    IN      p_t1	text,
    IN      p_t2	text,
    IN      p_t3	text
)
LANGUAGE 'plpgsql'
AS $BODY$
declare
v_expiration_date date;
v_gmo boolean;
BEGIN
    if p_gmo = 'Y' THEN
        v_gmo := true;
    ELSE
        v_gmo := false;
    end if;
    if p_expiration_date is null or length(p_expiration_date) = 0 THEN
        v_expiration_date := null;
    else
        v_expiration_date := to_date(p_expiration_date, 'YYYY-MM-DD');
    end if;
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN
    IF (p_id < 0) THEN
		insert into cells.cell_biosafety (accession_id, biosafety_level, gmo, gentg_level
            ,expiration_date, risk_group, risk_accessment, contact_person, comment
            , t1, t2, t3)
			values ( p_accession_id, p_biosafety_level, v_gmo, p_gentg_level
            , v_expiration_date, p_risk_group, p_risk_accessment, p_contact_person,p_comment
            , p_t1, p_t2, p_t3)
			returning id into p_id;
	ELSE
		update cells.cell_biosafety
			set accession_id        = p_accession_id
            ,   biosafety_level	    = p_biosafety_level
            ,   gmo	                = v_gmo
            ,   gentg_level	        = p_gentg_level
            ,   expiration_date	    = v_expiration_date
            ,   risk_group	        = p_risk_group
            ,   risk_accessment	    = p_risk_accessment
            ,   contact_person	    = p_contact_person
            ,   comment	            = p_comment
            ,   t1	                = p_t1
            ,   t2	                = p_t2
            ,   t3	                = p_t3
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_cell_biosafety(integer,integer, integer, text, text, text, text, text, text, text, text,text, text)
    OWNER TO cell;
