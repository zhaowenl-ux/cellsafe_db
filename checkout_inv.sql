-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE  cells.checkout_inv(
	IN  p_vial_id	integer
)
LANGUAGE 'plpgsql'
AS $BODY$
declare
    v_barcode       text;
    v_checkout_name text;
    v_checkout_id   integer;
BEGIN
    -- check if the vial has barcode
    select barcode into v_barcode
        from cells.inv_vial
        where vial_id = p_vial_id;

    if v_barcode is null then 
        -- delete the vial
        delete from cells.inv_vial where vial_id = p_vial_id;
    else
        SELECT "key" into v_checkout_name FROM cells.cell_dict where name ='CHECKOUT_CONT';
        SELECT id into v_checkout_id FROM cells.inv_container where name = v_checkout_name;
        update cells.inv_vial
            set cont_id = v_checkout_id
            where vial_id = p_vial_id;
    end if;
    
    
END;
$BODY$;
ALTER PROCEDURE cells.checkout_inv(integer)
    OWNER TO cell;
