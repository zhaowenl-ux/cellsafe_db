--
-- PostgreSQL database dump
--

\restrict Aj4qCTBf6VprgMbxptfTApoQmKVu4sMllyqmnQc3z1ucUKI3FXNMgnU0PtcriAZ

-- Dumped from database version 16.11 (Ubuntu 16.11-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.11 (Ubuntu 16.11-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: cells; Type: SCHEMA; Schema: -; Owner: cell
--

CREATE SCHEMA cells;


ALTER SCHEMA cells OWNER TO cell;

--
-- Name: add_cell_provenance(integer, integer); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.add_cell_provenance(IN p_accession_id integer, IN p_provenance_id integer)
    LANGUAGE plpgsql
    AS $$
declare
    v_existed integer;
    v_seq integer;
BEGIN
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN

    SELECT COUNT(*) INTO v_existed FROM cells.cell_accession_provenance WHERE accession_id = p_accession_id AND provenance_id = p_provenance_id;
	if (v_existed = 0) THEN
        select max(seq) + 1 into v_seq from cells.cell_accession_provenance where accession_id = p_accession_id;
        IF v_seq IS NULL THEN
            v_seq := 1;
        END IF;
        INSERT INTO cells.cell_accession_provenance(
            accession_id,
            provenance_id,
            seq,
            relevent
        ) VALUES (
            p_accession_id,
            p_provenance_id,
            v_seq,
            true
        );
    END IF;
    COMMIT;
END;
$$;


ALTER PROCEDURE cells.add_cell_provenance(IN p_accession_id integer, IN p_provenance_id integer) OWNER TO cell;

--
-- Name: approve_order(integer, integer, integer); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.approve_order(IN p_id integer, IN p_user integer, IN p_flag integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_what  text;
BEGIN
   -- record the decision in the history table
   if (p_flag < 1 ) then
        v_what = 'Approve order';
   elsif (p_flag = 1) then
        v_what = 'Approve order with override one flag';
    else
        v_what = 'Approve order with override '||  p_flag || ' flag';
   end if;
   insert into cells.history 
        ("type", entity_id, who, "when", what) values
        ('ORDER', p_id,p_user, CURRENT_DATE, v_what);
    update cells.cell_order set status = 'APPROVED' where id=p_id;

    commit;
END;
$$;


ALTER PROCEDURE cells.approve_order(IN p_id integer, IN p_user integer, IN p_flag integer) OWNER TO cell;

--
-- Name: assign_group_to_container(integer, integer); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.assign_group_to_container(INOUT p_container_id integer, IN p_group_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_name  text;
    v_type  text;
BEGIN
    select group_name into v_name from cells.user_group where id = p_group_id;
    select type into v_type from cells.inv_container where id = p_container_id;

    if v_type = 'TANK' then
        update cells.inv_container
            set n1 = p_group_id
            ,   t1 = v_name
            where id in (select id from cells.inv_container 
                            where parent_id in 
                            (select id from cells.inv_container where parent_id = p_container_id))
                and n1 is null;
    elsif v_type = 'RACK' then
        update cells.inv_container
            set n1 = p_group_id
            ,   t1 = v_name
            where id in (select id from cells.inv_container where parent_id = p_container_id)
                and n1 is null;
        
    elsif  v_type = 'BOX' then
        -- update group no matter if the group is assigned
        update cells.inv_container 
            set   n1 = p_group_id
                , t1 = v_name
            where id = p_container_id;
        
    end if;
	commit;
END;
$$;


ALTER PROCEDURE cells.assign_group_to_container(INOUT p_container_id integer, IN p_group_id integer) OWNER TO cell;

--
-- Name: attach_file(text, integer, text, text); Type: FUNCTION; Schema: cells; Owner: cell
--

CREATE FUNCTION cells.attach_file(p_entity_type text, p_entity_id integer, p_file_name text, p_file_mime text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id  integer;
BEGIN
   -- record the decision in the history table
   insert into cells.document (entity_type, entity_id, file_name, file_mime) 
        values(p_entity_type, p_entity_id, p_file_name, p_file_name)
        returning id into v_id; 
    
    --commit;

    return v_id;
END;
$$;


ALTER FUNCTION cells.attach_file(p_entity_type text, p_entity_id integer, p_file_name text, p_file_mime text) OWNER TO cell;

--
-- Name: can_access_box(integer, integer); Type: FUNCTION; Schema: cells; Owner: cell
--

CREATE FUNCTION cells.can_access_box(p_box_id integer, p_user_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
    v_group_id  integer;
    v_count     integer;
BEGIN
    -- check if the box belongs to a group
    select n1 into v_group_id
        from cells.inv_container
        where id = p_box_id;

    -- check if there is a group assigned
    if v_group_id is not null then
        -- check if the user belongs to the group
        select count(*) into v_count
            from cells.user_group_member
            where group_id = v_group_id
              and user_id = p_user_id;

        if v_count = 0 then
            return 'N';
        else
            return 'Y';
        end if;
    else
        return 'Y'; -- no group assigned, everyone has access
    end if;
    
END;
$$;


ALTER FUNCTION cells.can_access_box(p_box_id integer, p_user_id integer) OWNER TO cell;

--
-- Name: can_fill_order(integer, integer); Type: FUNCTION; Schema: cells; Owner: cell
--

CREATE FUNCTION cells.can_fill_order(p_user integer, p_batch_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
    v_count integer;
    rec     integer;
BEGIN
    -- check if the box belongs to a group
    -- find the inventory data
    For rec in SELECT distinct box_owner  FROM cells.cell_v_inventory where mat_id = p_batch_id loop
        select count(user_id) into v_count
            from cells.user_group_member
                where group_id = rec
                    and user_id = p_user;
        if (v_count > 0) then
            return 'Y';
        end if;
        
    end loop;
    
    return 'N';
END;
$$;


ALTER FUNCTION cells.can_fill_order(p_user integer, p_batch_id integer) OWNER TO cell;

--
-- Name: cancel_order(integer, integer); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.cancel_order(IN p_id integer, IN p_user integer)
    LANGUAGE plpgsql
    AS $$

BEGIN
   -- record the decision in the history table
   insert into cells.history 
        ("type", entity_id, who, "when", what) values
        ('ORDER', p_id, p_user, CURRENT_DATE, 'Cancel Order');
    update cells.cell_order set status = 'CANCELLED' where id = p_id;
    commit;
END;
$$;


ALTER PROCEDURE cells.cancel_order(IN p_id integer, IN p_user integer) OWNER TO cell;

--
-- Name: checkout_inv(integer); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.checkout_inv(IN p_vial_id integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE cells.checkout_inv(IN p_vial_id integer) OWNER TO cell;

--
-- Name: create_cell_vial(integer, integer, text, integer, integer, integer); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.create_cell_vial(INOUT p_vial_id integer, IN p_cont_id integer, IN p_barcode text, IN p_x integer, IN p_y integer, IN p_batch_id integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE cells.create_cell_vial(INOUT p_vial_id integer, IN p_cont_id integer, IN p_barcode text, IN p_x integer, IN p_y integer, IN p_batch_id integer) OWNER TO cell;

--
-- Name: create_tank(integer, text, integer, integer, integer, integer); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.create_tank(INOUT p_tank_id integer, IN p_name text, IN p_freezer integer, IN p_rack integer, IN p_box_x integer, IN p_box_y integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE cells.create_tank(INOUT p_tank_id integer, IN p_name text, IN p_freezer integer, IN p_rack integer, IN p_box_x integer, IN p_box_y integer) OWNER TO cell;

--
-- Name: deny_order(integer, integer, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.deny_order(IN p_id integer, IN p_user integer, IN p_msg text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_what  text;
BEGIN
   -- record the decision in the history table
   insert into cells.history 
        ("type", entity_id, who, "when", what) values
        ('ORDER', p_id, p_user, CURRENT_DATE, 'Deny Order, Reason: ' || COALESCE(p_msg, ''));
    update cells.cell_order set status = 'DENIED' where id = p_id;
    commit;
END;
$$;


ALTER PROCEDURE cells.deny_order(IN p_id integer, IN p_user integer, IN p_msg text) OWNER TO cell;

--
-- Name: fill_order(integer, integer, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.fill_order(IN p_id integer, IN p_user integer, IN p_msg text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_what  text;
BEGIN
   -- record the decision in the history table
   insert into cells.history 
        ("type", entity_id, who, "when", what) values
        ('ORDER', p_id, p_user, CURRENT_DATE, 'Fill Order ' || COALESCE(p_msg, ''));
    update cells.cell_order set status = 'FILLED' where id = p_id;
    commit;
END;
$$;


ALTER PROCEDURE cells.fill_order(IN p_id integer, IN p_user integer, IN p_msg text) OWNER TO cell;

--
-- Name: get_batch_inventory(integer, integer); Type: FUNCTION; Schema: cells; Owner: cell
--

CREATE FUNCTION cells.get_batch_inventory(p_batch_id integer, p_user_id integer) RETURNS TABLE(vial_id integer, cont_id integer, barcode text, vial_status text, x integer, y integer, "position" text, mat_id integer, mat_type integer, vial_type integer, t1 text, t2 text, t3 text, d1 double precision, d2 double precision, d3 double precision, box_id integer, box_name text, box_desc text, box_barcode text, box_owner integer, box_owner_name text, rack_id bigint, rack_name text, rack_desc text, rack_barcode text, tank_id bigint, tank_name text, tank_desc text, tank_barcode text, material_type_name text, material_type_desc text, vial_type_name text, vial_type_desc text, cell_batch_name text, is_visible text)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION cells.get_batch_inventory(p_batch_id integer, p_user_id integer) OWNER TO cell;

--
-- Name: mod_address(integer, text, text, text, text, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_address(INOUT p_id integer, IN p_name text, IN p_company text, IN p_address text, IN p_email text, IN p_phone text)
    LANGUAGE plpgsql
    AS $$

BEGIN
/*  
     id        | integer                |           | not null | nextval('cells.lst_address_id_seq'::regclass)
 name      | character varying(64)  |           | not null |
 company   | character varying(64)  |           |          |
 address   | character varying(512) |           |          |
 email     | character varying(128) |           |          |
 phone     | character varying(32)  |           |          |
*/
    IF (p_id < 0) THEN
		insert into cells.lst_address ( name, company, address, email, phone, is_active)
			values ( p_name, p_company, p_address, p_email, p_phone, true)
			returning id into p_id;
	ELSE
		update cells.lst_address
        set name	    = p_name
            ,   company	    = p_company
            ,   address	    = p_address
            ,   email	    = p_email
            ,   phone	    = p_phone
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$$;


ALTER PROCEDURE cells.mod_address(INOUT p_id integer, IN p_name text, IN p_company text, IN p_address text, IN p_email text, IN p_phone text) OWNER TO cell;

--
-- Name: mod_cell_accession(integer, integer, text, text, text, text, integer, text, integer, integer, integer, integer, text, text, text, text, integer, text, text, text, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_cell_accession(INOUT p_id integer, IN p_cell_id integer, IN p_name text, IN p_eln text, IN p_date_received text, IN p_date_discarded text, IN p_cell_source integer, IN p_catalog_num text, IN p_engineering_source integer, IN p_reporter integer, IN p_tag integer, IN p_engineering_method integer, IN p_pool_name text, IN p_clone_name text, IN p_passage_num text, IN p_status text, IN p_contact_person integer, IN p_comments text, IN p_t1 text, IN p_t2 text, IN p_t3 text)
    LANGUAGE plpgsql
    AS $$
declare
v_date_received date;
v_date_discarded date;
BEGIN
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN
    if (p_date_discarded is null or length(p_date_discarded) = 0) then
        v_date_discarded := null;
    else
        v_date_discarded := to_date(p_date_discarded, 'YYYY-MM-DD');
    end if;

    if (p_date_received is null or length(p_date_received) = 0) then
        v_date_received := null;
    else
        v_date_received := to_date(p_date_received, 'YYYY-MM-DD');
    end if;
    IF (p_id < 0) THEN
		insert into cells.cell_accession (cell_id, name, eln, date_received, date_discarded, cell_source, catalog_num, 
            engineering_source, reporter, tag, engineering_method, pool_name, clone_name, passage_num, status, 
            contact_person, comments, t1, t2, t3)             
			values (p_cell_id, p_name, p_eln, v_date_received, v_date_discarded, p_cell_source, p_catalog_num, 
                    p_engineering_source, p_reporter, p_tag, p_engineering_method, p_pool_name, p_clone_name, p_passage_num, p_status
                    , p_contact_person, p_comments, p_t1, p_t2, p_t3)
			returning id into p_id;
	ELSE
		update cells.cell_accession
			set   cell_id	            = p_cell_id
                , name	                = p_name
                , eln	                = p_eln
                , date_received         = v_date_received
                , date_discarded        = v_date_discarded
                , cell_source           = p_cell_source
                , catalog_num           = p_catalog_num
                , engineering_source    = p_engineering_source
                , reporter              = p_reporter
                , tag                   = p_tag
                , engineering_method    = p_engineering_method
                , pool_name             = p_pool_name
                , clone_name            = p_clone_name
                , passage_num           = p_passage_num
                , status                = p_status
                , contact_person        = p_contact_person
                , comments              = p_comments
                , t1                    = p_t1
                , t2                    = p_t2
                , t3                    = p_t3
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$$;


ALTER PROCEDURE cells.mod_cell_accession(INOUT p_id integer, IN p_cell_id integer, IN p_name text, IN p_eln text, IN p_date_received text, IN p_date_discarded text, IN p_cell_source integer, IN p_catalog_num text, IN p_engineering_source integer, IN p_reporter integer, IN p_tag integer, IN p_engineering_method integer, IN p_pool_name text, IN p_clone_name text, IN p_passage_num text, IN p_status text, IN p_contact_person integer, IN p_comments text, IN p_t1 text, IN p_t2 text, IN p_t3 text) OWNER TO cell;

--
-- Name: mod_cell_assay(integer, text, text, text, text, text, text, numeric, text, integer, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_cell_assay(INOUT p_id integer, IN p_assay text, IN p_pass text, IN p_eln text, IN p_exp_date text, IN p_control text, IN p_op text, IN p_result numeric, IN p_comment text, IN p_batch_id integer, IN p_result_unit text)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE cells.mod_cell_assay(INOUT p_id integer, IN p_assay text, IN p_pass text, IN p_eln text, IN p_exp_date text, IN p_control text, IN p_op text, IN p_result numeric, IN p_comment text, IN p_batch_id integer, IN p_result_unit text) OWNER TO cell;

--
-- Name: mod_cell_batch(integer, integer, text, text, integer, text, double precision, double precision, integer, text, integer, text, text, text, text, text, text, text, text, text, text, text, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_cell_batch(INOUT p_id integer, IN p_accession_id integer, IN p_name text, IN p_alt_name text, IN p_parent_batch integer, IN p_material_state text, IN p_cells_per_vial double precision, IN p_cells_per_ml double precision, IN p_passage integer, IN p_eln text, IN p_contact_person integer, IN p_culture_type text, IN p_culture_protocol text, IN p_dissociation_solution text, IN p_medium_growth text, IN p_medium_growth_suppl text, IN p_medium_freezing text, IN p_comments text, IN p_t1 text, IN p_t2 text, IN p_t3 text, IN p_t4 text, IN p_created_at text)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE cells.mod_cell_batch(INOUT p_id integer, IN p_accession_id integer, IN p_name text, IN p_alt_name text, IN p_parent_batch integer, IN p_material_state text, IN p_cells_per_vial double precision, IN p_cells_per_ml double precision, IN p_passage integer, IN p_eln text, IN p_contact_person integer, IN p_culture_type text, IN p_culture_protocol text, IN p_dissociation_solution text, IN p_medium_growth text, IN p_medium_growth_suppl text, IN p_medium_freezing text, IN p_comments text, IN p_t1 text, IN p_t2 text, IN p_t3 text, IN p_t4 text, IN p_created_at text) OWNER TO cell;

--
-- Name: mod_cell_biosafety(integer, integer, integer, text, text, text, text, text, integer, text, text, text, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_cell_biosafety(INOUT p_id integer, IN p_accession_id integer, IN p_biosafety_level integer, IN p_gmo text, IN p_gentg_level text, IN p_expiration_date text, IN p_risk_group text, IN p_risk_accessment text, IN p_contact_person integer, IN p_comment text, IN p_t1 text, IN p_t2 text, IN p_t3 text)
    LANGUAGE plpgsql
    AS $$
declare
v_expiration_date date;
v_gmo boolean;
BEGIN
    if p_gmo = 'Y' THEN
        v_gmo := true;
    ELSE
        v_gmo := false;
    end if;
    if p_expiration_date is null or length(p_expiration_date) = 0 THEN
        v_expiration_date := null;
    else
        v_expiration_date := to_date(p_expiration_date, 'YYYY-MM-DD');
    end if;
    -- Your procedure logic here
    -- RAISE NOTICE 'Procedure executed successfully';IF (p_id < 0) THEN
    IF (p_id < 0) THEN
		insert into cells.cell_biosafety (accession_id, biosafety_level, gmo, gentg_level
            ,expiration_date, risk_group, risk_accessment, contact_person, comment
            , t1, t2, t3)
			values ( p_accession_id, p_biosafety_level, v_gmo, p_gentg_level
            , v_expiration_date, p_risk_group, p_risk_accessment, p_contact_person,p_comment
            , p_t1, p_t2, p_t3)
			returning id into p_id;
	ELSE
		update cells.cell_biosafety
			set accession_id        = p_accession_id
            ,   biosafety_level	    = p_biosafety_level
            ,   gmo	                = v_gmo
            ,   gentg_level	        = p_gentg_level
            ,   expiration_date	    = v_expiration_date
            ,   risk_group	        = p_risk_group
            ,   risk_accessment	    = p_risk_accessment
            ,   contact_person	    = p_contact_person
            ,   comment	            = p_comment
            ,   t1	                = p_t1
            ,   t2	                = p_t2
            ,   t3	                = p_t3
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$$;


ALTER PROCEDURE cells.mod_cell_biosafety(INOUT p_id integer, IN p_accession_id integer, IN p_biosafety_level integer, IN p_gmo text, IN p_gentg_level text, IN p_expiration_date text, IN p_risk_group text, IN p_risk_accessment text, IN p_contact_person integer, IN p_comment text, IN p_t1 text, IN p_t2 text, IN p_t3 text) OWNER TO cell;

--
-- Name: mod_cell_cell(integer, text, text, text, text, smallint, text, text, text, text, text, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_cell_cell(INOUT p_id integer, IN p_name text, IN p_disease text, IN p_source_tissue text, IN p_source_type text, IN p_species smallint, IN p_cellosaurus_id text, IN p_reference text, IN p_comments text, IN p_t1 text, IN p_t2 text, IN p_t3 text)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE cells.mod_cell_cell(INOUT p_id integer, IN p_name text, IN p_disease text, IN p_source_tissue text, IN p_source_type text, IN p_species smallint, IN p_cellosaurus_id text, IN p_reference text, IN p_comments text, IN p_t1 text, IN p_t2 text, IN p_t3 text) OWNER TO cell;

--
-- Name: mod_cell_order(integer, integer, integer, text, text, text, text, integer, text, text, text, text, text, text, integer); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_cell_order(INOUT p_id integer, IN p_requestor integer, IN p_cell_batch_id integer, IN p_order_date text, IN p_status text, IN p_purpose text, IN p_comment text, IN p_shipping_id integer, IN p_order_needed text, IN p_rule1 text, IN p_rule2 text, IN p_rule3 text, IN p_rule4 text, IN p_rule5 text, IN p_vial_needed integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE cells.mod_cell_order(INOUT p_id integer, IN p_requestor integer, IN p_cell_batch_id integer, IN p_order_date text, IN p_status text, IN p_purpose text, IN p_comment text, IN p_shipping_id integer, IN p_order_needed text, IN p_rule1 text, IN p_rule2 text, IN p_rule3 text, IN p_rule4 text, IN p_rule5 text, IN p_vial_needed integer) OWNER TO cell;

--
-- Name: mod_cell_provenance(integer, integer, text, text, text, text, text, text, text, text, text, text, text, text, text, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_cell_provenance(INOUT p_id integer, IN p_source integer, IN p_source_role text, IN p_contract_name text, IN p_contract_expiration text, IN p_contract_desc text, IN p_comment text, IN p_restriction text, IN p_rule1 text, IN p_rule2 text, IN p_rule3 text, IN p_rule4 text, IN p_rule5 text, IN p_t1 text, IN p_t2 text, IN p_t3 text)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE cells.mod_cell_provenance(INOUT p_id integer, IN p_source integer, IN p_source_role text, IN p_contract_name text, IN p_contract_expiration text, IN p_contract_desc text, IN p_comment text, IN p_restriction text, IN p_rule1 text, IN p_rule2 text, IN p_rule3 text, IN p_rule4 text, IN p_rule5 text, IN p_t1 text, IN p_t2 text, IN p_t3 text) OWNER TO cell;

--
-- Name: mod_session(text, text, integer); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_session(INOUT p_id text, IN p_email text, IN p_expired integer)
    LANGUAGE plpgsql
    AS $$
declare 
    v_existed integer;
    v_user_id integer;
BEGIN
    select count(id) into v_existed
        from cells.app_session
        where id = p_id
            and email = p_email;
    
    SELECT id into v_user_id
        FROM cells."user" 
        where lower(email) = lower(p_email);

    if (v_existed > 0) THEN
        update cells.app_session
            set user_id = v_user_id
            ,   expired = current_date + p_expired
            where id = p_id
                and email  = p_email;
    ELSE
        insert into cells.app_session(id, user_id, email, expired)
            values(p_id, v_user_id, p_email, current_date + p_expired);
    end if;
END;
$$;


ALTER PROCEDURE cells.mod_session(INOUT p_id text, IN p_email text, IN p_expired integer) OWNER TO cell;

--
-- Name: mod_user(integer, text, text, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_user(INOUT p_id integer, IN p_full_name text, IN p_email text, IN p_alt_id text)
    LANGUAGE plpgsql
    AS $$
BEGIN

    IF (p_id < 0) THEN
		insert into cells.user ( full_name, email, alt_id, is_active)
			values ( p_full_name, p_email, p_alt_id,  true)
			returning id into p_id;
	ELSE
		update cells.user
        set     full_name	= p_full_name
            ,   email	    = p_email
            ,   alt_id	    = p_alt_id
			where id = p_id;
	
	END IF;
	COMMIT;
END;
$$;


ALTER PROCEDURE cells.mod_user(INOUT p_id integer, IN p_full_name text, IN p_email text, IN p_alt_id text) OWNER TO cell;

--
-- Name: mod_user_pref(integer, text, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.mod_user_pref(IN p_user integer, IN p_page text, IN p_pref text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_existed integer;
BEGIN
    select count("user")  into v_existed from cells.app_user_pref 
        where "user" = p_user
            and "page" = p_page;
    if (v_existed > 0) THEN
        -- update
        update cells.app_user_pref
            set pref = p_pref
            where "user" = p_user
                and "page" = p_page;
	ELSE
        -- insert
		insert into cells.app_user_pref ("user", "page", pref)
            values(p_user, p_page, p_pref);	
	END IF;
	COMMIT;
END;
$$;


ALTER PROCEDURE cells.mod_user_pref(IN p_user integer, IN p_page text, IN p_pref text) OWNER TO cell;

--
-- Name: remove_no_word(text); Type: FUNCTION; Schema: cells; Owner: cell
--

CREATE FUNCTION cells.remove_no_word(instr text) RETURNS text
    LANGUAGE plpgsql
    AS $$

begin
   if instr is null then
      return '';
    else
        return upper(replace(regexp_replace(instr, '\W', '', 'g'), '_', ''));
   end if;
end;
$$;


ALTER FUNCTION cells.remove_no_word(instr text) OWNER TO cell;

--
-- Name: save_location(integer, integer, text); Type: PROCEDURE; Schema: cells; Owner: cell
--

CREATE PROCEDURE cells.save_location(IN p_box_id integer, IN p_user integer, IN p_page text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rack_id   integer;
    v_tank_id   integer;
    v_existed   integer;
    v_pref      text;
BEGIN
    select parent_id into v_rack_id from cells.inv_container where id = p_box_id;
    select parent_id into v_tank_id from cells.inv_container where id = v_rack_id;
    select count(pref) into v_existed from cells.app_user_pref
        where "user" = p_user
            and "page" = p_page;
    
    v_pref = '{"location":[' || v_tank_id || ',' || v_rack_id || ','
            || p_box_id || ']}';

    if (v_existed > 0) then
        -- update
        update cells.app_user_pref
            set pref = v_pref
            where "user" = p_user
                and "page" = p_page;
    else
        insert into cells.app_user_pref ("user", "page", pref)
            values(p_user, p_page, v_pref);
    end if;
	COMMIT;
END;
$$;


ALTER PROCEDURE cells.save_location(IN p_box_id integer, IN p_user integer, IN p_page text) OWNER TO cell;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: tbl; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.tbl (
    v character varying(8)
);


ALTER TABLE cells.tbl OWNER TO cell;

--
-- Name: app_session; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.app_session (
    id character varying(128) NOT NULL,
    user_id integer NOT NULL,
    email character varying(256) NOT NULL,
    expired date NOT NULL
);


ALTER TABLE cells.app_session OWNER TO cell;

--
-- Name: app_user_pref; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.app_user_pref (
    "user" integer NOT NULL,
    page character varying(16) NOT NULL,
    pref character varying(1024) NOT NULL
);


ALTER TABLE cells.app_user_pref OWNER TO cell;

--
-- Name: cell_accession; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_accession (
    id integer NOT NULL,
    cell_id integer NOT NULL,
    name character varying(128) NOT NULL,
    eln character varying(32),
    date_received date,
    date_discarded date,
    cell_source integer,
    catalog_num character varying(64),
    engineering_source integer,
    reporter integer,
    tag integer,
    engineering_method integer,
    pool_name character varying(128),
    clone_name character varying(128),
    passage_num character varying(16),
    status character varying(16),
    contact_person integer,
    comments character varying(256),
    t1 character varying(64),
    t2 character varying(64),
    t3 character varying(64)
);


ALTER TABLE cells.cell_accession OWNER TO cell;

--
-- Name: cell_accession_gene; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_accession_gene (
    accession_id integer NOT NULL,
    ncbi_gene_id integer NOT NULL,
    modification character varying(256),
    id integer NOT NULL
);


ALTER TABLE cells.cell_accession_gene OWNER TO cell;

--
-- Name: cell_accession_gene_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_accession_gene_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_accession_gene_id_seq OWNER TO cell;

--
-- Name: cell_accession_gene_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_accession_gene_id_seq OWNED BY cells.cell_accession_gene.id;


--
-- Name: cell_accession_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_accession_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_accession_id_seq OWNER TO cell;

--
-- Name: cell_accession_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_accession_id_seq OWNED BY cells.cell_accession.id;


--
-- Name: cell_accession_provenance; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_accession_provenance (
    accession_id integer NOT NULL,
    provenance_id integer NOT NULL,
    seq smallint,
    relevent boolean
);


ALTER TABLE cells.cell_accession_provenance OWNER TO cell;

--
-- Name: cell_assay; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_assay (
    id bigint NOT NULL,
    assay character varying(32) NOT NULL,
    pass boolean NOT NULL,
    eln character varying(32),
    exp_date date,
    control character varying(32),
    op character varying(8),
    result double precision,
    comment character varying(64),
    batch_id bigint NOT NULL,
    result_unit character varying(16)
);


ALTER TABLE cells.cell_assay OWNER TO cell;

--
-- Name: cell_assay_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_assay_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_assay_id_seq OWNER TO cell;

--
-- Name: cell_assay_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_assay_id_seq OWNED BY cells.cell_assay.id;


--
-- Name: cell_batch; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_batch (
    id integer NOT NULL,
    accession_id integer NOT NULL,
    name character varying(128) NOT NULL,
    alt_name character varying(128),
    parent_batch integer,
    material_state character varying(16),
    cells_per_vial double precision,
    cells_per_ml double precision,
    passage integer,
    eln character varying(64),
    contact_person integer,
    culture_type character varying(16),
    culture_protocol character varying(1024),
    dissociation_solution character varying(1024),
    medium_growth character varying(1024),
    medium_growth_suppl character varying(1024),
    medium_freezing character varying(1024),
    comments character varying(2048),
    t1 character varying(256),
    t2 character varying(256),
    t3 character varying(256),
    t4 character varying(256),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE cells.cell_batch OWNER TO cell;

--
-- Name: cell_batch_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_batch_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_batch_id_seq OWNER TO cell;

--
-- Name: cell_batch_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_batch_id_seq OWNED BY cells.cell_batch.id;


--
-- Name: cell_biosafety; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_biosafety (
    id integer NOT NULL,
    accession_id integer NOT NULL,
    biosafety_level integer,
    gmo boolean DEFAULT false,
    gentg_level character varying(8),
    expiration_date date,
    risk_group character varying(128),
    risk_accessment character varying(512),
    contact_person integer,
    comment character varying(512),
    t1 character varying(256),
    t2 character varying(256),
    t3 character varying(256)
);


ALTER TABLE cells.cell_biosafety OWNER TO cell;

--
-- Name: cell_biosafety_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_biosafety_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_biosafety_id_seq OWNER TO cell;

--
-- Name: cell_biosafety_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_biosafety_id_seq OWNED BY cells.cell_biosafety.id;


--
-- Name: cell_cell; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_cell (
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    disease character varying(256),
    source_tissue character varying(256),
    source_type character varying(16),
    species smallint,
    cellosaurus_id character varying(16),
    reference character varying(512),
    comments character varying(512),
    t1 character varying(128),
    t2 character varying(128),
    t3 character varying(128)
);


ALTER TABLE cells.cell_cell OWNER TO cell;

--
-- Name: cell_cell_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_cell_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_cell_id_seq OWNER TO cell;

--
-- Name: cell_cell_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_cell_id_seq OWNED BY cells.cell_cell.id;


--
-- Name: cell_dict; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_dict (
    name character varying(16) NOT NULL,
    key character varying(32) NOT NULL,
    value character varying(64)
);


ALTER TABLE cells.cell_dict OWNER TO cell;

--
-- Name: cell_engineering_method; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_engineering_method (
    id smallint NOT NULL,
    name character varying(128) NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE cells.cell_engineering_method OWNER TO cell;

--
-- Name: cell_engineering_method_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_engineering_method_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_engineering_method_id_seq OWNER TO cell;

--
-- Name: cell_engineering_method_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_engineering_method_id_seq OWNED BY cells.cell_engineering_method.id;


--
-- Name: cell_reporter; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_reporter (
    id smallint NOT NULL,
    name character varying(64) NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE cells.cell_reporter OWNER TO cell;

--
-- Name: cell_synonyms; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_synonyms (
    id integer NOT NULL,
    synonyms character varying(128) NOT NULL
);


ALTER TABLE cells.cell_synonyms OWNER TO cell;

--
-- Name: cell_tag; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_tag (
    id smallint NOT NULL,
    name character varying(64) NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE cells.cell_tag OWNER TO cell;

--
-- Name: lst_gene; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.lst_gene (
    ncbi_gene_id integer NOT NULL,
    gene_symbol character varying(32),
    gene_species smallint
);


ALTER TABLE cells.lst_gene OWNER TO cell;

--
-- Name: cell_v_accession_gene; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_accession_gene AS
 SELECT ag.accession_id,
    string_agg((g.ncbi_gene_id || ''::text), ','::text ORDER BY g.ncbi_gene_id) AS ncbi_gene_id,
    string_agg(((g.gene_symbol)::text ||
        CASE
            WHEN (ag.modification IS NULL) THEN ''::text
            ELSE (('('::text || (ag.modification)::text) || ')'::text)
        END), ','::text ORDER BY g.gene_symbol) AS gene_symbol
   FROM (cells.cell_accession_gene ag
     LEFT JOIN cells.lst_gene g ON ((ag.ncbi_gene_id = g.ncbi_gene_id)))
  GROUP BY ag.accession_id;


ALTER VIEW cells.cell_v_accession_gene OWNER TO cell;

--
-- Name: cell_v_synonyms; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_synonyms AS
 SELECT id,
    string_agg((synonyms)::text, '|'::text ORDER BY (synonyms)::text) AS synonyms
   FROM cells.cell_synonyms
  GROUP BY id;


ALTER VIEW cells.cell_v_synonyms OWNER TO cell;

--
-- Name: lst_source; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.lst_source (
    id integer NOT NULL,
    name character varying(64),
    url character varying(128),
    address character varying(512),
    telephone character varying(64),
    email character varying(128),
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE cells.lst_source OWNER TO cell;

--
-- Name: lst_species; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.lst_species (
    id smallint NOT NULL,
    common_name character varying(16) NOT NULL,
    scientific_name character varying(32) NOT NULL,
    variant character varying(64),
    "desc" character varying(64)
);


ALTER TABLE cells.lst_species OWNER TO cell;

--
-- Name: user; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells."user" (
    id integer NOT NULL,
    email character varying(256) NOT NULL,
    full_name character varying(256) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    alt_id character varying(32)
);


ALTER TABLE cells."user" OWNER TO cell;

--
-- Name: cell_mv_accession; Type: MATERIALIZED VIEW; Schema: cells; Owner: cell
--

CREATE MATERIALIZED VIEW cells.cell_mv_accession AS
 SELECT a.id AS accession_id,
    a.cell_id AS accession_cell_id,
    a.name AS accession_name,
    a.eln AS accession_eln,
    a.date_received AS accession_date_received,
    a.date_discarded AS accession_date_discarded,
    a.cell_source AS accession_cell_source,
    a.catalog_num AS accession_catalog_num,
    a.engineering_source AS accession_engineering_source,
    a.reporter AS accession_reporter,
    a.tag AS accession_tag,
    a.engineering_method AS accession_engineering_method,
    a.pool_name AS accession_pool_name,
    a.clone_name AS accession_clone_name,
    a.passage_num AS accession_passage_num,
    a.status AS accession_status,
    a.contact_person AS accession_contact_person,
    a.comments AS accession_comments,
    a.t1 AS accession_t1,
    a.t2 AS accession_t2,
    a.t3 AS accession_t3,
    tag.name AS accession_tag_name,
    r.name AS accession_reporter_name,
    cs.name AS accession_cell_source_name,
    es.name AS accession_engineering_source_name,
    u.full_name AS accession_contact_person_name,
    em.name AS accession_engineering_method_name,
    c.name AS cell_name,
    c.disease AS cell_disease,
    c.source_tissue AS cell_source_tissue,
    c.source_type AS cell_source_type,
    c.species AS cell_species,
    ((((s.common_name)::text || '('::text) || (s.scientific_name)::text) || ')'::text) AS cell_species_name,
    c.cellosaurus_id AS cell_cellosaurus_id,
    c.reference AS cell_reference,
    c.comments AS cell_comments,
    c.t1 AS cell_t1,
    c.t2 AS cell_t2,
    c.t3 AS cell_t3,
    cv.synonyms AS cell_synonyms,
    gene.ncbi_gene_id,
    gene.gene_symbol,
    ((((((((((((((((((((((((((((((((((((((((((((((((((((((a.id || '|'::text) || cells.remove_no_word(gene.gene_symbol)) || '|'::text) || cells.remove_no_word(cv.synonyms)) || '|'::text) || cells.remove_no_word((c.name)::text)) || '|'::text) || cells.remove_no_word((c.disease)::text)) || '|'::text) || cells.remove_no_word((c.source_tissue)::text)) || '|'::text) || cells.remove_no_word((c.cellosaurus_id)::text)) || '|'::text) || cells.remove_no_word((c.reference)::text)) || '|'::text) || cells.remove_no_word((c.comments)::text)) || '|'::text) || cells.remove_no_word((s.common_name)::text)) || '|'::text) || cells.remove_no_word((s.scientific_name)::text)) || '|'::text) || cells.remove_no_word((c.t1)::text)) || '|'::text) || cells.remove_no_word((c.t2)::text)) || '|'::text) || cells.remove_no_word((c.t3)::text)) || '|'::text) || cells.remove_no_word((a.name)::text)) || '|'::text) || cells.remove_no_word((a.eln)::text)) || '|'::text) || cells.remove_no_word((a.catalog_num)::text)) || '|'::text) || cells.remove_no_word((a.pool_name)::text)) || '|'::text) || cells.remove_no_word((a.clone_name)::text)) || '|'::text) || cells.remove_no_word((a.comments)::text)) || '|'::text) || cells.remove_no_word((a.t1)::text)) || '|'::text) || cells.remove_no_word((a.t2)::text)) || '|'::text) || cells.remove_no_word((a.t3)::text)) || '|'::text) || cells.remove_no_word((tag.name)::text)) || '|'::text) || cells.remove_no_word((r.name)::text)) || '|'::text) || cells.remove_no_word((cs.name)::text)) || '|'::text) || cells.remove_no_word((es.name)::text)) || '|'::text) || cells.remove_no_word((em.name)::text)) AS search_string,
    ( SELECT count(cb_1.id) AS count
           FROM cells.cell_batch cb_1
          WHERE (cb_1.accession_id = a.id)) AS batch_count,
    ( SELECT count(cell_accession_provenance.provenance_id) AS count
           FROM cells.cell_accession_provenance
          WHERE (cell_accession_provenance.accession_id = a.id)) AS provenance_count,
    cb.id AS biosafety_id,
    cb.biosafety_level,
    cb.gmo AS biosafety_gmo,
    cb.expiration_date AS biosafety_expiration_date
   FROM (((((((((((cells.cell_accession a
     LEFT JOIN cells.cell_tag tag ON ((a.tag = tag.id)))
     LEFT JOIN cells.cell_reporter r ON ((a.reporter = r.id)))
     LEFT JOIN cells.lst_source cs ON ((a.cell_source = cs.id)))
     LEFT JOIN cells.lst_source es ON ((a.engineering_source = es.id)))
     LEFT JOIN cells.cell_engineering_method em ON ((a.engineering_method = em.id)))
     LEFT JOIN cells."user" u ON ((a.contact_person = u.id)))
     LEFT JOIN cells.cell_cell c ON ((a.cell_id = c.id)))
     LEFT JOIN cells.lst_species s ON ((c.species = s.id)))
     LEFT JOIN cells.cell_v_synonyms cv ON ((c.id = cv.id)))
     LEFT JOIN cells.cell_biosafety cb ON ((a.id = cb.accession_id)))
     LEFT JOIN cells.cell_v_accession_gene gene ON ((a.id = gene.accession_id)))
  WITH NO DATA;


ALTER MATERIALIZED VIEW cells.cell_mv_accession OWNER TO cell;

--
-- Name: inv_container; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.inv_container (
    id bigint NOT NULL,
    parent_id bigint,
    type character varying(8) NOT NULL,
    status character varying(8) NOT NULL,
    name character varying(16) NOT NULL,
    "desc" character varying(128),
    barcode character varying(64),
    x integer NOT NULL,
    y integer DEFAULT 1 NOT NULL,
    "position" character varying(8),
    site character varying(16),
    x_size integer DEFAULT 1 NOT NULL,
    y_size integer DEFAULT 1 NOT NULL,
    t1 character varying(64),
    t2 character varying(64),
    t3 character varying(64),
    capacity integer,
    n1 numeric,
    n2 numeric,
    n3 numeric
);


ALTER TABLE cells.inv_container OWNER TO cell;

--
-- Name: inv_mat_type; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.inv_mat_type (
    id smallint NOT NULL,
    name character varying(16) NOT NULL,
    "desc" character varying(64)
);


ALTER TABLE cells.inv_mat_type OWNER TO cell;

--
-- Name: inv_vial; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.inv_vial (
    vial_id bigint NOT NULL,
    cont_id bigint NOT NULL,
    barcode character varying(32),
    x integer NOT NULL,
    y integer NOT NULL,
    "position" character varying(8),
    volume double precision,
    volume_unit integer,
    weight double precision,
    tare_weight double precision,
    weight_unit integer,
    conc double precision,
    conc_unit integer,
    mat_id integer NOT NULL,
    mat_type integer NOT NULL,
    vial_type integer,
    t1 character varying(64),
    t2 character varying(64),
    t3 character varying(64),
    d1 double precision,
    d2 double precision,
    d3 double precision,
    status character varying(16)
);


ALTER TABLE cells.inv_vial OWNER TO cell;

--
-- Name: inv_vial_type; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.inv_vial_type (
    id smallint NOT NULL,
    name character varying(16) NOT NULL,
    "desc" character varying(64)
);


ALTER TABLE cells.inv_vial_type OWNER TO cell;

--
-- Name: cell_v_inventory; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_inventory AS
 SELECT vial.vial_id,
    vial.cont_id,
    vial.barcode,
    vial.status AS vial_status,
    vial.x,
    vial.y,
    vial."position",
    vial.mat_id,
    vial.mat_type,
    vial.vial_type,
    vial.t1,
    vial.t2,
    vial.t3,
    vial.d1,
    vial.d2,
    vial.d3,
    box.id AS box_id,
    box.name AS box_name,
    box."desc" AS box_desc,
    box.barcode AS box_barcode,
    box.n1 AS box_owner,
    box.t1 AS box_owner_name,
    rack.id AS rack_id,
    rack.name AS rack_name,
    rack."desc" AS rack_desc,
    rack.barcode AS rack_barcode,
    tank.id AS tank_id,
    tank.name AS tank_name,
    tank."desc" AS tank_desc,
    tank.barcode AS tank_barcode,
    mt.name AS material_type_name,
    mt."desc" AS material_type_desc,
    vt.name AS vial_type_name,
    vt."desc" AS vial_type_desc,
    cb.name AS cell_batch_name
   FROM ((((((cells.inv_vial vial
     JOIN cells.inv_container box ON ((box.id = vial.cont_id)))
     JOIN cells.inv_container rack ON ((box.parent_id = rack.id)))
     JOIN cells.inv_container tank ON ((rack.parent_id = tank.id)))
     LEFT JOIN cells.inv_mat_type mt ON ((vial.mat_type = mt.id)))
     LEFT JOIN cells.inv_vial_type vt ON ((vial.vial_type = vt.id)))
     LEFT JOIN cells.cell_batch cb ON ((vial.mat_id = cb.id)));


ALTER VIEW cells.cell_v_inventory OWNER TO cell;

--
-- Name: cell_mv_batch; Type: MATERIALIZED VIEW; Schema: cells; Owner: cell
--

CREATE MATERIALIZED VIEW cells.cell_mv_batch AS
 SELECT b.id AS batch_id,
    b.name AS batch_name,
    b.alt_name AS batch_alt_name,
    b.parent_batch AS batch_parent_batch,
    b.material_state AS batch_material_state,
    b.cells_per_vial AS batch_cells_per_vial,
    b.cells_per_ml AS batch_cells_per_ml,
    b.passage AS batch_passage,
    b.eln AS batch_eln,
    b.contact_person AS batch_contact_person,
    bu.full_name AS batch_contact_person_name,
    b.culture_type AS batch_culture_type,
    b.culture_protocol AS batch_culture_protocol,
    b.dissociation_solution AS batch_dissociation_solution,
    b.medium_growth AS batch_medium_growth,
    b.medium_growth_suppl AS batch_medium_growth_suppl,
    b.medium_freezing AS batch_medium_freezing,
    b.comments AS batch_comments,
    b.t1 AS batch_t1,
    b.t2 AS batch_t2,
    b.t3 AS batch_t3,
    b.t4 AS batch_t4,
    b.created_at AS batch_created_at,
    a.id AS accession_id,
    a.cell_id AS accession_cell_id,
    a.name AS accession_name,
    a.eln AS accession_eln,
    a.date_received AS accession_date_received,
    a.date_discarded AS accession_date_discarded,
    a.cell_source AS accession_cell_source,
    a.catalog_num AS accession_catalog_num,
    a.engineering_source AS accession_engineering_source,
    a.reporter AS accession_reporter,
    a.tag AS accession_tag,
    a.engineering_method AS accession_engineering_method,
    a.pool_name AS accession_pool_name,
    a.clone_name AS accession_clone_name,
    a.passage_num AS accession_passage_num,
    a.status AS accession_status,
    a.contact_person AS accession_contact_person,
    a.comments AS accession_comments,
    a.t1 AS accession_t1,
    a.t2 AS accession_t2,
    a.t3 AS accession_t3,
    tag.name AS accession_tag_name,
    r.name AS accession_reporter_name,
    cs.name AS accession_cell_source_name,
    es.name AS accession_engineering_source_name,
    u.full_name AS accession_contact_person_name,
    em.name AS accession_engineering_method_name,
    c.name AS cell_name,
    c.disease AS cell_disease,
    c.source_tissue AS cell_source_tissue,
    c.source_type AS cell_source_type,
    c.species AS cell_species,
    ((((s.common_name)::text || '('::text) || (s.scientific_name)::text) || ')'::text) AS cell_species_name,
    c.cellosaurus_id AS cell_cellosaurus_id,
    c.reference AS cell_reference,
    c.comments AS cell_comments,
    c.t1 AS cell_t1,
    c.t2 AS cell_t2,
    c.t3 AS cell_t3,
    cv.synonyms AS cell_synonyms,
    gene.ncbi_gene_id,
    gene.gene_symbol,
    inv.tank_id,
    inv.tank_name,
    ( SELECT count(cell_v_inventory.vial_id) AS count
           FROM cells.cell_v_inventory
          WHERE (cell_v_inventory.mat_id = b.id)) AS vial_count,
    ((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((a.id || '|'::text) || cells.remove_no_word((b.name)::text)) || '|'::text) || cells.remove_no_word((b.alt_name)::text)) || '|'::text) || cells.remove_no_word((b.material_state)::text)) || '|'::text) || cells.remove_no_word((b.eln)::text)) || '|'::text) || cells.remove_no_word((bu.full_name)::text)) || '|'::text) || cells.remove_no_word((b.culture_type)::text)) || '|'::text) || cells.remove_no_word((b.culture_protocol)::text)) || '|'::text) || cells.remove_no_word((b.dissociation_solution)::text)) || '|'::text) || cells.remove_no_word((b.medium_growth)::text)) || '|'::text) || cells.remove_no_word((b.medium_growth_suppl)::text)) || '|'::text) || cells.remove_no_word((b.medium_freezing)::text)) || '|'::text) || cells.remove_no_word((b.comments)::text)) || '|'::text) || cells.remove_no_word((b.t1)::text)) || '|'::text) || cells.remove_no_word((b.t2)::text)) || '|'::text) || cells.remove_no_word((b.t3)::text)) || '|'::text) || cells.remove_no_word((b.t4)::text)) || '|'::text) || cells.remove_no_word(gene.gene_symbol)) || '|'::text) || cells.remove_no_word(cv.synonyms)) || '|'::text) || cells.remove_no_word((c.name)::text)) || '|'::text) || cells.remove_no_word((c.disease)::text)) || '|'::text) || cells.remove_no_word((c.source_tissue)::text)) || '|'::text) || cells.remove_no_word((c.cellosaurus_id)::text)) || '|'::text) || cells.remove_no_word((c.reference)::text)) || '|'::text) || cells.remove_no_word((c.comments)::text)) || '|'::text) || cells.remove_no_word((s.common_name)::text)) || '|'::text) || cells.remove_no_word((s.scientific_name)::text)) || '|'::text) || cells.remove_no_word((c.t1)::text)) || '|'::text) || cells.remove_no_word((c.t2)::text)) || '|'::text) || cells.remove_no_word((c.t3)::text)) || '|'::text) || cells.remove_no_word((a.name)::text)) || '|'::text) || cells.remove_no_word((a.eln)::text)) || '|'::text) || cells.remove_no_word((a.catalog_num)::text)) || '|'::text) || cells.remove_no_word((a.pool_name)::text)) || '|'::text) || cells.remove_no_word((a.clone_name)::text)) || '|'::text) || cells.remove_no_word((a.comments)::text)) || '|'::text) || cells.remove_no_word((a.t1)::text)) || '|'::text) || cells.remove_no_word((a.t2)::text)) || '|'::text) || cells.remove_no_word((a.t3)::text)) || '|'::text) || cells.remove_no_word((tag.name)::text)) || '|'::text) || cells.remove_no_word((r.name)::text)) || '|'::text) || cells.remove_no_word((cs.name)::text)) || '|'::text) || cells.remove_no_word((es.name)::text)) || '|'::text) || cells.remove_no_word((em.name)::text)) AS search_string,
    ( SELECT count(cb_1.id) AS count
           FROM cells.cell_batch cb_1
          WHERE (cb_1.accession_id = a.id)) AS batch_count,
    ( SELECT count(cell_accession_provenance.provenance_id) AS count
           FROM cells.cell_accession_provenance
          WHERE (cell_accession_provenance.accession_id = a.id)) AS provenance_count,
    cb.id AS biosafety_id,
    cb.biosafety_level,
    cb.gmo AS biosafety_gmo,
    cb.expiration_date AS biosafety_expiration_date
   FROM ((((((((((((((cells.cell_batch b
     LEFT JOIN cells.cell_accession a ON ((b.accession_id = a.id)))
     LEFT JOIN cells.cell_tag tag ON ((a.tag = tag.id)))
     LEFT JOIN cells.cell_reporter r ON ((a.reporter = r.id)))
     LEFT JOIN cells.lst_source cs ON ((a.cell_source = cs.id)))
     LEFT JOIN cells.lst_source es ON ((a.engineering_source = es.id)))
     LEFT JOIN cells.cell_engineering_method em ON ((a.engineering_method = em.id)))
     LEFT JOIN cells."user" u ON ((a.contact_person = u.id)))
     LEFT JOIN cells.cell_cell c ON ((a.cell_id = c.id)))
     LEFT JOIN cells.lst_species s ON ((c.species = s.id)))
     LEFT JOIN cells.cell_v_synonyms cv ON ((c.id = cv.id)))
     LEFT JOIN cells.cell_biosafety cb ON ((a.id = cb.accession_id)))
     LEFT JOIN cells.cell_v_accession_gene gene ON ((a.id = gene.accession_id)))
     LEFT JOIN cells."user" bu ON ((bu.id = b.id)))
     LEFT JOIN cells.cell_v_inventory inv ON ((inv.mat_id = b.id)))
  WHERE (b.is_active = true)
  WITH NO DATA;


