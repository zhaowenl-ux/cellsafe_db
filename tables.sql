-- SEQUENCE: cells.inv_container_id_seq

-- DROP SEQUENCE IF EXISTS cells.inv_container_id_seq;

CREATE SEQUENCE IF NOT EXISTS cells.inv_container_id_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 2147483647
    CACHE 1;



ALTER SEQUENCE cells.inv_container_id_seq
    OWNER TO cell;
-- Table: cells.inv_container

-- DROP TABLE IF EXISTS cells.inv_container;

CREATE TABLE IF NOT EXISTS cells.inv_container
(
    id bigint NOT NULL DEFAULT nextval('cells.inv_container_id_seq'::regclass),
    parent_id bigint,
    type character varying(8) COLLATE pg_catalog."default" NOT NULL,
    status character varying(8) COLLATE pg_catalog."default" NOT NULL,
    name character varying(16) COLLATE pg_catalog."default" NOT NULL,
    "desc" character varying(128) COLLATE pg_catalog."default",
    barcode character varying(64) COLLATE pg_catalog."default",
    x integer NOT NULL,
    y integer NOT NULL DEFAULT 1,
    "position" character varying(8) COLLATE pg_catalog."default",
    site character varying(16) COLLATE pg_catalog."default",
    x_size integer NOT NULL DEFAULT 1,
    y_size integer NOT NULL DEFAULT 1,
    t1 character varying(64) COLLATE pg_catalog."default",
    t2 character varying(64) COLLATE pg_catalog."default",
    t3 character varying(64) COLLATE pg_catalog."default",
    capacity integer,
    n1 numeric,
    n2 numeric,
    n3 numeric,
    CONSTRAINT inv_container_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;
ALTER SEQUENCE cells.inv_container_id_seq
    OWNED BY cells.inv_container.id;
ALTER TABLE IF EXISTS cells.inv_container
    OWNER to cell;

-- View: cells.cell_v_inventory

-- DROP VIEW cells.cell_v_inventory;

CREATE OR REPLACE VIEW cells.cell_v_inventory
 AS
 SELECT vial.vial_id,
    vial.cont_id,
    vial.barcode,
    vial.x,
    vial.y,
    vial."position",
    vial.volume,
    vial.volume_unit,
    vial.weight,
    vial.tare_weight,
    vial.weight_unit,
    vial.conc,
    vial.conc_unit,
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
    box.barcode::text = box.barcode::text AS "?column?",
    box.n1 AS box_owner,
    rack.id AS rack_id,
    rack.name AS rack_name,
    rack."desc" AS rack_desc,
    rack.barcode AS rack_barcode,
    tank.id AS tank_id,
    tank.name AS tank_name,
    tank."desc" AS tank_desc,
    tank.barcode AS tank_barcode
   FROM cells.inv_vial vial
     JOIN cells.inv_container box ON box.id = vial.cont_id
     JOIN cells.inv_container rack ON box.parent_id = rack.id
     JOIN cells.inv_container tank ON rack.parent_id = tank.id;

ALTER TABLE cells.cell_v_inventory
    OWNER TO cell;