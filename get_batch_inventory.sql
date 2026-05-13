-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION  cells.get_batch_inventory(
	IN  p_batch_id	integer,
    IN  p_user_id   integer
)
RETURNS TABLE (
         vial_id        integer,
         cont_id        integer,
         barcode        text,
         vial_status    text,
         x              integer,
         y              integer,
         "position"       text,
         mat_id         integer,
         mat_type       integer,
         vial_type      integer,
         t1             text,
         t2             text,
         t3             text,
         d1             double precision,
         d2             double precision,
         d3             double precision,
         box_id         integer,
         box_name       text,
         box_desc       text,
         box_barcode    text,
         box_owner      integer,
         box_owner_name text,
         rack_id        bigint,
         rack_name      text,
         rack_desc      text,
         rack_barcode   text,
         tank_id        bigint,
         tank_name      text,
         tank_desc      text,
         tank_barcode   text,
         material_type_name text,
         material_type_desc text,
         vial_type_name     text,
         vial_type_desc     text,
         cell_batch_name    text,
         is_visible         text
)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE 
    var_r record;
BEGIN
    FOR var_r IN(
        SELECT *                  
        FROM 
            cells.cell_v_inventory inv
        WHERE 
            inv.mat_id = p_batch_id  )
    LOOP
        vial_id         := var_r.vial_id;
        cont_id         := var_r.cont_id;
        barcode         := var_r.barcode;
        vial_status     := var_r.vial_status;
        x               := var_r.x;
        y               := var_r.y;
        position        := var_r.position;
        mat_id          := var_r.mat_id;    
        mat_type        := var_r.mat_type;
        vial_type       := var_r.vial_type;
        t1              := var_r.t1;
        t2              := var_r.t2;        
        t3              := var_r.t3;
        d1              := var_r.d1;
        d2              := var_r.d2;
        d3              := var_r.d3;
        box_id          := var_r.box_id;
        box_name        := var_r.box_name;
        box_desc        := var_r.box_desc;
        box_barcode     := var_r.box_barcode;
        box_owner       := var_r.box_owner; 
        box_owner_name  := var_r.box_owner_name;
        rack_id         := var_r.rack_id;
        rack_name       := var_r.rack_name;
        rack_desc       := var_r.rack_desc;
        rack_barcode    := var_r.rack_barcode;
        tank_id         := var_r.tank_id;
        tank_name       := var_r.tank_name;
        tank_desc       := var_r.tank_desc;
        tank_barcode    := var_r.tank_barcode;
        material_type_name := var_r.material_type_name;
        material_type_desc := var_r.material_type_desc;
        vial_type_name     := var_r.vial_type_name;
        vial_type_desc     := var_r.vial_type_desc;
        cell_batch_name    := var_r.cell_batch_name;
        is_visible := cells.can_access_box(var_r.box_owner::integer, p_user_id);
        RETURN NEXT;
    END LOOP;
    
END;
$BODY$;
ALTER FUNCTION cells.get_batch_inventory(integer,integer)
    OWNER TO cell;
