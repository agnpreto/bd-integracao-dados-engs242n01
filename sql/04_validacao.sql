-- =====================================================================
-- PARTE 4 - CONSULTAS PRONTAS PARA A REUNIÃO DE VALIDAÇÃO (fevereiro/2025)
-- Disciplina: Banco de Dados (ENGS242N01)
-- Roteiro e explicações: docs/parte4_validacao.md
-- Sintaxe comum ao PostgreSQL e ao MySQL (testado nos dois).
--
-- Organização:
--   BLOCO A  totais de fevereiro para o cliente conferir com o sistema dele
--   BLOCO B  conferência da importação (linhas no banco x linhas na planilha)
--   BLOCO C  erros encontrados nos dados (E01 a E18), um por consulta
--   BLOCO D  resumo de todos os erros em uma tabela só
-- =====================================================================


-- =====================================================================
-- BLOCO A - TOTAIS DE FEVEREIRO/2025 (o cliente compara com o ERP dele)
-- =====================================================================

-- A1. Vendas de fevereiro: quantidade de linhas, quantidade vendida e valor, por filial
SELECT  filial_id,
        COUNT(*)                                       AS linhas,
        COUNT(DISTINCT venda_id)                       AS vendas,
        SUM(qtde_vendida)                              AS qtde_vendida,
        ROUND(SUM(qtde_vendida * valor_unitario), 2)   AS valor_rs
FROM    venda
WHERE   data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01'
GROUP BY filial_id
ORDER BY filial_id;

-- A2. Vendas de fevereiro dia a dia (o cliente confere dia por dia contra o caixa)
SELECT  data_emissao,
        COUNT(*)                                       AS linhas,
        ROUND(SUM(qtde_vendida * valor_unitario), 2)   AS valor_rs
FROM    venda
WHERE   data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01'
GROUP BY data_emissao
ORDER BY data_emissao;

-- A3. Pedidos de compra feitos em fevereiro: quantidade e valor (qtde x preço de compra)
SELECT  COUNT(*)                                       AS linhas,
        SUM(qtde_pedida)                               AS qtde_pedida,
        SUM(qtde_entregue)                             AS qtde_entregue_segundo_pedido,
        ROUND(SUM(qtde_pedida * preco_compra), 2)      AS valor_pedido_rs
FROM    pedido_compra
WHERE   data_pedido >= DATE '2025-02-01' AND data_pedido < DATE '2025-03-01';

-- A4. Entradas de mercadoria de fevereiro: quantidade e valor (qtde x custo)
SELECT  COUNT(*)                                       AS notas_item,
        COUNT(DISTINCT nro_nfe)                        AS notas_fiscais,
        SUM(qtde_recebida)                             AS qtde_recebida,
        ROUND(SUM(qtde_recebida * custo_unitario), 2)  AS valor_entrada_rs
FROM    entradas_mercadoria
WHERE   data_entrada >= DATE '2025-02-01' AND data_entrada < DATE '2025-03-01';

-- A5. Pedidos de fevereiro ainda sem nenhuma entrada (lista para o cliente confirmar
--     se a mercadoria realmente não chegou). Mesma regra da consulta 2.2.
SELECT  p.pedido_id, p.produto_id, p.data_pedido, p.ordem_compra, p.qtde_pedida
FROM    pedido_compra p
WHERE   p.data_pedido >= DATE '2025-02-01' AND p.data_pedido < DATE '2025-03-01'
  AND   NOT EXISTS (SELECT 1 FROM entradas_mercadoria e
                    WHERE e.ordem_compra = p.ordem_compra
                      AND e.produto_id   = p.produto_id
                      AND e.filial_id    = p.filial_id)
ORDER BY p.pedido_id;


