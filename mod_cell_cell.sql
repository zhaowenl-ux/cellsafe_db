-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_cell_cell(
	INOUT p_id integer,
	IN p_name text,
	IN p_disease text,
	IN p_source_tissue text,
	IN p_source_type text,
	IN p_species smallint,
	IN p_cellosaurus_id text,
	IN p_reference text,
	IN p_comments text,
	IN p_t1 text,
	IN p_t2 text,
	IN p_t3 text)
LANGUAGE 'plpgsql'
AS $BODY$
BEGIN
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN
    IF (p_id < 0) THEN
		insert into cells.cell_cell ( name ,disease,source_tissue ,source_type    
	 			, species ,cellosaurus_id , reference , comments 
				, t1, t2 ,t3 )
			values ( p_name, p_disease, p_source_tissue, p_source_type    
	 				,p_species, p_cellosaurus_id, p_reference, p_comments       
	 				,p_t1, p_t2, p_t3)
			returning id into p_id;
	ELSE
		update cells.cell_cell
			set name           = p_name           
	 		   ,disease        = p_disease        
	 			,source_tissue  = p_source_tissue  
	 			,source_type    = p_source_type    
	 			,species        = p_species        
	 			,cellosaurus_id = p_cellosaurus_id 
	 			,reference      = p_reference      
	 			,comments       = p_comments       
	 			,t1             = p_t1             
	 			,t2             = p_t2             
	 			,t3             = p_t3
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_cell_cell(integer, text, text, text, text, smallint, text, text, text, text, text, text)
    OWNER TO cell;
