-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.mod_cell_batch(
	INOUT p_id                  integer,
    IN p_accession_id          	integer,
    IN p_name                   text,
    IN p_alt_name              	text,
    IN p_parent_batch          	integer,
    IN p_material_state        	text,
    IN p_cells_per_vial        	float,
    IN p_cells_per_ml          	float,
    IN p_passage               	integer,
    IN p_eln                   	text,
    IN p_contact_person        	integer,
    IN p_culture_type          	text,
    IN p_culture_protocol      	text,
    IN p_dissociation_solution 	text,
    IN p_medium_growth         	text,
    IN p_medium_growth_suppl   	text,
    IN p_medium_freezing       	text,
    IN p_comments              	text,
    IN p_t1                    	text,
    IN p_t2                    	text,
    IN p_t3                    	text,
    IN p_t4                    	text,
    IN p_created_at             text
)
LANGUAGE 'plpgsql'
AS $BODY$
declare
    v_created_at date;
BEGIN
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN
    if (p_created_at is null or length(p_created_at) = 0) THEN
        v_created_at := null;
    else
        v_created_at := to_date(p_created_at, 'YYYY-MM-DD');
    end if;
    IF (p_id < 0) THEN
		insert into cells.cell_batch (accession_id, name, alt_name, parent_batch, material_state        
                        ,cells_per_vial,  cells_per_ml ,passage ,eln,contact_person,culture_type          
                        ,culture_protocol, dissociation_solution, medium_growth, medium_growth_suppl   
                        ,medium_freezing,comments,t1,t2,t3,t4,created_at,is_active)             
 
			values (p_accession_id,p_name ,p_alt_name,p_parent_batch,p_material_state,p_cells_per_vial        
                , p_cells_per_ml , p_passage ,p_eln , p_contact_person, p_culture_type, p_culture_protocol      
                , p_dissociation_solution , p_medium_growth , p_medium_growth_suppl , p_medium_freezing , p_comments , p_t1                     
                , p_t2, p_t3, p_t4 , v_created_at, true                 
)
			returning id into p_id;
	ELSE
		update cells.cell_batch
			set   accession_id          = p_accession_id          
                , name                  = p_name                  
                , alt_name              = p_alt_name              
                , parent_batch          = p_parent_batch          
                , material_state        = p_material_state        
                , cells_per_vial        = p_cells_per_vial        
                , cells_per_ml          = p_cells_per_ml          
                , passage               = p_passage               
                , eln                   = p_eln                   
                , contact_person        = p_contact_person        
                , culture_type          = p_culture_type          
                , culture_protocol      = p_culture_protocol      
                , dissociation_solution = p_dissociation_solution 
                , medium_growth         = p_medium_growth         
                , medium_growth_suppl   = p_medium_growth_suppl   
                , medium_freezing       = p_medium_freezing       
                , comments              = p_comments              
                , t1                    = p_t1                    
                , t2                    = p_t2                    
                , t3                    = p_t3                    
                , t4                    = p_t4                  

			where id = p_id;
	
	END IF;
	COMMIT;
END;
$BODY$;
ALTER PROCEDURE cells.mod_cell_batch(integer,integer,text,text,integer,text,float,float, integer, text
    ,integer, text, text ,text, text, text, text, text, text, text, text,text,text
)
    OWNER TO cell;