ALTER MATERIALIZED VIEW cells.cell_mv_batch OWNER TO cell;

--
-- Name: cell_mv_cell; Type: MATERIALIZED VIEW; Schema: cells; Owner: cell
--

CREATE MATERIALIZED VIEW cells.cell_mv_cell AS
 SELECT c.id,
    c.name,
    c.disease,
    c.source_tissue,
    c.source_type,
    c.species,
    ((((s.common_name)::text || '('::text) || (s.scientific_name)::text) || ')'::text) AS species_name,
    c.cellosaurus_id,
    c.reference,
    c.comments,
    c.t1,
    c.t2,
    c.t3,
    cs.synonyms,
    (((((((((((((((((((((((c.id || '|'::text) || cells.remove_no_word(cs.synonyms)) || cells.remove_no_word((c.name)::text)) || '|'::text) || cells.remove_no_word((c.disease)::text)) || '|'::text) || cells.remove_no_word((c.source_tissue)::text)) || '|'::text) || cells.remove_no_word((c.cellosaurus_id)::text)) || '|'::text) || cells.remove_no_word((c.reference)::text)) || '|'::text) || cells.remove_no_word((c.comments)::text)) || '|'::text) || cells.remove_no_word((s.common_name)::text)) || '|'::text) || cells.remove_no_word((s.scientific_name)::text)) || '|'::text) || cells.remove_no_word((c.t1)::text)) || '|'::text) || cells.remove_no_word((c.t2)::text)) || '|'::text) || cells.remove_no_word((c.t3)::text)) AS search_string,
    ( SELECT count(ca.id) AS count
           FROM cells.cell_accession ca
          WHERE (ca.cell_id = c.id)) AS accession_count,
    ( SELECT count(cb.id) AS count
           FROM (cells.cell_batch cb
             LEFT JOIN cells.cell_accession ca ON ((ca.id = cb.accession_id)))
          WHERE (ca.cell_id = c.id)) AS batch_count
   FROM ((cells.cell_cell c
     LEFT JOIN cells.lst_species s ON ((c.species = s.id)))
     LEFT JOIN cells.cell_v_synonyms cs ON ((c.id = cs.id)))
  WITH NO DATA;