-- =====================================================================
-- BLOCO B - CONFERÊNCIA DA IMPORTAÇÃO
-- Valores esperados (contagem das abas da planilha): fornecedor 20,
-- produtos_filial 20, pedido_compra 29, entradas_mercadoria 20, venda 33.
-- =====================================================================
-- B1. Linhas no banco x linhas na planilha
SELECT 'fornecedor'          AS tabela, 20 AS linhas_na_planilha, COUNT(*) AS linhas_no_banco FROM fornecedor
UNION ALL
SELECT 'produtos_filial',               20,                       COUNT(*) FROM produtos_filial
UNION ALL
SELECT 'pedido_compra',                 29,                       COUNT(*) FROM pedido_compra
UNION ALL
SELECT 'entradas_mercadoria',           20,                       COUNT(*) FROM entradas_mercadoria
UNION ALL
SELECT 'venda',                         33,                       COUNT(*) FROM venda;

-- B2. Nenhuma data pode ter ficado vazia na importação (o script antigo gravava NULL)
SELECT 'pedido_compra.data_pedido'      AS campo, COUNT(*) AS datas_vazias FROM pedido_compra       WHERE data_pedido  IS NULL
UNION ALL
SELECT 'entradas_mercadoria.data_entrada',          COUNT(*)               FROM entradas_mercadoria  WHERE data_entrada IS NULL
UNION ALL
SELECT 'venda.data_emissao',                        COUNT(*)               FROM venda                WHERE data_emissao IS NULL;


-- =====================================================================
-- BLOCO C - ERROS ENCONTRADOS NOS DADOS
-- Cada consulta lista as linhas com problema. "ERRO" = não pode acontecer;
-- "CONFIRMAR" = pode ter explicação de negócio e depende do cliente.
-- =====================================================================

-- E01 [ERRO] venda de produto que não existe em produtos_filial (produtos P21 a P28)
SELECT  v.venda_id, v.data_emissao, v.produto_id, v.filial_id, v.qtde_vendida, v.valor_unitario
FROM    venda v
WHERE   NOT EXISTS (SELECT 1 FROM produtos_filial p
                    WHERE p.produto_id = v.produto_id AND p.filial_id = v.filial_id)
ORDER BY v.venda_id;

-- E02 [ERRO] vendas em filiais (2 e 3) que não existem em produtos_filial
SELECT  v.filial_id, COUNT(*) AS linhas_de_venda
FROM    venda v
WHERE   NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.filial_id = v.filial_id)
GROUP BY v.filial_id
ORDER BY v.filial_id;

-- E03 [ERRO] quantidade fracionada em produto vendido em unidade "UN"
SELECT  venda_id, data_emissao, produto_id, qtde_vendida, unidade_medida
FROM    venda
WHERE   unidade_medida = 'UN'
  AND   qtde_vendida <> FLOOR(qtde_vendida)
ORDER BY venda_id;

-- E04 [CONFIRMAR] mesmo valor unitário em produtos diferentes (sinal de linhas copiadas:
--      P21 a P28 repetem exatamente os preços de P13 a P20)
SELECT  v.valor_unitario, v.produto_id, v.venda_id, v.data_emissao
FROM    venda v
WHERE   v.valor_unitario IN (SELECT valor_unitario
                             FROM   venda
                             GROUP BY valor_unitario
                             HAVING COUNT(DISTINCT produto_id) > 1)
ORDER BY v.valor_unitario, v.produto_id, v.venda_id;

-- E05 [CONFIRMAR] horário da venda igual em todas as linhas (08:00:00 parece valor padrão)
SELECT  horariomov, COUNT(*) AS linhas
FROM    venda
GROUP BY horariomov;

-- E06 [ERRO] pedido de compra sem ordem de compra (ordem_compra = 0): não dá para ligar à entrada
SELECT  pedido_id, produto_id, data_pedido, ordem_compra, qtde_pedida, qtde_entregue
FROM    pedido_compra
WHERE   ordem_compra = 0
ORDER BY pedido_id;

