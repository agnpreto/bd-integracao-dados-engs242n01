-- =====================================================================
-- PARTE 2 - CONSULTAS SQL BÁSICAS
-- Disciplina: Banco de Dados (ENGS242N01)
-- Testado em PostgreSQL 16 e MariaDB 10.11 (compatível com MySQL 8): a sintaxe
-- usada aqui é a mesma nos dois, sem nada específico de um SGBD.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 2.1  Total vendido, em quantidade e em R$, por produto, em fevereiro/2025
--
-- Regras adotadas:
--  * Valor em R$ = qtde_vendida * valor_unitario de cada linha, somado por produto
--    (somar primeiro o preço e depois multiplicar daria o valor errado).
--  * O filtro de data usa  >= 01/02  e  < 01/03: pega o mês inteiro e continua
--    certo mesmo que a coluna venha a ter hora no futuro.
--  * Agrupa só por produto_id (as filiais 2 e 3 também entram no total do produto).
--  * A descrição vem de produtos_filial com LEFT JOIN, porque 8 produtos vendidos
--    (P21 a P28) não existem nesse cadastro; com INNER JOIN eles sumiriam do total.
-- ---------------------------------------------------------------------
WITH vendas_fev AS (
    SELECT  produto_id,
            COUNT(*)                         AS qtd_linhas_venda,
            SUM(qtde_vendida)                AS qtde_total,
            SUM(qtde_vendida * valor_unitario) AS valor_total
    FROM    venda
    WHERE   data_emissao >= DATE '2025-02-01'
      AND   data_emissao <  DATE '2025-03-01'
    GROUP BY produto_id
),
descricao_produto AS (
    SELECT produto_id, MIN(descricao) AS descricao
    FROM   produtos_filial
    GROUP BY produto_id
)
SELECT  v.produto_id,
        COALESCE(d.descricao, '(sem cadastro em produtos_filial)') AS descricao,
        v.qtd_linhas_venda,
        v.qtde_total                      AS qtde_vendida_total,
        ROUND(v.valor_total, 2)           AS valor_vendido_rs
FROM    vendas_fev v
LEFT JOIN descricao_produto d ON d.produto_id = v.produto_id
ORDER BY v.valor_total DESC, v.produto_id;

-- Conferência do 2.1: soma geral de fevereiro (deve bater com a soma da consulta acima)
SELECT  COUNT(*)                                   AS linhas_fev,
        COUNT(DISTINCT produto_id)                 AS produtos_vendidos,
        SUM(qtde_vendida)                          AS qtde_total,
        ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_total_rs
FROM    venda
WHERE   data_emissao >= DATE '2025-02-01'
  AND   data_emissao <  DATE '2025-03-01';


-- ---------------------------------------------------------------------
-- 2.2  Produtos requisitados (pedido_compra) e NÃO recebidos (entradas_mercadoria)
--
-- O enunciado diz que a entrada se liga ao pedido pelo campo ordem_compra.
-- Um item do pedido é "não recebido" quando NÃO existe nenhuma entrada com a
-- mesma ordem_compra (e o mesmo produto e filial).
--
-- Atenção ao ordem_compra = 0: significa "pedido sem ordem de compra", então
-- nunca casa com nenhuma entrada e aparece como não recebido. É o caso dos
-- pedidos 19 a 29. Os pedidos 19 e 20 merecem conferência com o cliente: existem
-- entradas (NFE19 e NFE20) para as ordens 19 e 20, mas esses dois pedidos estão
-- com ordem_compra = 0 na planilha (provável erro de digitação).
-- ---------------------------------------------------------------------
SELECT  p.pedido_id,
        p.produto_id,
        p.descricao_produto,
        p.filial_id,
        p.data_pedido,
        p.ordem_compra,
        p.qtde_pedida,
        CASE WHEN p.ordem_compra = 0
             THEN 'Pedido sem ordem de compra'
             ELSE 'Ordem de compra sem nenhuma entrada'
        END AS motivo
FROM    pedido_compra p
WHERE   NOT EXISTS (
            SELECT 1
            FROM   entradas_mercadoria e
            WHERE  e.ordem_compra = p.ordem_compra
              AND  e.produto_id   = p.produto_id
              AND  e.filial_id    = p.filial_id
        )
ORDER BY p.pedido_id;

-- 2.2 (complemento) Recebimento PARCIAL: tem entrada, mas a soma recebida é menor
-- que a quantidade pedida. Fica separado para não misturar "não recebido" (nada
-- chegou) com "recebido a menos".
SELECT  p.pedido_id,
        p.produto_id,
        p.ordem_compra,
        p.qtde_pedida,
        r.qtde_recebida_total,
        p.qtde_pedida - r.qtde_recebida_total AS faltou_receber
FROM    pedido_compra p
JOIN (  SELECT ordem_compra, produto_id, filial_id, SUM(qtde_recebida) AS qtde_recebida_total
        FROM   entradas_mercadoria
        GROUP BY ordem_compra, produto_id, filial_id
     ) r ON  r.ordem_compra = p.ordem_compra
         AND r.produto_id   = p.produto_id
         AND r.filial_id    = p.filial_id
WHERE   r.qtde_recebida_total < p.qtde_pedida
ORDER BY p.pedido_id;
