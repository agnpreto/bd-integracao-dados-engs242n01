-- 04_validacao
-- Nome: Merivaldo Ferreira de Aquino Filho
-- Consultas de apoio à reunião de validação de fevereiro/2025
USE loja_integracao;

-- 1) Conferência de volume: planilha x banco (20, 20, 33, 29, 20).
SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas FROM fornecedor
UNION ALL SELECT 'produtos_filial', COUNT(*) FROM produtos_filial
UNION ALL SELECT 'venda', COUNT(*) FROM venda
UNION ALL SELECT 'pedido_compra', COUNT(*) FROM pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM entradas_mercadoria;

-- 2) Total de vendas em fevereiro/2025 (173,22 unidades / R$ 14.093,17).
SELECT
    COUNT(*) AS vendas,
    SUM(qtde_vendida) AS qtde_total,
    ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_total
FROM venda
WHERE data_emissao >= '2025-02-01'
  AND data_emissao <  '2025-03-01';

-- 3) ERRO: data de entrega anterior à data do pedido (20 registros).
SELECT pedido_id, ordem_compra, produto_id, data_pedido, data_entrega
FROM pedido_compra
WHERE data_entrega < data_pedido
ORDER BY pedido_id;

-- 4) ERRO: pedidos sem ordem de compra (ordem_compra = 0) — 11 registros.
SELECT COUNT(*) AS pedidos_sem_ordem
FROM pedido_compra
WHERE ordem_compra IS NULL OR ordem_compra = 0;

-- 5) ERRO: entradas de mercadoria sem pedido correspondente (2 registros:
--    ordens 19 e 20).
SELECT em.ordem_compra, em.produto_id, em.qtde_recebida, em.nro_nfe, em.data_entrada
FROM entradas_mercadoria em
LEFT JOIN pedido_compra pc ON pc.ordem_compra = em.ordem_compra
WHERE pc.ordem_compra IS NULL;

-- 6) ERRO: preço de venda menor que preço de compra (4 produtos).
SELECT produto_id, descricao, preco_compra, preco_venda
FROM produtos_filial
WHERE preco_venda < preco_compra;

-- 7) ERRO: vendas de produtos sem cadastro em produtos_filial
--    (13 linhas, códigos P21 a P28).
SELECT v.produto_id, COUNT(*) AS vendas_sem_cadastro, SUM(v.qtde_vendida) AS qtde
FROM venda v
LEFT JOIN produtos_filial pf ON pf.produto_id = v.produto_id
WHERE pf.produto_id IS NULL
GROUP BY v.produto_id
ORDER BY v.produto_id;

-- 8) Conferência: quantidade entregue maior que a pedida e pedidos duplicados
--    (resultado esperado: zero nas duas consultas).
SELECT COUNT(*) AS entregue_maior_que_pedido
FROM pedido_compra
WHERE qtde_entregue > qtde_pedida;

SELECT pedido_id, produto_id, item, COUNT(*) AS duplicatas
FROM pedido_compra
GROUP BY pedido_id, produto_id, item
HAVING COUNT(*) > 1;
