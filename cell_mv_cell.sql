 SELECT c.id,
    c.name,
    c.disease,
    c.source_tissue,
    c.source_type,
    c.species,
    ((s.common_name || '(') || s.scientific_name) || ')' AS species_name,
    c.cellosaurus_id,
    c.reference,
    c.comments,
    c.t1,
    c.t2,
    c.t3,
    cs.synonyms,
    c.id
    || '|' || cells.remove_no_word(cs.synonyms)
	|| cells.remove_no_word(c.name) 
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
    AS search_string,
    (select count(id) from cells.cell_accession ca where ca.cell_id = c.id) AS accession_count,
    (select count(cb.id) from cells.cell_batch cb
        left join cells.cell_accession ca on ca.id = cb.accession_id where ca.cell_id = c.id) AS batch_count
   FROM cells.cell_cell c
     LEFT JOIN cells.lst_species s ON c.species = s.id
     left join cells.cell_v_synonyms cs on c.cellosaurus_id = cs.cellosaurus_id;



     create index cell_mv_cell_ix_search_string on cells.cell_mv_cell (search_string);
     create index cell_mv_cell_ix_name on cells.cell_mv_cell (name);
     create index cell_mv_cell_ix_disease on cells.cell_mv_cell (disease);
     create index cell_mv_cell_ix_source_tissue on cells.cell_mv_cell (source_tissue);
     create index cell_mv_cell_ix_cellosaurus_id on cells.cell_mv_cell (cellosaurus_id);
