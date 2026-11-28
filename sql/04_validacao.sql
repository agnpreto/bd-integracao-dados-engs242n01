-- 04_validacao
-- Nome: Equipe CoreData (Ana Júlia Pantoja Chagas e Rafaela da Silva Tavares)
-- Consultas prontas para a reunião de validação dos dados de fevereiro/2025 (PostgreSQL).
-- Ordem: importar.py -> 04_validacao.sql (ANTES) -> 05_correcoes.sql -> 04_validacao.sql (DEPOIS).
-- Cada bloco "E" mostra as linhas com erro; o bloco "R" resume os totais para conferência.

-- =====================================================================
-- R1 - Reconciliação: linhas no banco x linhas na planilha (20, 20, 29, 20, 33 e 20 fornecedores)
-- Rodar logo após a importação. Depois de sql/05_correcoes.sql, produtos_filial passa a ter 28 linhas e
-- fornecedor 21 (cadastros provisórios da correção C2): a diferença é esperada e está em correcao_log.
-- =====================================================================
SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas_no_banco, 20 AS linhas_na_planilha FROM public.fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*), 20 FROM public.produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*), 29 FROM public.pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*), 20 FROM public.entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*), 33 FROM public.venda;

-- =====================================================================
-- R2 - Totais de controle de fevereiro/2025 (o cliente confere contra o sistema dele)
-- =====================================================================
SELECT COUNT(*)                                  AS linhas_venda_fev,
       COUNT(DISTINCT produto_id)                AS produtos_distintos,
       SUM(qtde_vendida)                         AS qtde_total,
       SUM(qtde_vendida * valor_unitario)        AS valor_total_rs,
       MIN(data_emissao)                         AS primeira_venda,
       MAX(data_emissao)                         AS ultima_venda
FROM   public.venda
WHERE  data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01';

-- R3 - Vendas por mês: mostra que a base tem janeiro e março além de fevereiro
SELECT to_char(data_emissao, 'YYYY-MM') AS mes, COUNT(*) AS linhas, SUM(qtde_vendida * valor_unitario) AS valor_rs
FROM   public.venda
GROUP  BY 1 ORDER BY 1;

-- =====================================================================
-- E1 - VENDA: produto vendido que não existe no cadastro (produtos_filial)  [P21 a P28]
-- =====================================================================
SELECT v.venda_id, v.data_emissao, v.produto_id, v.filial_id, v.qtde_vendida, v.valor_unitario
FROM   public.venda v
WHERE  NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.produto_id = v.produto_id)
ORDER  BY v.venda_id;

-- E2 - VENDA: filial sem cadastro de produtos (só existe a filial 1 em produtos_filial)
SELECT v.venda_id, v.data_emissao, v.produto_id, v.filial_id
FROM   public.venda v
WHERE  NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.filial_id = v.filial_id)
ORDER  BY v.venda_id;

-- E3 - VENDA: quantidade fracionada em unidade UN (unidade deveria ser inteira)
SELECT venda_id, data_emissao, produto_id, qtde_vendida, unidade_medida
FROM   public.venda
WHERE  unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida)
ORDER  BY venda_id;

-- E4 - VENDA: preço praticado diferente do preco_venda do cadastro
SELECT v.venda_id, v.produto_id, v.valor_unitario AS preco_vendido, p.preco_venda AS preco_cadastro,
       ROUND(v.valor_unitario - p.preco_venda, 2) AS diferenca
FROM   public.venda v
JOIN   public.produtos_filial p ON p.produto_id = v.produto_id AND p.filial_id = v.filial_id
WHERE  v.valor_unitario <> p.preco_venda
ORDER  BY v.venda_id;

-- E5 - VENDA: mesmo valor_unitario repetido em produtos diferentes (indício de preço copiado: P13=P21, P14=P22...)
SELECT valor_unitario, COUNT(DISTINCT produto_id) AS produtos, STRING_AGG(DISTINCT produto_id, ', ') AS lista_produtos
FROM   public.venda
GROUP  BY valor_unitario
HAVING COUNT(DISTINCT produto_id) > 1
ORDER  BY valor_unitario;

-- E6 - VENDA: horário e item sem variação (todas as linhas com 08:00:00 e item 1 = valor padrão, não real)
SELECT horariomov, item, COUNT(*) AS linhas
FROM   public.venda
GROUP  BY horariomov, item;

