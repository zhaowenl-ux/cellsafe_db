-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_cell_provenance(
	INOUT p_id                  integer
    ,IN p_source              	integer
    ,IN p_source_role         	text
    ,IN p_contract_name       	text
    ,IN p_contract_expiration 	text
    ,IN p_contract_desc       	text
    ,IN p_comment             	text
    ,IN p_restriction         	text
    ,IN p_rule1               	text
    ,IN p_rule2               	text
    ,IN p_rule3               	text
    ,IN p_rule4               	text
    ,IN p_rule5               	text
    ,IN p_t1                  	text
    ,IN p_t2                  	text
    ,IN p_t3                  	text
)
LANGUAGE 'plpgsql'
AS $BODY$
declare
    v_contract_expiration date;
    v_rule1 boolean;
    v_rule2 boolean;
    v_rule3 boolean;
    v_rule4 boolean;
    v_rule5 boolean;
BEGIN
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN

    -- fix the boolean inputs
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
    -- fix the date input
    if p_contract_expiration is null or length(p_contract_expiration) = 0 THEN
        v_contract_expiration := null;
    else
        v_contract_expiration := to_date(p_contract_expiration, 'YYYY-MM-DD');
    end if;

    IF (p_id < 0) THEN
		insert into cells.cell_provenance ( source, source_role, contract_name, contract_expiration, 
                    contract_desc, comment, restriction, rule1, rule2, rule3, 
                    rule4, rule5, t1, t2, t3 )
			values ( p_source, p_source_role, p_contract_name, v_contract_expiration, 
                    p_contract_desc, p_comment, p_restriction, v_rule1,v_rule2,v_rule3,
					v_rule4,v_rule5,p_t1,p_t2,p_t3)
			returning id into p_id;
	ELSE
		update cells.cell_provenance
			set source           = p_source
                ,source_role      = p_source_role
				,contract_name    = p_contract_name
				,contract_expiration = v_contract_expiration
				,contract_desc    = p_contract_desc
				,comment          = p_comment
				,restriction      = p_restriction
				,rule1            = v_rule1
                ,rule2            = v_rule2
                ,rule3            = v_rule3
                ,rule4            = v_rule4
                ,rule5            = v_rule5
				,t1               = p_t1
				,t2               = p_t2
				,t3               = p_t3
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_cell_provenance(integer, integer,text, text, text, text, text,
 text, text, text, text, text, text, text, text, text)
    OWNER TO cell; 
			