ALTER MATERIALIZED VIEW cells.cell_mv_cell OWNER TO cell;

--
-- Name: lst_gene_synonyms; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.lst_gene_synonyms (
    ncbi_gene_id integer NOT NULL,
    synonyms character varying(32) NOT NULL
);


ALTER TABLE cells.lst_gene_synonyms OWNER TO cell;

--
-- Name: cell_mv_gene; Type: MATERIALIZED VIEW; Schema: cells; Owner: cell
--

CREATE MATERIALIZED VIEW cells.cell_mv_gene AS
 SELECT g.ncbi_gene_id,
    g.gene_symbol,
    g.gene_species,
    string_agg((COALESCE(s.synonyms, ''::character varying))::text, ','::text ORDER BY s.synonyms) AS synonyms
   FROM (cells.lst_gene g
     LEFT JOIN cells.lst_gene_synonyms s ON ((g.ncbi_gene_id = s.ncbi_gene_id)))
  GROUP BY g.ncbi_gene_id, g.gene_symbol, g.gene_species
  WITH NO DATA;


ALTER MATERIALIZED VIEW cells.cell_mv_gene OWNER TO cell;

--
-- Name: cell_order; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_order (
    id bigint NOT NULL,
    requestor integer NOT NULL,
    cell_batch_id integer NOT NULL,
    order_date date,
    status character varying(8),
    purpose character varying(64),
    comment character varying(512),
    shipping_id integer,
    order_needed date,
    rule1 boolean,
    rule2 boolean,
    rule3 boolean,
    rule4 boolean,
    rule5 boolean,
    vial_needed smallint
);


