-- V1. Comparação da última carga entre planilha, aceitação e contagem no banco.
WITH contagens AS (
    SELECT 'fornecedor' AS aba, COUNT(*) AS banco FROM public.fornecedor
    UNION ALL SELECT 'produtos_filial', COUNT(*) FROM public.produtos_filial
    UNION ALL SELECT 'pedido_compra', COUNT(*) FROM public.pedido_compra
    UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM public.entradas_mercadoria
    UNION ALL SELECT 'venda', COUNT(*) FROM public.venda
)
SELECT c.aba, COUNT(a.linha_excel) AS linhas_planilha,
       COUNT(*) FILTER (WHERE a.status = 'inserida') AS inseridas,
       COUNT(*) FILTER (WHERE a.status = 'existente') AS existentes,
       COUNT(*) FILTER (WHERE a.status = 'rejeitada') AS rejeitadas,
       c.banco
FROM contagens c
LEFT JOIN public.importacao_linhas a ON a.aba = c.aba
GROUP BY c.aba, c.banco
ORDER BY c.aba;

-- V2. Rastreabilidade de rejeições, duplicidades e tratamentos aplicados.
SELECT aba, linha_excel, status, ocorrencias, dados_origem
FROM public.importacao_linhas
WHERE status = 'rejeitada' OR JSONB_ARRAY_LENGTH(ocorrencias) > 0
ORDER BY aba, linha_excel;

-- V3. Reconciliação das vendas de fevereiro com o sistema de origem.
SELECT filial_id, data_emissao, COUNT(*) AS linhas,
       COUNT(DISTINCT venda_id) AS vendas,
       SUM(qtde_vendida) AS unidades,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS valor_em_reais,
       COUNT(*) FILTER (WHERE qtde_vendida IS NULL OR valor_unitario IS NULL) AS linhas_incompletas
FROM public.venda
WHERE data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01'
GROUP BY filial_id, data_emissao
ORDER BY filial_id, data_emissao;

SELECT COUNT(*) AS linhas_de_venda, COUNT(DISTINCT produto_id) AS produtos,
       SUM(qtde_vendida) AS quantidade,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS total_em_reais
FROM public.venda
WHERE data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01';

-- V4. Campos nulos, negativos ou zerados que precisam de decisão de negócio.
-- Devoluções, ajustes de estoque e bonificações podem justificar alguns casos.
SELECT 'venda' AS tabela, CONCAT_WS('/', filial_id, venda_id, data_emissao, produto_id, item, horariomov) AS chave,
       JSONB_BUILD_OBJECT('qtde', qtde_vendida, 'preco', valor_unitario) AS valores
FROM public.venda
WHERE qtde_vendida IS NULL OR qtde_vendida <= 0 OR valor_unitario IS NULL OR valor_unitario <= 0
UNION ALL
SELECT 'pedido_compra', CONCAT_WS('/', pedido_id, produto_id, item),
       JSONB_BUILD_OBJECT('qtde_pedida', qtde_pedida, 'qtde_entregue', qtde_entregue, 'preco', preco_compra)
FROM public.pedido_compra
WHERE qtde_pedida IS NULL OR qtde_pedida <= 0 OR qtde_entregue < 0 OR preco_compra IS NULL OR preco_compra <= 0
UNION ALL
SELECT 'entradas_mercadoria', CONCAT_WS('/', ordem_compra, produto_id, item, nro_nfe),
       JSONB_BUILD_OBJECT('qtde', qtde_recebida, 'custo', custo_unitario)
FROM public.entradas_mercadoria
WHERE qtde_recebida IS NULL OR qtde_recebida <= 0 OR custo_unitario IS NULL OR custo_unitario <= 0
UNION ALL
SELECT 'produtos_filial', CONCAT_WS('/', filial_id, produto_id),
       JSONB_BUILD_OBJECT('estoque', estoque, 'preco_unitario', preco_unitario,
                          'preco_compra', preco_compra, 'preco_venda', preco_venda)
FROM public.produtos_filial
WHERE estoque IS NULL OR estoque < 0
   OR preco_unitario IS NULL OR preco_unitario <= 0
   OR preco_compra IS NULL OR preco_compra <= 0
   OR preco_venda IS NULL OR preco_venda <= 0
ORDER BY tabela, chave;

-- V5. Referências sem catálogo ou pedido correspondente.
WITH movimento AS (
    SELECT 'venda' AS origem, filial_id, produto_id FROM public.venda
    UNION ALL SELECT 'pedido_compra', filial_id, produto_id FROM public.pedido_compra
    UNION ALL SELECT 'entradas_mercadoria', filial_id, produto_id FROM public.entradas_mercadoria
)
SELECT m.origem, m.filial_id, m.produto_id, COUNT(*) AS linhas
FROM movimento m
WHERE NOT EXISTS (
    SELECT 1 FROM public.produtos_filial p
    WHERE p.filial_id = m.filial_id AND p.produto_id = m.produto_id
)
GROUP BY m.origem, m.filial_id, m.produto_id
ORDER BY m.origem, m.filial_id, m.produto_id;

