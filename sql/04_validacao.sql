-- 04_validacao
-- Nome: Vitor Davi Pereira Soares
-- Banco: PostgreSQL 18, schema integracao.
-- Parte 4: consultas para a reunião de validação de fevereiro de 2025.
-- O roteiro que explica cada uma está em docs/parte4_validacao.md.
-- Bloco A: fechamento do mês.  Bloco B: um erro por consulta (vazio = sem erro).


-- ===================== BLOCO A: FECHAMENTO DE FEVEREIRO =====================

-- A1. Linhas no banco (comparar com a planilha: 33, 29, 20, 20, 20)
SELECT 'venda' AS tabela, COUNT(*) AS linhas FROM integracao.venda
UNION ALL SELECT 'pedido_compra',       COUNT(*) FROM integracao.pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM integracao.entradas_mercadoria
UNION ALL SELECT 'produtos_filial',     COUNT(*) FROM integracao.produtos_filial
UNION ALL SELECT 'fornecedor',          COUNT(*) FROM integracao.fornecedor;

-- A2. Vendas por mês
SELECT TO_CHAR(data_emissao, 'YYYY-MM') AS mes, COUNT(*) AS vendas
FROM integracao.venda
GROUP BY mes
ORDER BY mes;

-- A3. Total de vendas de fevereiro por filial
SELECT filial_id,
       COUNT(*)                                              AS vendas,
       ROUND(SUM(qtde_vendida * valor_unitario)::numeric, 2) AS valor_total
FROM integracao.venda
WHERE data_emissao BETWEEN '2025-02-01' AND '2025-02-28'
GROUP BY filial_id
ORDER BY filial_id;

-- A4. Vendas de fevereiro por produto (mesma consulta da Parte 2.1)
SELECT produto_id,
       SUM(qtde_vendida)                                     AS qtde_total,
       ROUND(SUM(qtde_vendida * valor_unitario)::numeric, 2) AS valor_total
FROM integracao.venda
WHERE data_emissao BETWEEN '2025-02-01' AND '2025-02-28'
GROUP BY produto_id
ORDER BY produto_id;

-- A5. Pedidos de fevereiro: quanto foi pedido e quanto foi recebido
SELECT p.pedido_id, p.produto_id, p.qtde_pedida,
       COALESCE(SUM(e.qtde_recebida), 0) AS qtde_recebida
FROM integracao.pedido_compra p
LEFT JOIN integracao.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra
WHERE p.data_pedido BETWEEN '2025-02-01' AND '2025-02-28'
GROUP BY p.pedido_id, p.produto_id, p.qtde_pedida
ORDER BY p.pedido_id;

-- A6. Notas fiscais de entrada de fevereiro
SELECT nro_nfe, data_entrada, produto_id, qtde_recebida, custo_unitario
FROM integracao.entradas_mercadoria
WHERE data_entrada BETWEEN '2025-02-01' AND '2025-02-28'
ORDER BY data_entrada;


-- ===================== BLOCO B: ERROS NOS DADOS =====================

-- B1. Venda de produto que não existe no cadastro
SELECT v.venda_id, v.produto_id, v.filial_id
FROM integracao.venda v
LEFT JOIN integracao.produtos_filial pf
       ON pf.produto_id = v.produto_id AND pf.filial_id = v.filial_id
WHERE pf.produto_id IS NULL;

-- B2. Venda em filial sem produtos cadastrados
SELECT venda_id, filial_id, produto_id
FROM integracao.venda
WHERE filial_id NOT IN (SELECT filial_id FROM integracao.produtos_filial);

-- B3. Quantidade fracionada vendida em unidade (UN)
SELECT venda_id, produto_id, qtde_vendida, unidade_medida
FROM integracao.venda
WHERE unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida);

-- B4. Preço da venda diferente do preço de venda do cadastro
SELECT v.venda_id, v.produto_id, v.valor_unitario, pf.preco_venda
FROM integracao.venda v
JOIN integracao.produtos_filial pf
  ON pf.produto_id = v.produto_id AND pf.filial_id = v.filial_id
WHERE v.valor_unitario <> pf.preco_venda;

-- B5. Vendas copiadas: mesmo preço de uma venda anterior, com outro produto
SELECT a.venda_id, a.produto_id, a.valor_unitario,
       b.venda_id AS venda_original, b.produto_id AS produto_original
FROM integracao.venda a
JOIN integracao.venda b
  ON b.valor_unitario = a.valor_unitario
 AND b.venda_id < a.venda_id
 AND b.produto_id <> a.produto_id;

-- B6. Horário e item iguais em todas as vendas
SELECT horariomov, item, COUNT(*) AS vendas
FROM integracao.venda
GROUP BY horariomov, item;