-- =====================================================================
-- E7 - PEDIDO_COMPRA: sem ordem_compra (0): não se liga a nenhuma entrada
-- =====================================================================
SELECT pedido_id, produto_id, data_pedido, qtde_pedida, ordem_compra
FROM   public.pedido_compra
WHERE  ordem_compra = 0
ORDER  BY pedido_id;

-- E8 - PEDIDO_COMPRA: data de entrega anterior à data do pedido
SELECT pedido_id, produto_id, data_pedido, data_entrega, (data_pedido - data_entrega) AS dias_de_diferenca
FROM   public.pedido_compra
WHERE  data_entrega < data_pedido
ORDER  BY pedido_id;

-- E9 - PEDIDO_COMPRA: possível duplicidade (mesmo produto, filial, data de pedido e de entrega, preço)
SELECT produto_id, filial_id, data_pedido, data_entrega, preco_compra,
       COUNT(*) AS ocorrencias, STRING_AGG(pedido_id::text, ', ' ORDER BY pedido_id) AS pedidos
FROM   public.pedido_compra
GROUP  BY produto_id, filial_id, data_pedido, data_entrega, preco_compra
HAVING COUNT(*) > 1
ORDER  BY produto_id;

-- E10 - PEDIDO_COMPRA: fornecedor do pedido diferente do fornecedor do cadastro do produto
SELECT p.pedido_id, p.produto_id, p.fornecedor_id AS fornecedor_no_pedido, pf.idfornecedor AS fornecedor_no_cadastro
FROM   public.pedido_compra p
JOIN   public.produtos_filial pf ON pf.produto_id = p.produto_id AND pf.filial_id = p.filial_id
WHERE  p.fornecedor_id IS DISTINCT FROM pf.idfornecedor
ORDER  BY p.pedido_id;

-- =====================================================================
-- E11 - ENTRADAS: entrada sem pedido correspondente (ordem_compra/produto não encontrados em pedido_compra)
-- =====================================================================
SELECT e.nro_nfe, e.ordem_compra, e.produto_id, e.data_entrada, e.qtde_recebida
FROM   public.entradas_mercadoria e
WHERE  NOT EXISTS (SELECT 1 FROM public.pedido_compra p
                   WHERE p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id)
ORDER  BY e.nro_nfe;

-- E12 - ENTRADAS: recebido maior que o pedido (recebeu mais do que comprou)
SELECT p.pedido_id, p.produto_id, p.qtde_pedida, e.qtde_recebida, (e.qtde_recebida - p.qtde_pedida) AS excesso
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE  e.qtde_recebida > p.qtde_pedida
ORDER  BY p.pedido_id;

-- E13 - PEDIDO x ENTRADA: qtde_entregue (pedido) diferente de qtde_recebida (entrada)
SELECT p.pedido_id, p.produto_id, p.qtde_entregue, e.qtde_recebida, (e.qtde_recebida - p.qtde_entregue) AS diferenca
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE  e.qtde_recebida <> p.qtde_entregue
ORDER  BY p.pedido_id;

-- E14 - PEDIDO x ENTRADA: preço de compra do pedido diferente do custo da nota
SELECT p.pedido_id, p.produto_id, p.preco_compra, e.custo_unitario, ROUND(e.custo_unitario - p.preco_compra, 2) AS diferenca
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE  e.custo_unitario <> p.preco_compra
ORDER  BY p.pedido_id;

-- E15 - ENTRADAS: data da entrada anterior à data do pedido
SELECT p.pedido_id, p.produto_id, p.data_pedido, e.data_entrada
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE  e.data_entrada < p.data_pedido
ORDER  BY p.pedido_id;

-- =====================================================================
-- E16 - PRODUTOS_FILIAL: preço de venda menor que o preço de compra (venda com prejuízo)
-- =====================================================================
SELECT produto_id, preco_compra, preco_venda, ROUND(preco_venda - preco_compra, 2) AS margem
FROM   public.produtos_filial
WHERE  preco_venda < preco_compra
ORDER  BY CAST(SUBSTRING(produto_id FROM 2) AS integer);

-- E17 - PRODUTOS_FILIAL: preco_unitario, preco_compra e preco_venda sem relação entre si
--        (preco_unitario deveria coincidir com preco_venda ou preco_compra)
SELECT produto_id, preco_unitario, preco_compra, preco_venda
FROM   public.produtos_filial
WHERE  preco_unitario NOT IN (preco_compra, preco_venda)
ORDER  BY CAST(SUBSTRING(produto_id FROM 2) AS integer);