SELECT e.ordem_compra, e.filial_id, e.produto_id, e.nro_nfe, e.item, e.data_entrada
FROM public.entradas_mercadoria e
WHERE e.ordem_compra <= 0 OR e.filial_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.pedido_compra p
    WHERE p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id AND p.filial_id = e.filial_id
)
ORDER BY e.ordem_compra, e.filial_id, e.produto_id, e.nro_nfe, e.item;

SELECT 'pedido_compra' AS tabela, pedido_id::TEXT AS id, filial_id, produto_id
FROM public.pedido_compra
WHERE filial_id IS NULL OR filial_id <= 0 OR ordem_compra <= 0 OR fornecedor_id IS NULL
UNION ALL
SELECT 'produtos_filial', NULL::TEXT, filial_id, produto_id
FROM public.produtos_filial
WHERE idfornecedor IS NULL OR filial_id <= 0
ORDER BY tabela, id, filial_id, produto_id;

-- V6. Datas incompletas ou inconsistentes e divergências nas quantidades.
SELECT pedido_id, item, produto_id, data_pedido, data_entrega, qtde_pedida,
       qtde_entregue, qtde_pendente
FROM public.pedido_compra
WHERE data_pedido IS NULL OR data_entrega < data_pedido
   OR (data_entrega IS NULL AND qtde_entregue > 0)
   OR qtde_entregue > qtde_pedida
   OR qtde_pendente IS DISTINCT FROM (qtde_pedida - qtde_entregue)
ORDER BY pedido_id, item;

SELECT e.ordem_compra, e.filial_id, e.produto_id, e.nro_nfe, e.data_entrada
FROM public.entradas_mercadoria e
WHERE e.data_entrada IS NULL OR e.data_entrada < (
    SELECT MIN(p.data_pedido) FROM public.pedido_compra p
    WHERE p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id AND p.filial_id = e.filial_id
)
ORDER BY e.ordem_compra, e.filial_id, e.produto_id, e.nro_nfe;

-- V7. Reconciliação de pedidos feitos em fevereiro com entradas até o fechamento.
-- Agrupa movimentos por ordem, filial e produto, exibindo entrega em excesso.
WITH pedidos AS (
    SELECT ordem_compra, filial_id, produto_id, SUM(qtde_pedida) AS pedida,
           COUNT(*) FILTER (WHERE qtde_pedida IS NULL) AS pedidos_sem_quantidade
    FROM public.pedido_compra
    WHERE data_pedido >= DATE '2025-02-01' AND data_pedido < DATE '2025-03-01'
      AND ordem_compra > 0 AND filial_id IS NOT NULL
    GROUP BY ordem_compra, filial_id, produto_id
),
entradas AS (
    SELECT ordem_compra, filial_id, produto_id, SUM(qtde_recebida) AS recebida,
           COUNT(*) FILTER (WHERE qtde_recebida IS NULL) AS entradas_sem_quantidade
    FROM public.entradas_mercadoria
    WHERE data_entrada < DATE '2025-03-01'
    GROUP BY ordem_compra, filial_id, produto_id
)
SELECT p.ordem_compra, p.filial_id, p.produto_id, p.pedida,
       COALESCE(e.recebida, 0) AS recebida_ate_fevereiro,
       p.pedidos_sem_quantidade, COALESCE(e.entradas_sem_quantidade, 0) AS entradas_sem_quantidade,
       CASE WHEN p.pedidos_sem_quantidade = 0 AND COALESCE(e.entradas_sem_quantidade, 0) = 0
            THEN p.pedida - COALESCE(e.recebida, 0) END AS saldo
FROM pedidos p
LEFT JOIN entradas e USING (ordem_compra, filial_id, produto_id)
ORDER BY p.ordem_compra, p.filial_id, p.produto_id;

-- V8. Variações de descrição por produto nas diferentes origens.
WITH descricoes AS (
    SELECT produto_id, descricao FROM public.produtos_filial
    UNION ALL SELECT produto_id, descricao_produto FROM public.pedido_compra
    UNION ALL SELECT produto_id, descricao_produto FROM public.entradas_mercadoria
)
SELECT produto_id, ARRAY_AGG(DISTINCT LOWER(BTRIM(descricao)) ORDER BY LOWER(BTRIM(descricao))) AS descricoes
FROM descricoes
WHERE NULLIF(BTRIM(descricao), '') IS NOT NULL
GROUP BY produto_id
HAVING COUNT(DISTINCT LOWER(BTRIM(descricao))) > 1
ORDER BY produto_id;