-- E07 [ERRO] pedidos duplicados: mesmo produto, filial, datas e preço (pedidos 21 a 29
--      repetem os pedidos 12 a 20, mas com ordem_compra 0 e quantidade diferente)
SELECT  a.pedido_id AS pedido_original, b.pedido_id AS pedido_repetido, a.produto_id,
        a.data_pedido, a.data_entrega, a.preco_compra,
        a.qtde_pedida AS qtde_original, b.qtde_pedida AS qtde_repetido
FROM    pedido_compra a
JOIN    pedido_compra b
        ON  b.produto_id   = a.produto_id
        AND b.filial_id    = a.filial_id
        AND b.data_pedido  = a.data_pedido
        AND b.data_entrega = a.data_entrega
        AND b.preco_compra = a.preco_compra
        AND b.pedido_id    > a.pedido_id
ORDER BY a.pedido_id;

-- E08 [ERRO] data de entrega anterior à data do pedido
SELECT  pedido_id, produto_id, data_pedido, data_entrega
FROM    pedido_compra
WHERE   data_entrega < data_pedido
ORDER BY pedido_id;

-- E09 [ERRO] entrada de mercadoria cuja ordem_compra não existe em nenhum pedido
--      (NFE19 e NFE20 apontam para as ordens 19 e 20, mas esses pedidos estão com ordem 0)
SELECT  e.nro_nfe, e.data_entrada, e.ordem_compra, e.produto_id, e.qtde_recebida
FROM    entradas_mercadoria e
WHERE   NOT EXISTS (SELECT 1 FROM pedido_compra p WHERE p.ordem_compra = e.ordem_compra)
ORDER BY e.nro_nfe;

-- E10 [ERRO] mercadoria recebida ANTES de o pedido ser feito
SELECT  e.nro_nfe, e.produto_id, p.pedido_id, p.data_pedido, e.data_entrada
FROM    entradas_mercadoria e
JOIN    pedido_compra p ON p.ordem_compra = e.ordem_compra
                       AND p.produto_id   = e.produto_id
                       AND p.filial_id    = e.filial_id
WHERE   e.data_entrada < p.data_pedido
ORDER BY p.pedido_id;

-- E11 [ERRO] recebeu mais do que foi pedido
SELECT  e.nro_nfe, e.produto_id, p.pedido_id, p.qtde_pedida, e.qtde_recebida,
        (e.qtde_recebida - p.qtde_pedida) AS excesso
FROM    entradas_mercadoria e
JOIN    pedido_compra p ON p.ordem_compra = e.ordem_compra
                       AND p.produto_id   = e.produto_id
                       AND p.filial_id    = e.filial_id
WHERE   e.qtde_recebida > p.qtde_pedida
ORDER BY p.pedido_id;

-- E12 [ERRO] quantidade entregue no pedido diferente da quantidade recebida na entrada
SELECT  p.pedido_id, p.produto_id, p.qtde_entregue AS entregue_no_pedido,
        e.qtde_recebida AS recebido_na_entrada, e.nro_nfe
FROM    pedido_compra p
JOIN    entradas_mercadoria e ON e.ordem_compra = p.ordem_compra
                             AND e.produto_id   = p.produto_id
                             AND e.filial_id    = p.filial_id
WHERE   p.qtde_entregue <> e.qtde_recebida
ORDER BY p.pedido_id;

-- E13 [CONFIRMAR] custo da entrada diferente do preço de compra do pedido
SELECT  p.pedido_id, p.produto_id, p.preco_compra AS preco_no_pedido,
        e.custo_unitario AS custo_na_entrada, e.nro_nfe
FROM    pedido_compra p
JOIN    entradas_mercadoria e ON e.ordem_compra = p.ordem_compra
                             AND e.produto_id   = p.produto_id
                             AND e.filial_id    = p.filial_id
WHERE   p.preco_compra <> e.custo_unitario
ORDER BY p.pedido_id;

-- E14 [ERRO] fornecedor do pedido diferente do fornecedor cadastrado no produto
SELECT  p.pedido_id, p.produto_id, p.fornecedor_id AS fornecedor_no_pedido,
        pf.idfornecedor AS fornecedor_no_produto