-- E18 - FORNECEDOR: fornecedores sem nenhum produto ou pedido ligado
SELECT f.idfornecedor, f.codigo_origem, f.razao_social
FROM   public.fornecedor f
WHERE  NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.idfornecedor = f.idfornecedor)
  AND  NOT EXISTS (SELECT 1 FROM public.pedido_compra   o WHERE o.fornecedor_id = f.idfornecedor)
ORDER  BY f.idfornecedor;

-- =====================================================================
-- RESUMO - quantidade de linhas com erro por verificação (entra na tabela do docs/parte4_validacao.md)
-- =====================================================================
SELECT 'E1  venda de produto sem cadastro' AS verificacao, COUNT(*) AS linhas
FROM public.venda v WHERE NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.produto_id = v.produto_id)
UNION ALL
SELECT 'E2  venda em filial sem cadastro', COUNT(*)
FROM public.venda v WHERE NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.filial_id = v.filial_id)
UNION ALL
SELECT 'E3  quantidade fracionada em UN', COUNT(*)
FROM public.venda WHERE unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida)
UNION ALL
SELECT 'E4  preço vendido <> preço de cadastro', COUNT(*)
FROM public.venda v JOIN public.produtos_filial p ON p.produto_id = v.produto_id AND p.filial_id = v.filial_id
WHERE v.valor_unitario <> p.preco_venda
UNION ALL
SELECT 'E5  valor_unitario repetido entre produtos (grupos)', COUNT(*)
FROM (SELECT valor_unitario FROM public.venda GROUP BY valor_unitario HAVING COUNT(DISTINCT produto_id) > 1) t
UNION ALL
SELECT 'E7  pedido sem ordem_compra', COUNT(*) FROM public.pedido_compra WHERE ordem_compra = 0
UNION ALL
SELECT 'E8  entrega antes do pedido', COUNT(*) FROM public.pedido_compra WHERE data_entrega < data_pedido
UNION ALL
SELECT 'E9  possível duplicidade de pedidos (grupos)', COUNT(*)
FROM (SELECT 1 FROM public.pedido_compra GROUP BY produto_id, filial_id, data_pedido, data_entrega, preco_compra HAVING COUNT(*) > 1) t
UNION ALL
SELECT 'E10 fornecedor do pedido <> cadastro', COUNT(*)
FROM public.pedido_compra p JOIN public.produtos_filial pf ON pf.produto_id = p.produto_id AND pf.filial_id = p.filial_id
WHERE p.fornecedor_id IS DISTINCT FROM pf.idfornecedor
UNION ALL
SELECT 'E11 entrada sem pedido', COUNT(*)
FROM public.entradas_mercadoria e
WHERE NOT EXISTS (SELECT 1 FROM public.pedido_compra p WHERE p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id)
UNION ALL
SELECT 'E12 recebido > pedido', COUNT(*)
FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE e.qtde_recebida > p.qtde_pedida
UNION ALL
SELECT 'E13 entregue (pedido) <> recebido (entrada)', COUNT(*)
FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE e.qtde_recebida <> p.qtde_entregue
UNION ALL
SELECT 'E14 preço do pedido <> custo da nota', COUNT(*)
FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE e.custo_unitario <> p.preco_compra
UNION ALL
SELECT 'E15 entrada antes do pedido', COUNT(*)
FROM public.pedido_compra p JOIN public.entradas_mercadoria e ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE e.data_entrada < p.data_pedido
UNION ALL
SELECT 'E16 preço de venda < preço de compra', COUNT(*) FROM public.produtos_filial WHERE preco_venda < preco_compra
UNION ALL
SELECT 'E17 preco_unitario sem relação com compra/venda', COUNT(*)
FROM public.produtos_filial WHERE preco_unitario NOT IN (preco_compra, preco_venda)
UNION ALL
SELECT 'E18 fornecedor sem produto/pedido', COUNT(*)
FROM public.fornecedor f
WHERE NOT EXISTS (SELECT 1 FROM public.produtos_filial p WHERE p.idfornecedor = f.idfornecedor)
  AND NOT EXISTS (SELECT 1 FROM public.pedido_compra o WHERE o.fornecedor_id = f.idfornecedor);
