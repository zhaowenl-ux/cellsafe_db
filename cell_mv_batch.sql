 SELECT 
    b.id AS batch_id,
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
    a.passage AS accession_passage_num,
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
    c.id AS cell_id,
    c.name AS cell_name,
    c.disease AS cell_disease,
    c.source_tissue AS cell_source_tissue,
    c.source_type as cell_source_type,
    c.species AS cell_species,
    ((s.common_name || '(') || s.scientific_name) || ')' AS cell_species_name,
    c.cellosaurus_id AS cell_cellosaurus_id,
    c.reference AS cell_reference,
    c.comments AS cell_comments,
    c.t1 AS cell_t1,
    c.t2 AS cell_t2,
    c.t3 AS cell_t3,
    cv.synonyms AS cell_synonyms,
    gene.ncbi_gene_id AS ncbi_gene_id,
    gene.gene_symbol  AS gene_symbol,
    inv.tank_id,
    inv.tank_name,
    (SELECT count(vial_id) FROM cells.cell_v_inventory where mat_id = b.id) AS vial_count,
    a.id
    || '|' || cells.remove_no_word(b.name)
    || '|' || cells.remove_no_word(b.alt_name)
    || '|' || cells.remove_no_word(b.material_state)
    || '|' || cells.remove_no_word(b.eln)
    || '|' || cells.remove_no_word(bu.full_name)
    || '|' || cells.remove_no_word(b.culture_type)
    || '|' || cells.remove_no_word(b.culture_protocol)
    || '|' || cells.remove_no_word(b.dissociation_solution)
    || '|' || cells.remove_no_word(b.medium_growth)
    || '|' || cells.remove_no_word(b.medium_growth_suppl) 
    || '|' || cells.remove_no_word(b.medium_freezing) 
    || '|' || cells.remove_no_word(b.comments) 
    || '|' || cells.remove_no_word(b.t1)
    || '|' || cells.remove_no_word(b.t2)
    || '|' || cells.remove_no_word(b.t3)
    || '|' || cells.remove_no_word(b.t4)
    || '|' || cells.remove_no_word(gene.gene_symbol)
    || '|' || cells.remove_no_word(cv.synonyms)
	|| '|' || cells.remove_no_word(c.name) 
	|| '|' || cells.remove_no_word(c.disease) 
	|| '|' || cells.remove_no_word(c.source_tissue) 
	|| '|' || cells.remove_no_word(c.cellosaurus_id) 
	|| '|' || cells.remove_no_word(c.reference) 
	|| '|' || cells.remove_no_word(c.comments) 
	|| '|' || cells.remove_no_word(s.common_name) 
	|| '|' || cells.remove_no_word(s.scientific_name) 
    || '|' || cells.remove_no_word(c.t1)
    || '|' || cells.remove_no_word(c.t2)    
    || '|' || cells.remove_no_word(c.t3) 
    || '|' || cells.remove_no_word(a.name)  
    || '|' || cells.remove_no_word(a.eln)   
    || '|' || cells.remove_no_word(a.catalog_num)   
    || '|' || cells.remove_no_word(a.pool_name)  
    || '|' || cells.remove_no_word(a.clone_name)  
    || '|' || cells.remove_no_word(a.comments)  
    || '|' || cells.remove_no_word(a.t1)  
    || '|' || cells.remove_no_word(a.t2)  
    || '|' || cells.remove_no_word(a.t3)  
    || '|' || cells.remove_no_word(tag.name) 
    || '|' || cells.remove_no_word(r.name)  
    || '|' || cells.remove_no_word(cs.name)  
    || '|' || cells.remove_no_word(es.name)  
    || '|' || cells.remove_no_word(em.name)   search_string,
    (select count(cb.id) from cells.cell_batch cb where cb.accession_id = a.id) AS batch_count,
	(select count(provenance_id) from cells.cell_accession_provenance where accession_id = a.id) AS provenance_count,
    cb.id as biosafety_id,
    cb. biosafety_level  as biosafety_level,
    cb.gmo as biosafety_gmo,
    cb.expiration_date as biosafety_expiration_date
   FROM cells.cell_batch b
    LEFT JOIN cells.cell_accession a ON b.accession_id = a.id
     LEFT JOIN cells.cell_tag tag ON a.tag = tag.id
     LEFT JOIN cells.cell_reporter r ON a.reporter = r.id
     LEFT JOIN cells.lst_source cs ON a.cell_source = cs.id
     LEFT JOIN cells.lst_source es ON a.engineering_source = es.id
     LEFT JOIN cells.cell_engineering_method em ON a.engineering_method = em.id
     LEFT JOIN cells."user" u ON a.contact_person = u.id
     LEFT JOIN cells.cell_cell c ON a.cell_id = c.id
     LEFT JOIN cells.lst_species s ON c.species = s.id
     LEFT JOIN cells.cell_v_synonyms cv ON c.cellosaurus_id = cv.cellosaurus_id
     LEFT JOIN cells.cell_biosafety cb ON a.id = cb.accession_id
     LEFT JOIN cells.cell_v_accession_gene gene ON a.id = gene.accession_id
     LEFT JOIN cells."user" bu ON bu.id = b.id
     LEFT JOIN cells.cell_v_cell_tank inv on inv.cell_batch_id = b.id
where b.is_active = true;

create index cell_mv_batch_ix_search_string on cells.cell_mv_batch (search_string);
create index cell_mv_batch_ix_name on cells.cell_mv_batch (batch_name);
create index cell_mv_batch_ix_tag on cells.cell_mv_batch (accession_tag);
create index cell_mv_batch_ix_reporter on cells.cell_mv_batch (accession_reporter);
create index cell_mv_batch_ix_status on cells.cell_mv_batch (accession_status);
create index cell_mv_batch_ix_species  on cells.cell_mv_batch (cell_species);  
create index cell_mv_batch_ix_tank  on cells.cell_mv_batch (tank_id);     