-- V9. Ordens compartilhadas entre vários pedidos para o mesmo produto e filial.
-- O saldo pode ser calculado para a ordem. A distribuição por pedido exige
-- uma regra de alocação ou uma chave mais específica na fonte.
SELECT ordem_compra, filial_id, produto_id, COUNT(DISTINCT pedido_id) AS pedidos,
       MIN(data_pedido) AS primeiro_pedido, MAX(data_pedido) AS ultimo_pedido
FROM public.pedido_compra
WHERE ordem_compra > 0
GROUP BY ordem_compra, filial_id, produto_id
HAVING COUNT(DISTINCT pedido_id) > 1
ORDER BY ordem_compra, filial_id, produto_id;

-- V10. Compras conciliáveis com excesso ou diferença entre a quantidade
-- registrada no pedido e a quantidade total nas notas de entrada.
WITH pedidos AS (
    SELECT ordem_compra, filial_id, produto_id,
           SUM(qtde_pedida) AS pedida, SUM(qtde_entregue) AS entregue_no_pedido
    FROM public.pedido_compra
    WHERE ordem_compra > 0 AND filial_id IS NOT NULL
    GROUP BY ordem_compra, filial_id, produto_id
    HAVING COUNT(qtde_pedida) = COUNT(*)
),
entradas AS (
    SELECT ordem_compra, filial_id, produto_id, SUM(qtde_recebida) AS recebida_nfe
    FROM public.entradas_mercadoria
    GROUP BY ordem_compra, filial_id, produto_id
    HAVING COUNT(qtde_recebida) = COUNT(*)
)
SELECT p.ordem_compra, p.filial_id, p.produto_id,
       p.pedida, p.entregue_no_pedido, e.recebida_nfe,
       e.recebida_nfe - p.entregue_no_pedido AS diferenca,
       e.recebida_nfe > p.pedida AS recebimento_acima_do_pedido
FROM pedidos p
JOIN entradas e USING (ordem_compra, filial_id, produto_id)
WHERE e.recebida_nfe <> p.entregue_no_pedido OR e.recebida_nfe > p.pedida
ORDER BY p.ordem_compra, p.filial_id, p.produto_id;

-- V11. Vendas em UN com quantidade fracionária. Confirme se UN permite fração.
SELECT venda_id, data_emissao, filial_id, produto_id, qtde_vendida, unidade_medida
FROM public.venda
WHERE UPPER(BTRIM(unidade_medida)) = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida)
ORDER BY venda_id;

-- V12. Bloco auxiliar M:W na aba pedido_compra, sem cabeçalho.
-- As colunas de ordem/quantidade são interpretadas pela posição aparente,
-- apenas para comparar os registros e discutir os dois casos sem equivalente.
SELECT a.linha_excel, a.dados_origem ->> 'A: pedido_id' AS pedido_da_linha,
       a.dados_origem ->> 'O: sem cabeçalho' AS produto_do_bloco,
       a.dados_origem ->> 'Q: sem cabeçalho' AS ordem_do_bloco,
       a.dados_origem ->> 'R: sem cabeçalho' AS quantidade_do_bloco,
       p.pedido_id AS pedido_equivalente
FROM public.importacao_linhas a
LEFT JOIN public.pedido_compra p
    ON p.ordem_compra::TEXT = a.dados_origem ->> 'Q: sem cabeçalho'
   AND p.produto_id = a.dados_origem ->> 'O: sem cabeçalho'
   AND p.filial_id::TEXT = a.dados_origem ->> 'S: sem cabeçalho'
WHERE a.aba = 'pedido_compra' AND a.dados_origem ? 'Q: sem cabeçalho'
ORDER BY a.linha_excel;

-- V13. Quantidades sem uma ordem vinculada no recorte de fevereiro.
SELECT pedido_id, data_pedido, filial_id, produto_id, qtde_pedida, qtde_entregue
FROM public.pedido_compra
WHERE ordem_compra <= 0 AND data_pedido >= DATE '2025-02-01' AND data_pedido < DATE '2025-03-01'
ORDER BY pedido_id;

-- V14. Frequência máxima usada para explicar o resultado do filtro da Parte 3.
WITH contagem AS (
    SELECT produto_id, COUNT(DISTINCT pedido_id) AS pedidos
    FROM public.pedido_compra
    WHERE data_pedido >= DATE '2025-02-01' AND data_pedido < DATE '2025-03-01'
    GROUP BY produto_id
)
SELECT COUNT(*) AS produtos, MAX(pedidos) AS maior_frequencia,
       COUNT(*) FILTER (WHERE pedidos > 10) AS produtos_acima_de_10
FROM contagem;
