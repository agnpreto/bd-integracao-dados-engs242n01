-- 02_consultas
-- Nome: Equipe CoreData (Ana Júlia Pantoja Chagas e Rafaela da Silva Tavares)
-- Parte 2: Consultas SQL Básicas (PostgreSQL)

-- ---------------------------------------------------------------------
-- 2.1 Consumo por produto e mês: total vendido em quantidade e em R$
--     por produto no mês de fevereiro de 2025.
-- ---------------------------------------------------------------------
SELECT
    v.produto_id,
    COALESCE(
        MAX(pf.descricao),
        'Produto sem cadastro'
    ) AS descricao_produto,
    SUM(v.qtde_vendida) AS qtde_total_vendida,
    SUM(
        v.qtde_vendida * v.valor_unitario
    ) AS valor_total_rs
FROM public.venda v
    LEFT JOIN public.produtos_filial pf ON pf.produto_id = v.produto_id
    AND pf.filial_id = v.filial_id
WHERE
    v.data_emissao >= DATE '2025-02-01'
    AND v.data_emissao < DATE '2025-03-01'
GROUP BY
    v.produto_id
ORDER BY valor_total_rs DESC, v.produto_id;

-- ---------------------------------------------------------------------
-- 2.2 Produtos com requisição pendente: produtos requisitados em
--     pedido_compra mas não recebidos em entradas_mercadoria.
--     Ligação entre pedido_compra e entradas_mercadoria via ordem_compra.
-- ---------------------------------------------------------------------
SELECT pc.pedido_id, pc.ordem_compra, pc.produto_id, pc.descricao_produto, pc.qtde_pedida, pc.qtde_entregue, pc.qtde_pendente, pc.data_pedido
FROM public.pedido_compra pc
    LEFT JOIN public.entradas_mercadoria em ON em.ordem_compra = pc.ordem_compra
    AND em.produto_id = pc.produto_id
WHERE
    em.ordem_compra IS NULL
    OR pc.qtde_pendente > 0
ORDER BY pc.pedido_id, pc.produto_id;