ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';


BEGIN
    EXECUTE IMMEDIATE 'DROP VIEW vw_mortalidade_publica';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE fato_mortalidade CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE dim_causa_cid CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE dim_uf CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/


CREATE TABLE dim_uf (
    uf_id NUMBER(2) NOT NULL,
    sigla CHAR(2) NOT NULL,
    nome VARCHAR2(50) NOT NULL,
    regiao VARCHAR2(20) NOT NULL,

    CONSTRAINT pk_dim_uf
        PRIMARY KEY (uf_id),

    CONSTRAINT uk_dim_uf_sigla
        UNIQUE (sigla),

    CONSTRAINT ck_dim_uf_regiao
        CHECK (regiao IN (
            'Norte',
            'Nordeste',
            'Centro-Oeste',
            'Sudeste',
            'Sul'
        ))
);


CREATE TABLE dim_causa_cid (
    causa_id NUMBER(5) NOT NULL,
    codigo VARCHAR2(20) NOT NULL,
    descricao VARCHAR2(300) NOT NULL,
    nivel NUMBER(1) NOT NULL,
    tipo VARCHAR2(20) NOT NULL,
    texto_original VARCHAR2(400) NOT NULL,

    CONSTRAINT pk_dim_causa_cid
        PRIMARY KEY (causa_id),

    CONSTRAINT uk_dim_causa_texto
        UNIQUE (texto_original),

    CONSTRAINT ck_dim_causa_nivel
        CHECK (nivel BETWEEN 1 AND 4),

    CONSTRAINT ck_dim_causa_tipo
        CHECK (tipo IN (
            'GRUPO',
            'SUBGRUPO',
            'CATEGORIA',
            'DETALHE'
        ))
);


CREATE TABLE fato_mortalidade (
    mortalidade_id NUMBER(10) NOT NULL,
    uf_id NUMBER(2) NOT NULL,
    causa_id NUMBER(5) NOT NULL,
    periodo_inicio NUMBER(4) DEFAULT 2019 NOT NULL,
    periodo_fim NUMBER(4) DEFAULT 2024 NOT NULL,
    obitos NUMBER(12) DEFAULT 0 NOT NULL,
    data_carga DATE DEFAULT SYSDATE NOT NULL,

    CONSTRAINT pk_fato_mortalidade
        PRIMARY KEY (mortalidade_id),

    CONSTRAINT fk_fato_mortalidade_uf
        FOREIGN KEY (uf_id)
        REFERENCES dim_uf (uf_id),

    CONSTRAINT fk_fato_mortalidade_causa
        FOREIGN KEY (causa_id)
        REFERENCES dim_causa_cid (causa_id),

    CONSTRAINT uk_fato_mortalidade
        UNIQUE (uf_id, causa_id, periodo_inicio, periodo_fim),

    CONSTRAINT ck_fato_obitos
        CHECK (obitos >= 0),

    CONSTRAINT ck_fato_periodo
        CHECK (periodo_inicio <= periodo_fim)
);


CREATE INDEX ix_fato_mortalidade_uf
ON fato_mortalidade (uf_id);

CREATE INDEX ix_fato_mortalidade_causa
ON fato_mortalidade (causa_id);

CREATE INDEX ix_fato_mortalidade_periodo
ON fato_mortalidade (periodo_inicio, periodo_fim);

CREATE INDEX ix_dim_causa_codigo
ON dim_causa_cid (codigo);


INSERT INTO dim_uf VALUES (1,'RO', 'Rondônia', 'Norte');
INSERT INTO dim_uf VALUES (2,'AC', 'Acre', 'Norte');
INSERT INTO dim_uf VALUES (3,'AM', 'Amazonas', 'Norte');
INSERT INTO dim_uf VALUES (4,'RR', 'Roraima','Norte');
INSERT INTO dim_uf VALUES (5,'PA', 'Pará', 'Norte');
INSERT INTO dim_uf VALUES (6,'AP', 'Amapá','Norte');
INSERT INTO dim_uf VALUES (7,'TO', 'Tocantins','Norte');

INSERT INTO dim_uf VALUES (8,'MA', 'Maranhão', 'Nordeste');
INSERT INTO dim_uf VALUES (9,'PI', 'Piauí','Nordeste');
INSERT INTO dim_uf VALUES (10, 'CE', 'Ceará','Nordeste');
INSERT INTO dim_uf VALUES (11, 'RN', 'Rio Grande do Norte','Nordeste');
INSERT INTO dim_uf VALUES (12, 'PB', 'Paraíba','Nordeste');
INSERT INTO dim_uf VALUES (13, 'PE', 'Pernambuco', 'Nordeste');
INSERT INTO dim_uf VALUES (14, 'AL', 'Alagoas','Nordeste');
INSERT INTO dim_uf VALUES (15, 'SE', 'Sergipe','Nordeste');
INSERT INTO dim_uf VALUES (16, 'BA', 'Bahia','Nordeste');