ALTER TABLE cells.cell_order OWNER TO cell;

--
-- Name: cell_order_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_order_id_seq OWNER TO cell;

--
-- Name: cell_order_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_order_id_seq OWNED BY cells.cell_order.id;


--
-- Name: cell_provenance; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.cell_provenance (
    id smallint NOT NULL,
    source integer NOT NULL,
    contract_name character varying(256) NOT NULL,
    contract_expiration date NOT NULL,
    contract_desc character varying(512),
    comment character varying(256),
    restriction character varying(256),
    rule1 boolean,
    rule2 boolean,
    rule3 boolean,
    rule4 boolean,
    rule5 boolean,
    t1 character varying(256),
    t2 character varying(256),
    t3 character varying(256),
    source_role character varying(16)
);


ALTER TABLE cells.cell_provenance OWNER TO cell;

--
-- Name: cell_provenance_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_provenance_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_provenance_id_seq OWNER TO cell;

--
-- Name: cell_provenance_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_provenance_id_seq OWNED BY cells.cell_provenance.id;


--
-- Name: cell_reporter_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_reporter_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_reporter_id_seq OWNER TO cell;

--
-- Name: cell_reporter_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_reporter_id_seq OWNED BY cells.cell_reporter.id;


--
-- Name: cell_tag_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.cell_tag_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.cell_tag_id_seq OWNER TO cell;