-- B7. Venda maior que o estoque cadastrado
SELECT v.venda_id, v.produto_id, v.qtde_vendida, pf.estoque
FROM integracao.venda v
JOIN integracao.produtos_filial pf
  ON pf.produto_id = v.produto_id AND pf.filial_id = v.filial_id
WHERE v.qtde_vendida > pf.estoque;

-- B8. Data de entrega anterior à data do pedido
SELECT pedido_id, produto_id, data_pedido, data_entrega
FROM integracao.pedido_compra
WHERE data_entrega < data_pedido;

-- B9. Pedido sem ordem de compra
SELECT pedido_id, produto_id, ordem_compra
FROM integracao.pedido_compra
WHERE ordem_compra = 0;

-- B10. Pedidos duplicados (mesmo produto, data e preço)
SELECT a.pedido_id, b.pedido_id AS pedido_repetido, a.produto_id, a.data_pedido
FROM integracao.pedido_compra a
JOIN integracao.pedido_compra b
  ON b.produto_id   = a.produto_id
 AND b.data_pedido  = a.data_pedido
 AND b.preco_compra = a.preco_compra
 AND b.pedido_id    > a.pedido_id;

-- B11. Fornecedor do pedido diferente do fornecedor do cadastro (1 x 'F8')
SELECT p.pedido_id, p.produto_id, p.fornecedor_id, pf.idfornecedor
FROM integracao.pedido_compra p
JOIN integracao.produtos_filial pf
  ON pf.produto_id = p.produto_id AND pf.filial_id = p.filial_id
WHERE CONCAT('F', p.fornecedor_id) <> pf.idfornecedor;

-- B12. Data de entrega preenchida, mas nada entregue
SELECT pedido_id, produto_id, data_entrega, qtde_entregue
FROM integracao.pedido_compra
WHERE data_entrega IS NOT NULL AND qtde_entregue = 0;

-- B13. Quantidade entregue no pedido diferente da recebida na nota
SELECT p.pedido_id, p.produto_id, p.qtde_entregue, e.qtde_recebida
FROM integracao.pedido_compra p
JOIN integracao.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra
WHERE p.qtde_entregue <> e.qtde_recebida;

-- B14. Nota fiscal sem pedido de compra
SELECT e.nro_nfe, e.ordem_compra, e.produto_id
FROM integracao.entradas_mercadoria e
LEFT JOIN integracao.pedido_compra p ON p.ordem_compra = e.ordem_compra
WHERE p.pedido_id IS NULL;

-- B15. Quantidade recebida maior que a pedida
SELECT e.nro_nfe, e.produto_id, p.qtde_pedida, e.qtde_recebida
FROM integracao.entradas_mercadoria e
JOIN integracao.pedido_compra p ON p.ordem_compra = e.ordem_compra
WHERE e.qtde_recebida > p.qtde_pedida;

-- B16. Mercadoria recebida antes de ser pedida
SELECT e.nro_nfe, e.produto_id, p.data_pedido, e.data_entrada
FROM integracao.entradas_mercadoria e
JOIN integracao.pedido_compra p ON p.ordem_compra = e.ordem_compra
WHERE e.data_entrada < p.data_pedido;

-- B17. Custo na nota diferente do preço de compra do pedido
SELECT e.nro_nfe, e.produto_id, p.preco_compra, e.custo_unitario
FROM integracao.entradas_mercadoria e
JOIN integracao.pedido_compra p ON p.ordem_compra = e.ordem_compra
WHERE e.custo_unitario <> p.preco_compra;

-- B18. Preço de compra maior que o preço de venda
SELECT produto_id, preco_compra, preco_venda
FROM integracao.produtos_filial
WHERE preco_compra > preco_venda;

-- B19. Preço de compra do cadastro diferente do preço do pedido
SELECT p.pedido_id, p.produto_id, p.preco_compra, pf.preco_compra AS preco_cadastro
FROM integracao.pedido_compra p
JOIN integracao.produtos_filial pf
  ON pf.produto_id = p.produto_id AND pf.filial_id = p.filial_id
WHERE p.preco_compra <> pf.preco_compra;

-- B20. Produto com fornecedor que não existe no cadastro
SELECT pf.produto_id, pf.idfornecedor
FROM integracao.produtos_filial pf
LEFT JOIN integracao.fornecedor f ON f.idfornecedor = pf.idfornecedor
WHERE f.idfornecedor IS NULL;

-- B21. Fornecedores com mais de um produto ou sem nenhum produto
SELECT f.idfornecedor, COUNT(pf.produto_id) AS produtos
FROM integracao.fornecedor f
LEFT JOIN integracao.produtos_filial pf ON pf.idfornecedor = f.idfornecedor
GROUP BY f.idfornecedor
HAVING COUNT(pf.produto_id) <> 1;
