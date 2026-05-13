-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_cell_order(
	INOUT p_id	integer,
    IN  p_requestor	integer,
    IN  p_cell_batch_id	integer,
    IN  p_order_date text,
    IN  p_status	text,
    IN  p_purpose	text,
    IN  p_comment	text,
    IN  p_shipping_id	integer,
    IN  p_order_needed	text,
    IN  p_rule1	text,
    IN  p_rule2	text,
    IN  p_rule3	text,
    IN  p_rule4	text,
    IN  p_rule5	text,
    IN  p_vial_needed	integer
)
LANGUAGE 'plpgsql'
AS $BODY$
declare
v_order_date date;
v_order_needed date;
v_rule1 boolean;
v_rule2 boolean;
v_rule3 boolean;
v_rule4 boolean;
v_rule5 boolean;
BEGIN
    /*  id            | bigint                 |           | not null | nextval('cells.cell_order_id_seq'::regclass)
        requestor     | integer                |           | not null |
        cell_batch_id | integer                |           | not null |
        order_date    | date                   |           |          |
        status        | character varying(8)   |           |          |
        purpose       | character varying(64)  |           |          |
        comment       | character varying(512) |           |          |
        shipping_id   | integer                |           |          |
        order_needed  | date                   |           |          |
        rule1         | boolean                |           |          |
        rule2         | boolean                |           |          |
        rule3         | boolean                |           |          |
        rule4         | boolean                |           |          |
        rule5         | boolean                |           |          |
        vial_needed   | smallint               |           |          |
 */
    -- process date fields
    if p_order_date is null or length(p_order_date) = 0 THEN
        v_order_date := null;
    else
        v_order_date := to_date(p_order_date, 'YYYY-MM-DD');
    end if;

    if p_order_needed is null or length(p_order_needed) = 0 THEN
        v_order_needed := null;
    else
        v_order_needed := to_date(p_order_needed, 'YYYY-MM-DD');
    end if;
    -- process rule fields

    if p_rule1 = 'Y' THEN
        v_rule1 := true;
    ELSE
        v_rule1 := false;
    end if;

    if p_rule2 = 'Y' THEN
        v_rule2 := true;
    ELSE
        v_rule2 := false;
    end if;

    if p_rule3 = 'Y' THEN
        v_rule3 := true;
    ELSE
        v_rule3 := false;
    end if;

    if p_rule4 = 'Y' THEN
        v_rule4 := true;
    ELSE
        v_rule4 := false;
    end if;

    if p_rule5 = 'Y' THEN
        v_rule5 := true;
    ELSE
        v_rule5 := false;
    end if;
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN
    IF (p_id < 0) THEN
		insert into cells.cell_order ( requestor,cell_batch_id,order_date,status,
        purpose,comment,shipping_id,order_needed,
        rule1,rule2,rule3,rule4,rule5,vial_needed)
			values ( p_requestor,p_cell_batch_id,v_order_date,p_status,
            p_purpose,p_comment,p_shipping_id,v_order_needed,
            v_rule1,v_rule2,v_rule3,v_rule4,v_rule5,p_vial_needed)
			returning id into p_id; 

	ELSE
		update cells.cell_order
			set requestor	    = p_requestor
            ,   cell_batch_id	= p_cell_batch_id
            ,   order_date	= v_order_date
            ,   status		= p_status
            ,   purpose		= p_purpose
            ,   comment		= p_comment
            ,   shipping_id	= p_shipping_id
            ,   order_needed	= v_order_needed
            ,   rule1			= v_rule1
            ,   rule2			= v_rule2
            ,   rule3			= v_rule3
            ,   rule4			= v_rule4
            ,   rule5			= v_rule5
            ,   vial_needed	= p_vial_needed
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_cell_order(integer, integer, integer,
    text, text, text, text, integer, 
    text, text, text, text, text, text, integer)
    OWNER TO cell;