--
-- Name: cell_tag_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.cell_tag_id_seq OWNED BY cells.cell_tag.id;


--
-- Name: cell_v_accession; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_accession AS
 SELECT a.id,
    a.cell_id,
    a.name,
    a.eln,
    a.date_received,
    a.date_discarded,
    a.cell_source,
    a.catalog_num,
    a.engineering_source,
    a.reporter,
    a.tag,
    a.engineering_method,
    a.pool_name,
    a.clone_name,
    a.passage_num,
    a.status,
    a.contact_person,
    a.comments,
    a.t1,
    a.t2,
    a.t3,
    tag.name AS tag_name,
    r.name AS reporter_name,
    cs.name AS cell_source_name,
    es.name AS engineering_source_name,
    u.full_name AS contact_person_name,
    em.name AS engineering_method_name
   FROM ((((((cells.cell_accession a
     LEFT JOIN cells.cell_tag tag ON ((a.tag = tag.id)))
     LEFT JOIN cells.cell_reporter r ON ((a.reporter = r.id)))
     LEFT JOIN cells.lst_source cs ON ((a.cell_source = cs.id)))
     LEFT JOIN cells.lst_source es ON ((a.engineering_source = es.id)))
     LEFT JOIN cells.cell_engineering_method em ON ((a.engineering_method = em.id)))
     LEFT JOIN cells."user" u ON ((a.contact_person = u.id)));