FROM    pedido_compra p
JOIN    produtos_filial pf ON pf.produto_id = p.produto_id AND pf.filial_id = p.filial_id
WHERE   p.fornecedor_id <> pf.idfornecedor
ORDER BY p.pedido_id;

-- E15 [ERRO] preço de venda menor que o preço de compra (prejuízo em cada unidade)
SELECT  filial_id, produto_id, preco_compra, preco_venda,
        (preco_venda - preco_compra) AS margem_por_unidade
FROM    produtos_filial
WHERE   preco_venda < preco_compra
ORDER BY margem_por_unidade;

-- E16 [CONFIRMAR] preco_unitario não bate com preço de compra nem com preço de venda
--      (a coluna não tem significado definido: perguntar ao cliente o que ela representa)
SELECT  filial_id, produto_id, preco_unitario, preco_compra, preco_venda
FROM    produtos_filial
WHERE   preco_unitario <> preco_compra
  AND   preco_unitario <> preco_venda
ORDER BY produto_id;

-- E17 [CONFIRMAR] preço praticado na venda diferente do preço de venda do cadastro
SELECT  v.venda_id, v.produto_id, v.valor_unitario AS preco_vendido,
        pf.preco_venda AS preco_cadastro
FROM    venda v
JOIN    produtos_filial pf ON pf.produto_id = v.produto_id AND pf.filial_id = v.filial_id
WHERE   v.valor_unitario <> pf.preco_venda
ORDER BY v.venda_id;

-- E18 [CONFIRMAR] vendeu mais do que o estoque atual do produto
SELECT  v.venda_id, v.data_emissao, v.produto_id, v.qtde_vendida, pf.estoque
FROM    venda v
JOIN    produtos_filial pf ON pf.produto_id = v.produto_id AND pf.filial_id = v.filial_id
WHERE   v.qtde_vendida > pf.estoque
ORDER BY v.venda_id;

-- Erros que NÃO aparecem em consulta, porque estão na planilha e não no banco
-- (ficam documentados em docs/parte4_validacao.md):
--   E19  aba pedido_compra: 11 colunas sem título (M a W) com dados em 9 linhas
--   E20  aba produtos_filial e fornecedor: código do fornecedor como texto ("F8")
--   E21  aba produtos_filial: coluna "idproduto" (nas outras abas é "produto_id")


-- =====================================================================
-- BLOCO D - RESUMO DOS ERROS (uma linha por verificação)
-- =====================================================================
SELECT 'E01' AS cod, 'ERRO'      AS tipo, 'venda' AS tabela, 'Venda de produto não cadastrado' AS problema,
       COUNT(*) AS qtd
FROM   venda v
WHERE  NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.produto_id = v.produto_id AND p.filial_id = v.filial_id)
UNION ALL
SELECT 'E02', 'ERRO', 'venda', 'Venda em filial sem cadastro de produtos', COUNT(*)
FROM   venda v
WHERE  NOT EXISTS (SELECT 1 FROM produtos_filial p WHERE p.filial_id = v.filial_id)
UNION ALL
SELECT 'E03', 'ERRO', 'venda', 'Quantidade fracionada em unidade UN', COUNT(*)
FROM   venda WHERE unidade_medida = 'UN' AND qtde_vendida <> FLOOR(qtde_vendida)
UNION ALL
SELECT 'E04', 'CONFIRMAR', 'venda', 'Mesmo valor unitário em produtos diferentes', COUNT(*)
FROM   venda v
WHERE  v.valor_unitario IN (SELECT valor_unitario FROM venda GROUP BY valor_unitario HAVING COUNT(DISTINCT produto_id) > 1)
UNION ALL
SELECT 'E05', 'CONFIRMAR', 'venda', 'Horário 08:00:00 em todas as linhas', COUNT(*)
FROM   venda WHERE horariomov = '08:00:00'
UNION ALL
SELECT 'E06', 'ERRO', 'pedido_compra', 'Pedido sem ordem de compra (ordem = 0)', COUNT(*)
FROM   pedido_compra WHERE ordem_compra = 0
UNION ALL
SELECT 'E07', 'ERRO', 'pedido_compra', 'Pedido duplicado (mesmo produto, datas e preço)', COUNT(*)
FROM   pedido_compra a
JOIN   pedido_compra b ON b.produto_id = a.produto_id AND b.filial_id = a.filial_id
                      AND b.data_pedido = a.data_pedido AND b.data_entrega = a.data_entrega
                      AND b.preco_compra = a.preco_compra AND b.pedido_id > a.pedido_id
