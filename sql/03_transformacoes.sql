-- =====================================================================
-- PARTE 3 - TRANSFORMAÇÕES DE DADOS
-- Disciplina: Banco de Dados (ENGS242N01)
-- Os comandos abaixo são para PostgreSQL. Onde o MySQL é diferente (formato de
-- data e trigger), a versão MySQL aparece logo depois, dentro de comentário.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 3.1 e 3.2  Concatenar produto_id + descricao_produto  ->  "12345 - Detergente"
--            e mostrar as datas como DD/MM/YYYY
--
-- CONCAT_WS(' - ', a, b) junta os textos com " - " e ignora o que for NULL, então
-- quando não há descrição sai só o código (sem sobrar " - " no fim). O NULLIF
-- trata também o caso da descrição vazia ('') ou só com espaços.
-- ---------------------------------------------------------------------

-- a) Pedidos de compra
SELECT  CONCAT_WS(' - ', p.produto_id, NULLIF(TRIM(p.descricao_produto), '')) AS "Produto",
        p.qtde_pedida                                                           AS "Qtde Requisitada",
        TO_CHAR(p.data_pedido, 'DD/MM/YYYY')                                    AS "Data Solicitação",
        TO_CHAR(p.data_entrega, 'DD/MM/YYYY')                                   AS "Data Entrega"
FROM    pedido_compra p
ORDER BY p.data_pedido, p.pedido_id;

-- b) Vendas (a descrição vem de produtos_filial; LEFT JOIN para não perder
--    as vendas de produtos que não estão no cadastro)
SELECT  CONCAT_WS(' - ', v.produto_id, NULLIF(TRIM(pf.descricao), ''))  AS "Produto",
        v.qtde_vendida                                                  AS "Qtde Vendida",
        TO_CHAR(v.data_emissao, 'DD/MM/YYYY')                           AS "Data Emissão"
FROM    venda v
LEFT JOIN produtos_filial pf
       ON pf.produto_id = v.produto_id AND pf.filial_id = v.filial_id
ORDER BY v.data_emissao, v.venda_id;

-- c) Produtos
SELECT  CONCAT_WS(' - ', produto_id, NULLIF(TRIM(descricao), '')) AS "Produto",
        filial_id                                                  AS "Filial",
        estoque                                                    AS "Estoque"
FROM    produtos_filial
ORDER BY filial_id, produto_id;

/* Versão MySQL das datas (o resto da sintaxe acima funciona igual):
     DATE_FORMAT(p.data_pedido, '%d/%m/%Y')
*/


-- ---------------------------------------------------------------------
-- 3.3  Só os produtos "requisitados mais de 10 vezes no período"
--
-- COMO EU INTERPRETEI "mais de 10 vezes":
--   A frase é ambígua. Dá para ler de dois jeitos:
--     (A) mais de 10 requisições  = mais de 10 linhas de pedido do produto;
--     (B) mais de 10 unidades requisitadas = soma de qtde_pedida do produto > 10.
--   Adotei (B). Motivos: (1) o exemplo do enunciado mostra a coluna "Qtde
--   Requisitada" = 15 para um único dia (01/01/2025), ou seja, "15" é uma
--   quantidade e não a contagem de pedidos; (2) na base do cliente nenhum produto
--   tem mais de 2 pedidos, então a leitura (A) devolveria sempre zero linhas
--   (a consulta de prova está logo abaixo) e não serviria para nada.
--   O "período" é o dos dados: 01/01/2025 a 31/03/2025 (altere em "parametros").
--   A soma é feita por produto no período inteiro e o resultado mostra a
--   quantidade requisitada por produto em cada data de solicitação.
--   Nesta base, todos os 20 produtos passam no filtro (o menor total é 12), então
--   o resultado traz os 20. Se o cliente quiser filtrar cada pedido individual
--   (qtde_pedida > 10 na linha), basta trocar "t.qtde_total > 10" por "r.qtde_dia > 10".
-- ---------------------------------------------------------------------
WITH parametros AS (
    SELECT DATE '2025-01-01' AS data_ini, DATE '2025-03-31' AS data_fim
),
requisicoes AS (
    SELECT  p.produto_id,
            MAX(p.descricao_produto)  AS descricao_produto,
            p.data_pedido,
            SUM(p.qtde_pedida)        AS qtde_dia
    FROM    pedido_compra p, parametros x
    WHERE   p.data_pedido BETWEEN x.data_ini AND x.data_fim
    GROUP BY p.produto_id, p.data_pedido
),
total_no_periodo AS (
    SELECT produto_id, SUM(qtde_dia) AS qtde_total
    FROM   requisicoes
    GROUP BY produto_id
)
SELECT  CONCAT_WS(' - ', r.produto_id, NULLIF(TRIM(r.descricao_produto), '')) AS "Produto",
        r.qtde_dia                                                              AS "Qtde Requisitada",
        TO_CHAR(r.data_pedido, 'DD/MM/YYYY')                                    AS "Data Solicitação",
        t.qtde_total                                                            AS "Total no Período"
