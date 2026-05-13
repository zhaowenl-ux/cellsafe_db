-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_cell_assay(
	INOUT p_id	integer,
    IN  p_assay	text,
    IN  p_pass	text,
    IN  p_eln	text,
    IN  p_exp_date	text,
    IN  p_control	text,
    IN  p_op	text,
    IN  p_result	numeric,
    IN  p_comment	text,
    IN  p_batch_id	integer,
    IN  p_result_unit	text
)
LANGUAGE 'plpgsql'
AS $BODY$
declare
v_exp_date date;
v_pass boolean;
BEGIN
    if p_pass = 'pass' THEN
        v_pass := true;
    ELSE
        v_pass := false;
    end if;
    if p_exp_date is null or length(p_exp_date) = 0 THEN
        v_exp_date := null;
    else
        v_exp_date := to_date(p_exp_date, 'YYYY-MM-DD');
    end if;
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN
    IF (p_id < 0) THEN
		insert into cells.cell_assay ( assay, pass, eln, exp_date, control, op
                , result, comment, batch_id, result_unit)
			values ( p_assay, v_pass, p_eln, v_exp_date, p_control, p_op
                , p_result, p_comment, p_batch_id, p_result_unit)
			returning id into p_id;
	ELSE
		update cells.cell_assay
			set assay	    = p_assay
            ,   pass	    = v_pass
            ,   eln	        = p_eln
            ,   exp_date    = v_exp_date
            ,   control	    = p_control
            ,   op	        = p_op
            ,   result	    = p_result
            ,   comment	    = p_comment
            ,   batch_id	= p_batch_id
            ,   result_unit	= p_result_unit
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_cell_assay(integer, text, text, text, text, text, text, numeric, text, integer, text)
    OWNER TO cell;
