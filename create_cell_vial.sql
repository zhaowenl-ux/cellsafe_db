-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.create_cell_vial(
	INOUT p_vial_id	integer,
    IN  p_cont_id	integer,
    IN  p_barcode	text,
    IN  p_x	        integer,
    IN  p_y	        integer,
    IN  p_batch_id	integer
)
LANGUAGE 'plpgsql'
AS $BODY$
declare
    v_y text;
BEGIN
    /*`     
        vial_id     
        cont_id     
        barcode     in
        x           
        y           
        position    
        mat_id  batch_id 
        mat_type = 1
        vial_type = 1   

 */
    -- 1. Create the Tank and get tank ID
    if p_y < 10 then
        v_y := '0' || p_y::text;
    else
        v_y := p_y::text;
    end if;
    
    INSERT INTO cells.inv_vial (cont_id, barcode, x, y, position, mat_id, mat_type, vial_type)
        VALUES (p_cont_id, p_barcode, p_x, p_y, chr(64+p_x) || v_y, p_batch_id, 1, 1)
    RETURNING vial_id INTO p_vial_id;
    
END;
$BODY$;
ALTER PROCEDURE cells.create_cell_vial(integer,integer, text, integer,integer,integer)
    OWNER TO cell;
