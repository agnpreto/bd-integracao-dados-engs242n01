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
-- Critério: a soma recebida nas notas fiscais com a mesma ordem_compra é menor
-- que a quantidade pedida. Entram os pedidos sem nenhum recebimento e os
-- recebidos só em parte; a coluna qtde_nao_recebida mostra quanto falta.
-- Observação: os pedidos 19 e 20 estão com ordem_compra = 0 e aparecem como não
-- recebidos, mas existem as notas NFE19 e NFE20 com ordem 19 e 20 para os mesmos
-- produtos. É um erro nos dados, tratado na Parte 4 (consultas B9 e B14).
SELECT p.pedido_id,
       p.produto_id,
       p.descricao_produto,
       p.qtde_pedida,
       COALESCE(e.qtde_recebida, 0)                 AS qtde_recebida,
       p.qtde_pedida - COALESCE(e.qtde_recebida, 0) AS qtde_nao_recebida
FROM integracao.pedido_compra p
LEFT JOIN (SELECT ordem_compra, SUM(qtde_recebida) AS qtde_recebida
             FROM integracao.entradas_mercadoria
            GROUP BY ordem_compra) e
       ON e.ordem_compra = p.ordem_compra
WHERE COALESCE(e.qtde_recebida, 0) < p.qtde_pedida
ORDER BY p.pedido_id;
