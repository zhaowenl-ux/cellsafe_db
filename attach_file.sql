-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION  cells.attach_file(
	IN  p_entity_type text,    
    IN  p_entity_id   integer,
    IN  p_file_name   text,
    IN  p_file_mime   text  
)
returns  integer
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_id  integer;
BEGIN
   -- record the decision in the history table
   insert into cells.document (entity_type, entity_id, file_name, file_mime) 
        values(p_entity_type, p_entity_id, p_file_name, p_file_name)
        returning id into v_id; 
    
    --commit;

    return v_id;
END;
$BODY$;
ALTER FUNCTION cells.attach_file(text, integer,text, text)
    OWNER TO cell;