UNION ALL
SELECT 'E08', 'ERRO', 'pedido_compra', 'Data de entrega anterior ao pedido', COUNT(*)
FROM   pedido_compra WHERE data_entrega < data_pedido
UNION ALL
SELECT 'E09', 'ERRO', 'entradas_mercadoria', 'Entrada sem pedido (ordem_compra inexistente)', COUNT(*)
FROM   entradas_mercadoria e
WHERE  NOT EXISTS (SELECT 1 FROM pedido_compra p WHERE p.ordem_compra = e.ordem_compra)
UNION ALL
SELECT 'E10', 'ERRO', 'entradas_mercadoria', 'Entrada anterior à data do pedido', COUNT(*)
FROM   entradas_mercadoria e
JOIN   pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id AND p.filial_id = e.filial_id
WHERE  e.data_entrada < p.data_pedido
UNION ALL
SELECT 'E11', 'ERRO', 'entradas_mercadoria', 'Recebido mais do que o pedido', COUNT(*)
FROM   entradas_mercadoria e
JOIN   pedido_compra p ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id AND p.filial_id = e.filial_id
WHERE  e.qtde_recebida > p.qtde_pedida
UNION ALL
SELECT 'E12', 'ERRO', 'pedido x entrada', 'Qtde entregue (pedido) <> qtde recebida (entrada)', COUNT(*)
FROM   pedido_compra p
JOIN   entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id AND e.filial_id = p.filial_id
WHERE  p.qtde_entregue <> e.qtde_recebida
UNION ALL
SELECT 'E13', 'CONFIRMAR', 'pedido x entrada', 'Custo da entrada <> preço do pedido', COUNT(*)
FROM   pedido_compra p
JOIN   entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id AND e.filial_id = p.filial_id
WHERE  p.preco_compra <> e.custo_unitario
UNION ALL
SELECT 'E14', 'ERRO', 'pedido x produto', 'Fornecedor do pedido <> fornecedor do produto', COUNT(*)
FROM   pedido_compra p
JOIN   produtos_filial pf ON pf.produto_id = p.produto_id AND pf.filial_id = p.filial_id
WHERE  p.fornecedor_id <> pf.idfornecedor
UNION ALL
SELECT 'E15', 'ERRO', 'produtos_filial', 'Preço de venda menor que o de compra', COUNT(*)
FROM   produtos_filial WHERE preco_venda < preco_compra
UNION ALL
SELECT 'E16', 'CONFIRMAR', 'produtos_filial', 'preco_unitario sem relação com compra/venda', COUNT(*)
FROM   produtos_filial WHERE preco_unitario <> preco_compra AND preco_unitario <> preco_venda
UNION ALL
SELECT 'E17', 'CONFIRMAR', 'venda x produto', 'Preço vendido <> preço de venda cadastrado', COUNT(*)
FROM   venda v
JOIN   produtos_filial pf ON pf.produto_id = v.produto_id AND pf.filial_id = v.filial_id
WHERE  v.valor_unitario <> pf.preco_venda
UNION ALL
SELECT 'E18', 'CONFIRMAR', 'venda x produto', 'Vendeu mais que o estoque atual', COUNT(*)
FROM   venda v
JOIN   produtos_filial pf ON pf.produto_id = v.produto_id AND pf.filial_id = v.filial_id
WHERE  v.qtde_vendida > pf.estoque
ORDER BY cod;
