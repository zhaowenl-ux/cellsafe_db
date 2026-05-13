-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_cell_accession(
    INOUT p_id integer,
    IN p_cell_id	integer,
    IN p_name	text,
    IN p_eln	text,
    IN p_date_received	text,
    IN p_date_discarded	text,
    IN p_cell_source	integer,
    IN p_catalog_num	text,
    IN p_engineering_source	integer,
    IN p_reporter	integer,
    IN p_tag	integer,
    IN p_engineering_method	integer,
    IN p_pool_name	text,
    IN p_clone_name	text,
    IN p_passage	integer,
    IN p_status	text,
    IN p_contact_person	integer,
    IN p_comments	text,
    IN p_t1	text,
    IN p_t2	text,
    IN p_t3	text
)

LANGUAGE 'plpgsql'
AS $BODY$
declare
v_date_received date;
v_date_discarded date;
BEGIN
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN
    if (p_date_discarded is null or length(p_date_discarded) = 0) then
        v_date_discarded := null;
    else
        v_date_discarded := to_date(p_date_discarded, 'YYYY-MM-DD');
    end if;

    if (p_date_received is null or length(p_date_received) = 0) then
        v_date_received := null;
    else
        v_date_received := to_date(p_date_received, 'YYYY-MM-DD');
    end if;
    IF (p_id < 0) THEN
		insert into cells.cell_accession (cell_id, name, eln, date_received, date_discarded, cell_source, catalog_num, 
            engineering_source, reporter, tag, engineering_method, pool_name, clone_name, passage, status, 
            contact_person, comments, t1, t2, t3)             
			values (p_cell_id, p_name, p_eln, v_date_received, v_date_discarded, p_cell_source, p_catalog_num, 
                    p_engineering_source, p_reporter, p_tag, p_engineering_method, p_pool_name, p_clone_name, p_passage, p_status
                    , p_contact_person, p_comments, p_t1, p_t2, p_t3)
			returning id into p_id;
	ELSE
		update cells.cell_accession
			set   cell_id	            = p_cell_id
                , name	                = p_name
                , eln	                = p_eln
                , date_received         = v_date_received
                , date_discarded        = v_date_discarded
                , cell_source           = p_cell_source
                , catalog_num           = p_catalog_num
                , engineering_source    = p_engineering_source
                , reporter              = p_reporter
                , tag                   = p_tag
                , engineering_method    = p_engineering_method
                , pool_name             = p_pool_name
                , clone_name            = p_clone_name
                , passage               = p_passage
                , status                = p_status
                , contact_person        = p_contact_person
                , comments              = p_comments
                , t1                    = p_t1
                , t2                    = p_t2
                , t3                    = p_t3
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_cell_accession(integer, integer, text ,text, text, text, integer, text, integer, integer
                    ,integer, integer, text, text, integer, text, integer, text, text, text, text

)
    OWNER TO cell;
