-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.create_tank(
	INOUT p_tank_id	integer,
    IN  p_name	text,
    IN  p_freezer	integer,
    IN  p_rack	integer,
    IN  p_box_x	integer,
    IN  p_box_y	integer
)
LANGUAGE 'plpgsql'
AS $BODY$
declare
v_rack_id integer;
v_box_id integer;
v_rack_name text;
BEGIN
    /*`  id        
        parent_id 
        type      
        status    
        name      
        desc      
        barcode   
        x         
        y         
        position       
        x_size    
        y_size    
 */
    -- 1. Create the Tank and get tank ID
    INSERT INTO cells.inv_container (type, status, name, x, y, position, x_size, y_size,  capacity )
        VALUES ('TANK', 'ACTIVE', p_name, 1, 1, 'A1', p_freezer,1, p_freezer)
    RETURNING id INTO p_tank_id;
    -- 2. Create the racks and get rack ID
    FOR i IN 1..p_freezer LOOP
        v_rack_name := 'R-' || i;
        INSERT INTO cells.inv_container (parent_id,type, status, name,"desc", x, y, position, x_size, y_size, capacity)
        VALUES (p_tank_id,'RACK', 'ACTIVE', v_rack_name, 'RACK-'||i, 1, 1, 'A' || i, p_rack,1, p_rack)
        RETURNING id INTO v_rack_id;
        -- 3. Create the boxes and get box ID
        FOR j IN 1..p_rack LOOP
            INSERT INTO cells.inv_container (parent_id,type, status, name,"desc", x, y, position, x_size, y_size, capacity)
            VALUES (v_rack_id,'BOX', 'ACTIVE', v_rack_name||'-B-' || j, 'BOX-'||j, 1, 1, 'A' || j, p_box_x,p_box_y, p_box_x * p_box_y)
            RETURNING id INTO v_box_id;
        END LOOP;
    END LOOP;
END;
$BODY$;
ALTER PROCEDURE cells.create_tank(integer, text, integer,integer,integer,integer)
    OWNER TO cell;
