-- 02_consultas
-- Nome: Merivaldo Ferreira de Aquino Filho
-- Parte 2: Consultas SQL básicas
USE loja_integracao;

-- 1) Consumo por produto e mês: total de vendas em quantidade e em R$ por produto
--    no mês de fevereiro/2025.
--    Conferência: 14 vendas, 173,22 unidades e R$ 14.093,17 no total do mês.
SELECT
    v.produto_id,
    pf.descricao,
    SUM(v.qtde_vendida) AS quantidade_vendida,
    ROUND(SUM(v.qtde_vendida * v.valor_unitario), 2) AS valor_total_reais
FROM venda v
LEFT JOIN (
    SELECT produto_id, MIN(descricao) AS descricao
    FROM produtos_filial
    GROUP BY produto_id
) pf ON pf.produto_id = v.produto_id
WHERE v.data_emissao >= '2025-02-01'
  AND v.data_emissao <  '2025-03-01'
GROUP BY v.produto_id, pf.descricao
ORDER BY valor_total_reais DESC;

-- 2) Produtos requisitados, mas não recebidos.
--    Critério: pedido sem quantidade entregue OU sem entrada de mercadoria
--    vinculada pelo campo ordem_compra.
SELECT
    pc.produto_id,
    pf.descricao,
    SUM(pc.qtde_pedida) AS qtde_requisitada,
    SUM(COALESCE(pc.qtde_entregue, 0)) AS qtde_recebida,
    SUM(pc.qtde_pedida - COALESCE(pc.qtde_entregue, 0)) AS qtde_pendente
FROM pedido_compra pc
LEFT JOIN (
    SELECT produto_id, MIN(descricao) AS descricao
    FROM produtos_filial
    GROUP BY produto_id
) pf ON pf.produto_id = pc.produto_id
WHERE COALESCE(pc.qtde_entregue, 0) = 0
   OR NOT EXISTS (
        SELECT 1
        FROM entradas_mercadoria em
        WHERE em.ordem_compra = pc.ordem_compra
   )
GROUP BY pc.produto_id, pf.descricao
HAVING SUM(pc.qtde_pedida) > SUM(COALESCE(pc.qtde_entregue, 0))
ORDER BY qtde_pendente DESC;

-- 2b) Detalhe por pedido, para conferir cada pendência na reunião com o cliente.
SELECT
    pc.ordem_compra,
    pc.produto_id,
    pc.qtde_pedida,
    COALESCE(pc.qtde_entregue, 0) AS qtde_entregue,
    DATE_FORMAT(pc.data_pedido, '%d/%m/%Y') AS data_pedido
FROM pedido_compra pc
WHERE COALESCE(pc.qtde_entregue, 0) = 0
ORDER BY pc.ordem_compra, pc.produto_id;
