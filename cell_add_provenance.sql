-- PROCEDURE: cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text)

-- DROP PROCEDURE IF EXISTS cells.mod_cell_cell(integer, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE cells.add_cell_provenance(
	 IN p_accession_id          integer
    ,IN p_provenance_id         integer
)
LANGUAGE 'plpgsql'
AS $BODY$
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
$BODY$;
ALTER PROCEDURE cells.add_cell_provenance(integer, integer)
    OWNER TO cell;
			