ALTER VIEW cells.cell_v_accession OWNER TO cell;

--
-- Name: cell_v_accession_gene_item; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_accession_gene_item AS
 SELECT a.id,
    a.accession_id,
    a.ncbi_gene_id,
    a.modification,
    g.gene_symbol
   FROM (cells.cell_accession_gene a
     LEFT JOIN cells.lst_gene g ON ((g.ncbi_gene_id = a.ncbi_gene_id)));


ALTER VIEW cells.cell_v_accession_gene_item OWNER TO cell;

--
-- Name: cell_v_accession_provenance; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_accession_provenance AS
 SELECT a.accession_id,
    a.seq,
    a.relevent,
    p.id,
    p.source,
    s.name AS source_name,
    p.contract_name,
    p.contract_expiration,
    p.contract_desc,
    p.comment,
    p.restriction AS restraction,
    p.rule1,
    p.rule2,
    p.rule3,
    p.rule4,
    p.rule5,
    p.t1,
    p.t2,
    p.t3
   FROM ((cells.cell_accession_provenance a
     LEFT JOIN cells.cell_provenance p ON ((a.provenance_id = p.id)))
     LEFT JOIN cells.lst_source s ON ((p.source = s.id)));


ALTER VIEW cells.cell_v_accession_provenance OWNER TO cell;

--
-- Name: cell_v_batch; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_batch AS
 SELECT b.id,
    b.accession_id,
    b.name,
    b.alt_name,
    b.parent_batch,
    b.material_state,
    b.cells_per_vial,
    b.cells_per_ml,
    b.passage,
    b.eln,
    b.contact_person,
    u.full_name AS contact_person_name,
    b.culture_type,
    b.culture_protocol,
    b.dissociation_solution,
    b.medium_growth,
    b.medium_growth_suppl,
    b.medium_freezing,
    b.comments,
    b.t1,
    b.t2,
    b.t3,
    b.t4,
    b.is_active,
    b.created_at
   FROM (cells.cell_batch b
     LEFT JOIN cells."user" u ON ((u.id = b.contact_person)));


ALTER VIEW cells.cell_v_batch OWNER TO cell;

--
-- Name: cell_v_batch_provenance; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_batch_provenance AS
 SELECT p.accession_id,
    p.id,
    p.seq,
    p.relevent,
    p.source,
    p.source_name,
    p.contract_name,
    p.contract_expiration,
    p.contract_desc,
    p.comment,
    p.restraction,
    p.rule1,
    p.rule2,
    p.rule3,
    p.rule4,
    p.rule5,
    p.t1,
    p.t2,
    p.t3,
    b.id AS batch_id
   FROM (cells.cell_v_accession_provenance p
     LEFT JOIN cells.cell_batch b ON ((b.accession_id = p.accession_id)));


ALTER VIEW cells.cell_v_batch_provenance OWNER TO cell;

--
-- Name: cell_v_biosafety; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_biosafety AS
 SELECT s.id,
    s.accession_id,
    a.name AS accession_name,
    s.biosafety_level,
    s.gmo,
    s.gentg_level,
    s.expiration_date,
    s.risk_group,
    s.risk_accessment,
    s.contact_person,
    u.full_name AS contact_person_name,
    s.comment,
    s.t1,
    s.t2,
    s.t3
   FROM ((cells.cell_biosafety s
     LEFT JOIN cells."user" u ON ((s.contact_person = u.id)))
     LEFT JOIN cells.cell_accession a ON ((s.accession_id = a.id)));


ALTER VIEW cells.cell_v_biosafety OWNER TO cell;

--
-- Name: cell_v_cell; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_cell AS
 SELECT c.id,
    c.name,
    c.disease,
    c.source_tissue,
    c.source_type,
    c.species,
    c.cellosaurus_id,
    c.reference,
    c.comments,
    c.t1,
    c.t2,
    c.t3,
    ((((s.common_name)::text || '('::text) || (s.scientific_name)::text) || ')'::text) AS species_name
   FROM (cells.cell_cell c
     LEFT JOIN cells.lst_species s ON ((c.species = s.id)));


ALTER VIEW cells.cell_v_cell OWNER TO cell;

--
-- Name: cell_v_gene; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_gene AS
 SELECT g.ncbi_gene_id,
    g.gene_symbol,
    g.gene_species,
    string_agg((COALESCE(s.synonyms, ''::character varying))::text, ','::text ORDER BY s.synonyms) AS synonyms
   FROM (cells.lst_gene g
     LEFT JOIN cells.lst_gene_synonyms s ON ((g.ncbi_gene_id = s.ncbi_gene_id)))
  GROUP BY g.ncbi_gene_id, g.gene_symbol, g.gene_species;


ALTER VIEW cells.cell_v_gene OWNER TO cell;

