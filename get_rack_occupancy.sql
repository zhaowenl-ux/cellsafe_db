-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);
DROP FUNCTION cells.get_rack_occupancy(integer);
CREATE OR REPLACE FUNCTION  cells.get_rack_occupancy(
	IN  p_tank_id	integer
)
RETURNS TABLE (
         rack_id        integer,
         rack_name      text,
         rack_desc      text,
         box_count      integer,
         vial_count     integer,
         vial_used      integer
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE 
    var_r record;
BEGIN
    FOR var_r IN(
        SELECT id, name, "desc" from cells.inv_container where parent_id = p_tank_id order by id                 
         )
    LOOP
        rack_id         := var_r.id;
        rack_name       := var_r.name;
        rack_desc       := var_r.desc;
        SELECT sum(capacity) FROM cells.inv_container where parent_id = var_r.id INTO vial_count;
        SELECT count(id) FROM cells.inv_container where parent_id = var_r.id INTO box_count;
        select count(vial_id) from cells.inv_vial where cont_id in (
            SELECT id FROM cells.inv_container where parent_id = var_r.id)
        INTO vial_used;
        RETURN NEXT;
    END LOOP;
    
END;
$BODY$;
ALTER FUNCTION cells.get_rack_occupancy(integer)
    OWNER TO cell;