INSERT INTO dim_uf VALUES (17, 'MG', 'Minas Gerais', 'Sudeste');
INSERT INTO dim_uf VALUES (18, 'ES', 'Espírito Santo', 'Sudeste');
INSERT INTO dim_uf VALUES (19, 'RJ', 'Rio de Janeiro', 'Sudeste');
INSERT INTO dim_uf VALUES (20, 'SP', 'São Paulo','Sudeste');

INSERT INTO dim_uf VALUES (21, 'PR', 'Paraná', 'Sul');
INSERT INTO dim_uf VALUES (22, 'SC', 'Santa Catarina', 'Sul');
INSERT INTO dim_uf VALUES (23, 'RS', 'Rio Grande do Sul','Sul');

INSERT INTO dim_uf VALUES (24, 'MS', 'Mato Grosso do Sul', 'Centro-Oeste');
INSERT INTO dim_uf VALUES (25, 'MT', 'Mato Grosso','Centro-Oeste');
INSERT INTO dim_uf VALUES (26, 'GO', 'Goiás','Centro-Oeste');
INSERT INTO dim_uf VALUES (27, 'DF', 'Distrito Federal', 'Centro-Oeste');

COMMIT;


BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE stg_mortalidade_datasus';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

CREATE TABLE stg_mortalidade_datasus (
    causa_cid_br10 VARCHAR2(400),
    uf CHAR(2),
    obitos NUMBER(12)
);


INSERT INTO dim_causa_cid (
    causa_id,
    codigo,
    descricao,
    nivel,
    tipo,
    texto_original
)
SELECT
    ROW_NUMBER() OVER (ORDER BY causa_cid_br10) AS causa_id,

    REGEXP_SUBSTR(REGEXP_REPLACE(causa_cid_br10, '^\.+\s*', ''), '^[^ ]+') AS codigo,

    REGEXP_REPLACE(REGEXP_REPLACE(causa_cid_br10, '^\.+\s*', ''), '^[^ ]+\s*','') AS descricao,

    CASE
        WHEN causa_cid_br10 LIKE '.....%' THEN 4
        WHEN causa_cid_br10 LIKE '...%' THEN 3
        WHEN causa_cid_br10 LIKE '.%' THEN 2
        ELSE 1
    END AS nivel,

    CASE
        WHEN REGEXP_LIKE(REGEXP_SUBSTR(REGEXP_REPLACE(causa_cid_br10, '^\.+\s*', ''), '^[^ ]+'), '^[0-9]{3}-[0-9]{3}$')
        AND causa_cid_br10 NOT LIKE '.%'
        THEN 'GRUPO'

        WHEN REGEXP_LIKE(REGEXP_SUBSTR(REGEXP_REPLACE(causa_cid_br10, '^\.+\s*', ''), '^[^ ]+'), '^[0-9]{3}-[0-9]{3}$')
        THEN 'SUBGRUPO'

        WHEN REGEXP_LIKE(REGEXP_SUBSTR(REGEXP_REPLACE(causa_cid_br10, '^\.+\s*', ''), '^[^ ]+'), '^[0-9]{3}\.[0-9]+$')
        THEN 'DETALHE'

        ELSE 'CATEGORIA'
    END AS tipo,

    causa_cid_br10 AS texto_original

FROM (
    SELECT DISTINCT causa_cid_br10
    FROM stg_mortalidade_datasus
    WHERE causa_cid_br10 IS NOT NULL
);

COMMIT;


BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_fato_mortalidade';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -2289 THEN
            RAISE;
        END IF;
END;
/

CREATE SEQUENCE seq_fato_mortalidade
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


INSERT INTO fato_mortalidade (
    mortalidade_id,
    uf_id,
    causa_id,
    periodo_inicio,
    periodo_fim,
    obitos,
    data_carga
)
SELECT
    seq_fato_mortalidade.NEXTVAL,
    u.uf_id,
    c.causa_id,
    2019 AS periodo_inicio,
    2024 AS periodo_fim,
    NVL(s.obitos, 0) AS obitos,
    SYSDATE AS data_carga
FROM stg_mortalidade_datasus s
INNER JOIN dim_uf u
    ON u.sigla = s.uf
INNER JOIN dim_causa_cid c
    ON c.texto_original = s.causa_cid_br10;

COMMIT;


CREATE OR REPLACE VIEW vw_mortalidade_publica AS
SELECT
    f.mortalidade_id,
    u.sigla AS uf,
    u.nome AS estado,
    u.regiao,
    c.codigo AS codigo_cid_br10,
    c.descricao AS causa_morte,
    c.nivel AS nivel_hierarquico,
    c.tipo AS tipo_causa,
    f.periodo_inicio,
    f.periodo_fim,
    f.obitos,
    f.data_carga