--
-- Name: user_group; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.user_group (
    id integer NOT NULL,
    group_name character varying(32) NOT NULL,
    group_desc character varying(128),
    group_role "char" DEFAULT 'G'::"char" NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE cells.user_group OWNER TO cell;

--
-- Name: user_group_member; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.user_group_member (
    group_id integer NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE cells.user_group_member OWNER TO cell;

--
-- Name: cell_v_group_detail; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_group_detail AS
 SELECT g.id AS group_id,
    g.group_name,
    g.group_desc,
    string_agg(((((u.full_name)::text || '('::text) || u.id) || ')'::text), ','::text ORDER BY u.full_name) AS member
   FROM ((cells.user_group g
     LEFT JOIN cells.user_group_member gm ON ((gm.group_id = g.id)))
     LEFT JOIN cells."user" u ON ((u.id = gm.user_id)))
  WHERE (g.group_role = 'G'::"char")
  GROUP BY g.id, g.group_name, g.group_desc;


ALTER VIEW cells.cell_v_group_detail OWNER TO cell;

--
-- Name: cell_v_group_member; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_group_member AS
 SELECT gm.group_id,
    gm.user_id,
    g.group_role,
    g.group_name,
    g.group_desc,
    u.id,
    u.full_name,
    u.email,
    u.alt_id
   FROM ((cells.user_group_member gm
     LEFT JOIN cells."user" u ON ((gm.user_id = u.id)))
     LEFT JOIN cells.user_group g ON ((g.id = gm.group_id)));


ALTER VIEW cells.cell_v_group_member OWNER TO cell;

--
-- Name: history; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.history (
    id bigint NOT NULL,
    type character varying(8) NOT NULL,
    who integer NOT NULL,
    "when" date DEFAULT CURRENT_TIMESTAMP NOT NULL,
    what character varying(128),
    entity_id bigint
);


ALTER TABLE cells.history OWNER TO cell;

--
-- Name: cell_v_history; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_history AS
 SELECT h.id,
    h.type,
    h.who,
    u.full_name,
    h."when",
    h.what,
    h.entity_id
   FROM (cells.history h
     LEFT JOIN cells."user" u ON ((u.id = h.who)));


ALTER VIEW cells.cell_v_history OWNER TO cell;

--
-- Name: lst_address; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.lst_address (
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    company character varying(64),
    address character varying(512),
    email character varying(128),
    phone character varying(32),
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE cells.lst_address OWNER TO cell;

--
-- Name: cell_v_order; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_order AS
 SELECT o.id,
    o.requestor,
    o.cell_batch_id,
    o.order_date,
    o.status,
    o.purpose,
    o.comment,
    o.shipping_id,
    o.order_needed,
    o.rule1,
    o.rule2,
    o.rule3,
    o.rule4,
    o.rule5,
    o.vial_needed,
    u.full_name AS requestor_name,
    c.name AS cell_batch_name,
    ((((a.name)::text || '('::text) || (a.company)::text) || ')'::text) AS shipping_name,
    a.address AS shipping_address
   FROM (((cells.cell_order o
     LEFT JOIN cells."user" u ON ((o.requestor = u.id)))
     LEFT JOIN cells.cell_batch c ON ((c.id = o.cell_batch_id)))
     LEFT JOIN cells.lst_address a ON ((o.shipping_id = a.id)));


ALTER VIEW cells.cell_v_order OWNER TO cell;

--
-- Name: cell_v_provenance; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.cell_v_provenance AS
 SELECT p.id,
    p.source,
    s.name AS source_name,
    p.contract_name,
    p.contract_expiration,
    p.contract_desc,
    p.comment,
    p.restriction,
    p.rule1,
    p.rule2,
    p.rule3,
    p.rule4,
    p.rule5,
    p.t1,
    p.t2,
    p.t3,
    p.source_role
   FROM (cells.cell_provenance p
     LEFT JOIN cells.lst_source s ON ((p.source = s.id)));


ALTER VIEW cells.cell_v_provenance OWNER TO cell;

--
-- Name: document; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.document (
    id integer NOT NULL,
    entity_type character varying(16) NOT NULL,
    entity_id integer NOT NULL,
    file_name character varying(256) NOT NULL,
    file_mime character varying(256) NOT NULL,
    file_path character varying(256),
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE cells.document OWNER TO cell;

--
-- Name: document_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.document_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.document_id_seq OWNER TO cell;

--
-- Name: document_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.document_id_seq OWNED BY cells.document.id;


--
-- Name: history_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.history_id_seq OWNER TO cell;

--
-- Name: history_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.history_id_seq OWNED BY cells.history.id;


--
-- Name: inv_container_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.inv_container_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER SEQUENCE cells.inv_container_id_seq OWNER TO cell;

--
-- Name: inv_container_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.inv_container_id_seq OWNED BY cells.inv_container.id;


--
-- Name: inv_mat_type_ID_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells."inv_mat_type_ID_seq"
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells."inv_mat_type_ID_seq" OWNER TO cell;

--
-- Name: inv_mat_type_ID_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells."inv_mat_type_ID_seq" OWNED BY cells.inv_mat_type.id;


--
-- Name: inv_unit; Type: TABLE; Schema: cells; Owner: cell
--

CREATE TABLE cells.inv_unit (
    id integer NOT NULL,
    type character varying(8) NOT NULL,
    name character varying(8) NOT NULL,
    "desc" character varying(64),
    conv double precision
);


ALTER TABLE cells.inv_unit OWNER TO cell;

--
-- Name: inv_unit_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.inv_unit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.inv_unit_id_seq OWNER TO cell;

--
-- Name: inv_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.inv_unit_id_seq OWNED BY cells.inv_unit.id;


--
-- Name: inv_v_cell_vial; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.inv_v_cell_vial AS
 SELECT v.vial_id,
    v.cont_id,
    v.barcode,
    v.x,
    v.y,
    v."position",
    v.volume,
    v.volume_unit,
    v.weight,
    v.tare_weight,
    v.weight_unit,
    v.conc,
    v.conc_unit,
    v.mat_id,
    batch.name AS cell_batch_name,
    v.mat_type,
    v.vial_type,
    v.t1,
    v.t2,
    v.t3,
    v.d1,
    v.d2,
    v.d3,
    t.name AS vial_type_name,
    t."desc" AS vial_type_desc,
    mt.name AS material_type_name,
    mt."desc" AS material_type_desc
   FROM (((cells.inv_vial v
     LEFT JOIN cells.inv_vial_type t ON ((v.vial_type = t.id)))
     LEFT JOIN cells.inv_mat_type mt ON ((v.mat_type = mt.id)))
     LEFT JOIN cells.cell_batch batch ON ((v.mat_id = batch.id)));


ALTER VIEW cells.inv_v_cell_vial OWNER TO cell;

--
-- Name: inv_v_tank; Type: VIEW; Schema: cells; Owner: cell
--

CREATE VIEW cells.inv_v_tank AS
 SELECT box.id AS box_id,
    box.status AS box_status,
    box.name AS box_name,
    box."desc" AS box_desc,
    box.barcode AS box_barcode,
    box.x AS box_x,
    box.y AS box_y,
    box."position" AS box_position,
    rack.id AS rack_id,
    rack.status AS rack_status,
    rack.name AS rack_name,
    rack."desc" AS rack_desc,
    rack.barcode AS rack_barcode,
    rack.x AS rack_x,
    rack.y AS rack_y,
    rack."position" AS rack_position,
    tank.id AS tank_id,
    tank.status AS tank_status,
    tank.name AS tank_name,
    tank."desc" AS tank_desc,
    tank.barcode AS tank_barcode
   FROM ((cells.inv_container box
     LEFT JOIN cells.inv_container rack ON ((rack.id = box.parent_id)))
     LEFT JOIN cells.inv_container tank ON ((tank.id = rack.parent_id)))
  WHERE ((box.type)::text = 'BOX'::text);


ALTER VIEW cells.inv_v_tank OWNER TO cell;

--
-- Name: inv_vial_type_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.inv_vial_type_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.inv_vial_type_id_seq OWNER TO cell;

--
-- Name: inv_vial_type_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.inv_vial_type_id_seq OWNED BY cells.inv_vial_type.id;


--
-- Name: inv_vial_vial_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.inv_vial_vial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.inv_vial_vial_id_seq OWNER TO cell;

--
-- Name: inv_vial_vial_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.inv_vial_vial_id_seq OWNED BY cells.inv_vial.vial_id;


--
-- Name: lst_address_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.lst_address_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.lst_address_id_seq OWNER TO cell;

--
-- Name: lst_address_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.lst_address_id_seq OWNED BY cells.lst_address.id;


--
-- Name: lst_source_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.lst_source_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.lst_source_id_seq OWNER TO cell;

--
-- Name: lst_source_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.lst_source_id_seq OWNED BY cells.lst_source.id;


--
-- Name: lst_species_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.lst_species_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.lst_species_id_seq OWNER TO cell;

--
-- Name: lst_species_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.lst_species_id_seq OWNED BY cells.lst_species.id;


--
-- Name: user_group_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.user_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.user_group_id_seq OWNER TO cell;

--
-- Name: user_group_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.user_group_id_seq OWNED BY cells.user_group.id;


--
-- Name: user_id_seq; Type: SEQUENCE; Schema: cells; Owner: cell
--

CREATE SEQUENCE cells.user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE cells.user_id_seq OWNER TO cell;

--
-- Name: user_id_seq; Type: SEQUENCE OWNED BY; Schema: cells; Owner: cell
--

ALTER SEQUENCE cells.user_id_seq OWNED BY cells."user".id;


--
-- Name: cell_accession id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession ALTER COLUMN id SET DEFAULT nextval('cells.cell_accession_id_seq'::regclass);


--
-- Name: cell_accession_gene id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession_gene ALTER COLUMN id SET DEFAULT nextval('cells.cell_accession_gene_id_seq'::regclass);


--
-- Name: cell_assay id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_assay ALTER COLUMN id SET DEFAULT nextval('cells.cell_assay_id_seq'::regclass);


--
-- Name: cell_batch id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_batch ALTER COLUMN id SET DEFAULT nextval('cells.cell_batch_id_seq'::regclass);


--
-- Name: cell_biosafety id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_biosafety ALTER COLUMN id SET DEFAULT nextval('cells.cell_biosafety_id_seq'::regclass);


--
-- Name: cell_cell id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_cell ALTER COLUMN id SET DEFAULT nextval('cells.cell_cell_id_seq'::regclass);


--
-- Name: cell_engineering_method id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_engineering_method ALTER COLUMN id SET DEFAULT nextval('cells.cell_engineering_method_id_seq'::regclass);


--
-- Name: cell_order id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_order ALTER COLUMN id SET DEFAULT nextval('cells.cell_order_id_seq'::regclass);


--
-- Name: cell_provenance id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_provenance ALTER COLUMN id SET DEFAULT nextval('cells.cell_provenance_id_seq'::regclass);


--
-- Name: cell_reporter id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_reporter ALTER COLUMN id SET DEFAULT nextval('cells.cell_reporter_id_seq'::regclass);


--
-- Name: cell_tag id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_tag ALTER COLUMN id SET DEFAULT nextval('cells.cell_tag_id_seq'::regclass);


--
-- Name: document id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.document ALTER COLUMN id SET DEFAULT nextval('cells.document_id_seq'::regclass);


--
-- Name: history id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.history ALTER COLUMN id SET DEFAULT nextval('cells.history_id_seq'::regclass);


--
-- Name: inv_container id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_container ALTER COLUMN id SET DEFAULT nextval('cells.inv_container_id_seq'::regclass);


--
-- Name: inv_mat_type id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_mat_type ALTER COLUMN id SET DEFAULT nextval('cells."inv_mat_type_ID_seq"'::regclass);


--
-- Name: inv_unit id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_unit ALTER COLUMN id SET DEFAULT nextval('cells.inv_unit_id_seq'::regclass);


--
-- Name: inv_vial vial_id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_vial ALTER COLUMN vial_id SET DEFAULT nextval('cells.inv_vial_vial_id_seq'::regclass);


--
-- Name: inv_vial_type id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_vial_type ALTER COLUMN id SET DEFAULT nextval('cells.inv_vial_type_id_seq'::regclass);


--
-- Name: lst_address id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.lst_address ALTER COLUMN id SET DEFAULT nextval('cells.lst_address_id_seq'::regclass);


--
-- Name: lst_source id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.lst_source ALTER COLUMN id SET DEFAULT nextval('cells.lst_source_id_seq'::regclass);


--
-- Name: lst_species id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.lst_species ALTER COLUMN id SET DEFAULT nextval('cells.lst_species_id_seq'::regclass);


--
-- Name: user id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells."user" ALTER COLUMN id SET DEFAULT nextval('cells.user_id_seq'::regclass);


--
-- Name: user_group id; Type: DEFAULT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.user_group ALTER COLUMN id SET DEFAULT nextval('cells.user_group_id_seq'::regclass);


--
-- Name: app_session app_session_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.app_session
    ADD CONSTRAINT app_session_pkey PRIMARY KEY (id);


--
-- Name: app_user_pref app_user_pref_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.app_user_pref
    ADD CONSTRAINT app_user_pref_pkey PRIMARY KEY ("user", page);


--
-- Name: cell_accession_gene cell_accession_gene_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession_gene
    ADD CONSTRAINT cell_accession_gene_pkey PRIMARY KEY (id);


--
-- Name: cell_accession cell_accession_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession
    ADD CONSTRAINT cell_accession_pkey PRIMARY KEY (id);


--
-- Name: cell_accession_provenance cell_accession_provenance_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession_provenance
    ADD CONSTRAINT cell_accession_provenance_pkey PRIMARY KEY (accession_id, provenance_id);


--
-- Name: cell_assay cell_assay_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_assay
    ADD CONSTRAINT cell_assay_pkey PRIMARY KEY (id);


--
-- Name: cell_batch cell_batch_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_batch
    ADD CONSTRAINT cell_batch_pkey PRIMARY KEY (id);


--
-- Name: cell_biosafety cell_biosafety_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_biosafety
    ADD CONSTRAINT cell_biosafety_pkey PRIMARY KEY (id);


--
-- Name: cell_cell cell_cell_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_cell
    ADD CONSTRAINT cell_cell_pkey PRIMARY KEY (id);


--
-- Name: cell_dict cell_dict_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_dict
    ADD CONSTRAINT cell_dict_pkey PRIMARY KEY (name, key);


--
-- Name: cell_engineering_method cell_engineering_method_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_engineering_method
    ADD CONSTRAINT cell_engineering_method_pkey PRIMARY KEY (id);


--
-- Name: cell_order cell_order_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_order
    ADD CONSTRAINT cell_order_pkey PRIMARY KEY (id);


--
-- Name: cell_provenance cell_provenance_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_provenance
    ADD CONSTRAINT cell_provenance_pkey PRIMARY KEY (id);


--
-- Name: cell_reporter cell_reporter_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_reporter
    ADD CONSTRAINT cell_reporter_pkey PRIMARY KEY (id);


--
-- Name: cell_tag cell_tag_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_tag
    ADD CONSTRAINT cell_tag_pkey PRIMARY KEY (id);


--
-- Name: document document_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.document
    ADD CONSTRAINT document_pkey PRIMARY KEY (id);


--
-- Name: history history_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.history
    ADD CONSTRAINT history_pkey PRIMARY KEY (id);


--
-- Name: inv_container inv_container_barcode_key; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_container
    ADD CONSTRAINT inv_container_barcode_key UNIQUE (barcode);


--
-- Name: inv_container inv_container_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_container
    ADD CONSTRAINT inv_container_pkey PRIMARY KEY (id);


--
-- Name: inv_mat_type inv_mat_type_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_mat_type
    ADD CONSTRAINT inv_mat_type_pkey PRIMARY KEY (id);


--
-- Name: inv_unit inv_unit_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_unit
    ADD CONSTRAINT inv_unit_pkey PRIMARY KEY (id);


--
-- Name: inv_vial inv_vial_barcode_key; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_vial
    ADD CONSTRAINT inv_vial_barcode_key UNIQUE (barcode);


--
-- Name: inv_vial inv_vial_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_vial
    ADD CONSTRAINT inv_vial_pkey PRIMARY KEY (vial_id);


--
-- Name: inv_vial_type inv_vial_type_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.inv_vial_type
    ADD CONSTRAINT inv_vial_type_pkey PRIMARY KEY (id);


--
-- Name: lst_address lst_address_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.lst_address
    ADD CONSTRAINT lst_address_pkey PRIMARY KEY (id);


--
-- Name: lst_gene lst_gene_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.lst_gene
    ADD CONSTRAINT lst_gene_pkey PRIMARY KEY (ncbi_gene_id);


--
-- Name: lst_source lst_source_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.lst_source
    ADD CONSTRAINT lst_source_pkey PRIMARY KEY (id);


--
-- Name: lst_species lst_species_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.lst_species
    ADD CONSTRAINT lst_species_pkey PRIMARY KEY (id);


--
-- Name: user_group_member user_group_member_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.user_group_member
    ADD CONSTRAINT user_group_member_pkey PRIMARY KEY (group_id, user_id);


--
-- Name: user_group user_group_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.user_group
    ADD CONSTRAINT user_group_pkey PRIMARY KEY (id);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: cell_mv_accession_ix_name; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_accession_ix_name ON cells.cell_mv_accession USING btree (accession_name);


--
-- Name: cell_mv_accession_ix_reporter; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_accession_ix_reporter ON cells.cell_mv_accession USING btree (accession_reporter);


--
-- Name: cell_mv_accession_ix_search_string; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_accession_ix_search_string ON cells.cell_mv_accession USING btree (search_string);


--
-- Name: cell_mv_accession_ix_species; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_accession_ix_species ON cells.cell_mv_accession USING btree (cell_species);


--
-- Name: cell_mv_accession_ix_status; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_accession_ix_status ON cells.cell_mv_accession USING btree (accession_status);


--
-- Name: cell_mv_accession_ix_tag; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_accession_ix_tag ON cells.cell_mv_accession USING btree (accession_tag);


--
-- Name: cell_mv_batch_ix_name; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_batch_ix_name ON cells.cell_mv_batch USING btree (batch_name);


--
-- Name: cell_mv_batch_ix_reporter; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_batch_ix_reporter ON cells.cell_mv_batch USING btree (accession_reporter);


--
-- Name: cell_mv_batch_ix_search_string; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_batch_ix_search_string ON cells.cell_mv_batch USING btree (search_string);


--
-- Name: cell_mv_batch_ix_species; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_batch_ix_species ON cells.cell_mv_batch USING btree (cell_species);


--
-- Name: cell_mv_batch_ix_status; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_batch_ix_status ON cells.cell_mv_batch USING btree (accession_status);


--
-- Name: cell_mv_batch_ix_tag; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_batch_ix_tag ON cells.cell_mv_batch USING btree (accession_tag);


--
-- Name: cell_mv_batch_ix_tank; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_batch_ix_tank ON cells.cell_mv_batch USING btree (tank_id);


--
-- Name: cell_mv_cell_ix_cellosaurus_id; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_cell_ix_cellosaurus_id ON cells.cell_mv_cell USING btree (cellosaurus_id);


--
-- Name: cell_mv_cell_ix_disease; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_cell_ix_disease ON cells.cell_mv_cell USING btree (disease);


--
-- Name: cell_mv_cell_ix_name; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_cell_ix_name ON cells.cell_mv_cell USING btree (name);


--
-- Name: cell_mv_cell_ix_search_string; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_cell_ix_search_string ON cells.cell_mv_cell USING btree (search_string);


--
-- Name: cell_mv_cell_ix_source_tissue; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_cell_ix_source_tissue ON cells.cell_mv_cell USING btree (source_tissue);


--
-- Name: cell_mv_gene_ix_symbol; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_gene_ix_symbol ON cells.cell_mv_gene USING btree (gene_symbol);


--
-- Name: cell_mv_gene_ix_synonyms; Type: INDEX; Schema: cells; Owner: cell
--

CREATE INDEX cell_mv_gene_ix_synonyms ON cells.cell_mv_gene USING btree (synonyms);


--
-- Name: cell_accession cell_accession_cell_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession
    ADD CONSTRAINT cell_accession_cell_id_fkey FOREIGN KEY (cell_id) REFERENCES cells.cell_cell(id) NOT VALID;


--
-- Name: cell_accession cell_accession_cell_source_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession
    ADD CONSTRAINT cell_accession_cell_source_fkey FOREIGN KEY (cell_source) REFERENCES cells.lst_source(id) NOT VALID;


--
-- Name: cell_accession cell_accession_contact_person_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession
    ADD CONSTRAINT cell_accession_contact_person_fkey FOREIGN KEY (contact_person) REFERENCES cells."user"(id) NOT VALID;


--
-- Name: cell_accession cell_accession_engineering_method_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession
    ADD CONSTRAINT cell_accession_engineering_method_fkey FOREIGN KEY (engineering_method) REFERENCES cells.cell_engineering_method(id) NOT VALID;


--
-- Name: cell_accession cell_accession_engineering_source_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession
    ADD CONSTRAINT cell_accession_engineering_source_fkey FOREIGN KEY (engineering_source) REFERENCES cells.lst_source(id) NOT VALID;


--
-- Name: cell_accession_gene cell_accession_gene_accession_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession_gene
    ADD CONSTRAINT cell_accession_gene_accession_id_fkey FOREIGN KEY (accession_id) REFERENCES cells.cell_accession(id) NOT VALID;


--
-- Name: cell_accession_gene cell_accession_gene_ncbi_gene_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession_gene
    ADD CONSTRAINT cell_accession_gene_ncbi_gene_id_fkey FOREIGN KEY (ncbi_gene_id) REFERENCES cells.lst_gene(ncbi_gene_id) NOT VALID;


--
-- Name: cell_accession_provenance cell_accession_provenance_accession_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession_provenance
    ADD CONSTRAINT cell_accession_provenance_accession_id_fkey FOREIGN KEY (accession_id) REFERENCES cells.cell_accession(id) NOT VALID;


--
-- Name: cell_accession_provenance cell_accession_provenance_provenance_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession_provenance
    ADD CONSTRAINT cell_accession_provenance_provenance_id_fkey FOREIGN KEY (provenance_id) REFERENCES cells.cell_provenance(id) NOT VALID;


--
-- Name: cell_accession cell_accession_reporter_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession
    ADD CONSTRAINT cell_accession_reporter_fkey FOREIGN KEY (reporter) REFERENCES cells.cell_reporter(id) NOT VALID;


--
-- Name: cell_accession cell_accession_tag_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_accession
    ADD CONSTRAINT cell_accession_tag_fkey FOREIGN KEY (tag) REFERENCES cells.cell_tag(id) NOT VALID;


--
-- Name: cell_assay cell_assay_batch_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_assay
    ADD CONSTRAINT cell_assay_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES cells.cell_batch(id) NOT VALID;


--
-- Name: cell_batch cell_batch_accession_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_batch
    ADD CONSTRAINT cell_batch_accession_id_fkey FOREIGN KEY (accession_id) REFERENCES cells.cell_accession(id) NOT VALID;


--
-- Name: cell_batch cell_batch_contact_person_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_batch
    ADD CONSTRAINT cell_batch_contact_person_fkey FOREIGN KEY (contact_person) REFERENCES cells."user"(id) NOT VALID;


--
-- Name: cell_biosafety cell_biosafety_accession_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.cell_biosafety
    ADD CONSTRAINT cell_biosafety_accession_id_fkey FOREIGN KEY (accession_id) REFERENCES cells.cell_accession(id) NOT VALID;


--
-- Name: user_group_member user_group_member_group_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.user_group_member
    ADD CONSTRAINT user_group_member_group_id_fkey FOREIGN KEY (group_id) REFERENCES cells.user_group(id) NOT VALID;


--
-- Name: user_group_member user_group_member_user_id_fkey; Type: FK CONSTRAINT; Schema: cells; Owner: cell
--

ALTER TABLE ONLY cells.user_group_member
    ADD CONSTRAINT user_group_member_user_id_fkey FOREIGN KEY (user_id) REFERENCES cells."user"(id) NOT VALID;


--
-- PostgreSQL database dump complete
--

\unrestrict Aj4qCTBf6VprgMbxptfTApoQmKVu4sMllyqmnQc3z1ucUKI3FXNMgnU0PtcriAZ