FROM    requisicoes r
JOIN    total_no_periodo t ON t.produto_id = r.produto_id
WHERE   t.qtde_total > 10
ORDER BY r.data_pedido, r.produto_id;

-- Prova de que a leitura (A) não serve: produtos com mais de 10 PEDIDOS.
-- Resultado esperado: 0 linhas (o máximo de pedidos de um mesmo produto é 2).
SELECT  produto_id, COUNT(*) AS qtd_pedidos
FROM    pedido_compra
GROUP BY produto_id
HAVING  COUNT(*) > 10;


-- ---------------------------------------------------------------------
-- 3.4  TRIGGER: gerar automaticamente um novo idfornecedor numérico em
--      produtos_filial, ligado à tabela fornecedor
--
-- Como funciona: quando um produto é cadastrado (ou atualizado) SEM fornecedor
-- (idfornecedor NULL), a trigger cria um fornecedor novo na tabela fornecedor
-- (id numérico gerado pela sequência da própria tabela, razão social provisória
-- "A DEFINIR - produto X") e coloca esse id no produto. Assim o produto nasce
-- sempre ligado a um fornecedor existente (a FK fica satisfeita) e o cadastro
-- completo do fornecedor pode ser feito depois. Se o idfornecedor já vier
-- preenchido, a trigger não mexe em nada.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_gera_idfornecedor()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    novo_id int;
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO fornecedor (razao_social)
        VALUES ('A DEFINIR - produto ' || NEW.produto_id || ' (filial ' || NEW.filial_id || ')')
        RETURNING idfornecedor INTO novo_id;

        NEW.idfornecedor := novo_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gera_idfornecedor ON produtos_filial;
CREATE TRIGGER trg_gera_idfornecedor
    BEFORE INSERT OR UPDATE OF idfornecedor ON produtos_filial
    FOR EACH ROW
    EXECUTE FUNCTION fn_gera_idfornecedor();

-- Teste da trigger (dentro de uma transação que é desfeita no fim, para não
-- sujar a base; por isso o próximo id da sequência "pula" um número, o que é normal).
BEGIN;
    -- 1) produto SEM fornecedor: a trigger cria o fornecedor e preenche o id
    INSERT INTO produtos_filial (filial_id, produto_id, descricao, idfornecedor)
    VALUES (1, 'P99', 'Produto de teste da trigger', NULL);

    -- 2) produto COM fornecedor já existente: nada muda
    INSERT INTO produtos_filial (filial_id, produto_id, descricao, idfornecedor)
    VALUES (1, 'P98', 'Produto de teste com fornecedor', 5);

    SELECT  p.produto_id, p.idfornecedor, f.razao_social
    FROM    produtos_filial p
    JOIN    fornecedor f ON f.idfornecedor = p.idfornecedor
    WHERE   p.produto_id IN ('P99', 'P98')
    ORDER BY p.produto_id;
    -- Esperado numa base recém-importada: P98 -> 5 (Fornecedor 5 LTDA) e
    -- P99 -> 21 (A DEFINIR - produto P99 (filial 1)). Se a sequência já tiver sido
    -- usada antes, o número do P99 será maior que 21.
ROLLBACK;

/* Versão MySQL da trigger (rodar no cliente com DELIMITER). Cobre só o INSERT,
   porque o MySQL não tem "UPDATE OF coluna". Testada em MariaDB 10.11:

DELIMITER $$
CREATE TRIGGER trg_gera_idfornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO fornecedor (razao_social)
        VALUES (CONCAT('A DEFINIR - produto ', NEW.produto_id, ' (filial ', NEW.filial_id, ')'));
        SET NEW.idfornecedor = LAST_INSERT_ID();
    END IF;
END$$
DELIMITER ;
*/