FROM fato_mortalidade f
INNER JOIN dim_uf u
    ON u.uf_id = f.uf_id
INNER JOIN dim_causa_cid c
    ON c.causa_id = f.causa_id;


SELECT COUNT(*) AS total_ufs FROM dim_uf;


SELECT COUNT(*) AS total_causas FROM dim_causa_cid;


SELECT COUNT(*) AS total_registros_mortalidade FROM fato_mortalidade;


SELECT SUM(obitos) AS total_obitos FROM fato_mortalidade;


SELECT * FROM vw_mortalidade_publica WHERE ROWNUM <= 20;


SELECT
    uf,
    estado,
    regiao,
    SUM(obitos) AS total_obitos
FROM vw_mortalidade_publica
GROUP BY
    uf,
    estado,
    regiao
ORDER BY
    total_obitos DESC;


SELECT
    regiao,
    SUM(obitos) AS total_obitos
FROM vw_mortalidade_publica
GROUP BY
    regiao
ORDER BY
    total_obitos DESC;


SELECT
    codigo_cid_br10,
    causa_morte,
    SUM(obitos) AS total_obitos
FROM vw_mortalidade_publica
WHERE nivel_hierarquico = 1
GROUP BY
    codigo_cid_br10,
    causa_morte
ORDER BY
    total_obitos DESC;


SELECT *
FROM (
    SELECT
        uf,
        estado,
        codigo_cid_br10,
        causa_morte,
        SUM(obitos) AS total_obitos
    FROM vw_mortalidade_publica
    WHERE uf = 'SP'
    GROUP BY
        uf,
        estado,
        codigo_cid_br10,
        causa_morte
    ORDER BY
        SUM(obitos) DESC
)
WHERE ROWNUM <= 10;


SELECT
    uf,
    estado,
    regiao,
    codigo_cid_br10,
    causa_morte,
    obitos
FROM vw_mortalidade_publica
WHERE UPPER(causa_morte) LIKE '%TUBERCULOSE%'
ORDER BY
    obitos DESC;


SELECT
    uf,
    estado,
    regiao,
    causa_morte,
    obitos
FROM vw_mortalidade_publica
WHERE UPPER(causa_morte) LIKE '%CIRCULATÓRIO%'
   OR UPPER(causa_morte) LIKE '%CIRCULATORIO%'
ORDER BY
    obitos DESC;


SELECT
    uf,
    estado,
    regiao,
    causa_morte,
    obitos
FROM vw_mortalidade_publica
WHERE UPPER(causa_morte) LIKE '%RESPIRATÓRIO%'
   OR UPPER(causa_morte) LIKE '%RESPIRATORIO%'
ORDER BY
    obitos DESC;


SELECT
    uf,
    estado,
    SUM(obitos) AS total_obitos
FROM vw_mortalidade_publica
WHERE UPPER(causa_morte) LIKE '%DIABETES%'
GROUP BY
    uf,
    estado
ORDER BY
    total_obitos DESC;


SELECT *
FROM (
    SELECT
        regiao,
        causa_morte,
        SUM(obitos) AS total_obitos,
        ROW_NUMBER() OVER (
            PARTITION BY regiao
            ORDER BY SUM(obitos) DESC
        ) AS posicao
    FROM vw_mortalidade_publica
    WHERE nivel_hierarquico = 1
    GROUP BY
        regiao,
        causa_morte
)
WHERE posicao <= 5
ORDER BY
    regiao,
    posicao;


/* TESTES DE INTEGRIDADE */


/* Teste 1: verificar se existem fatos sem UF correspondente */
SELECT COUNT(*) AS fatos_sem_uf
FROM fato_mortalidade f
LEFT JOIN dim_uf u
    ON u.uf_id = f.uf_id
WHERE u.uf_id IS NULL;


/* Teste 2: verificar se existem fatos sem causa correspondente */
SELECT COUNT(*) AS fatos_sem_causa
FROM fato_mortalidade f
LEFT JOIN dim_causa_cid c
    ON c.causa_id = f.causa_id
WHERE c.causa_id IS NULL;


/* Teste 3: verificar se existem óbitos negativos */
SELECT COUNT(*) AS registros_com_obitos_negativos
FROM fato_mortalidade
WHERE obitos < 0;


/* Teste 4: verificar duplicidades na tabela fato */
SELECT
    uf_id,
    causa_id,
    periodo_inicio,
    periodo_fim,
    COUNT(*) AS quantidade
FROM fato_mortalidade
GROUP BY
    uf_id,
    causa_id,
    periodo_inicio,
    periodo_fim
HAVING COUNT(*) > 1;