-- 02_consultas
-- Nome: Vitor Davi Pereira Soares
-- Banco: PostgreSQL 18, schema integracao.
-- Parte 2: consultas SQL básicas.


-- 2.1 Total vendido por produto em fevereiro de 2025 (quantidade e R$)
SELECT produto_id,
       SUM(qtde_vendida)                                     AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario)::numeric, 2) AS valor_total
FROM integracao.venda
WHERE data_emissao BETWEEN '2025-02-01' AND '2025-02-28'
GROUP BY produto_id
ORDER BY produto_id;


-- 2.2 Produtos requisitados e não recebidos
-- A entrada se liga ao pedido pela ordem_compra (regra do enunciado).
-- Pedido sem nenhuma entrada com a mesma ordem_compra = não recebido.
SELECT p.pedido_id, p.produto_id, p.descricao_produto, p.qtde_pedida
FROM integracao.pedido_compra p
LEFT JOIN integracao.entradas_mercadoria e
       ON e.ordem_compra = p.ordem_compra
WHERE e.ordem_compra IS NULL
ORDER BY p.pedido_id;
