-- 2.1 Total vendido por produto em fevereiro de 2025.
SELECT produto_id,
       SUM(qtde_vendida) AS qtde_vendida,
       ROUND(SUM(qtde_vendida * valor_unitario), 2) AS total_vendido,
       COUNT(*) FILTER (WHERE qtde_vendida IS NULL OR valor_unitario IS NULL)
           AS linhas_sem_quantidade_ou_preco
FROM public.venda
WHERE data_emissao >= DATE '2025-02-01' AND data_emissao < DATE '2025-03-01'
GROUP BY produto_id
ORDER BY total_vendido DESC NULLS LAST, produto_id;

-- 2.2 Ordens com produtos sem recebimento ou com recebimento parcial.
-- Consolida pedidos e entradas antes da junção para evitar duplicar quantidades.
-- A filial e o produto distinguem itens da mesma ordem. Uma filial desconhecida
-- ou uma entrada sem quantidade impede a conciliação e aparece na Parte 4.
WITH pedidos AS (
    SELECT ordem_compra, produto_id, filial_id,
           MIN(data_pedido) AS primeira_solicitacao,
           SUM(qtde_pedida) AS qtde_pedida
    FROM public.pedido_compra
    WHERE filial_id IS NOT NULL AND ordem_compra > 0
    GROUP BY ordem_compra, produto_id, filial_id
    HAVING COUNT(qtde_pedida) = COUNT(*)
),
recebimentos AS (
    SELECT ordem_compra, produto_id, filial_id,
           SUM(qtde_recebida) AS qtde_recebida,
           COUNT(*) FILTER (WHERE qtde_recebida IS NULL) AS entradas_sem_quantidade
    FROM public.entradas_mercadoria
    WHERE filial_id IS NOT NULL AND ordem_compra > 0
    GROUP BY ordem_compra, produto_id, filial_id
)
SELECT NULL::BIGINT AS pedido_id, p.ordem_compra, p.filial_id, p.produto_id, p.primeira_solicitacao,
       p.qtde_pedida, COALESCE(r.qtde_recebida, 0) AS qtde_recebida,
       p.qtde_pedida - COALESCE(r.qtde_recebida, 0) AS qtde_pendente,
       CASE WHEN COALESCE(r.qtde_recebida, 0) = 0 THEN 'Sem recebimento registrado'
            ELSE 'Recebimento parcial' END AS situacao
FROM pedidos p
LEFT JOIN recebimentos r USING (ordem_compra, produto_id, filial_id)
WHERE p.qtde_pedida > COALESCE(r.qtde_recebida, 0)
  AND COALESCE(r.entradas_sem_quantidade, 0) = 0
UNION ALL
-- Requisições sem ordem válida aparecem individualmente. Um zero na ordem
-- não identifica uma compra e não comprova a ausência de entrada física.
SELECT pedido_id, ordem_compra, filial_id, produto_id, data_pedido,
       qtde_pedida, NULL, NULL, 'Sem ordem vinculada'
FROM public.pedido_compra
WHERE ordem_compra <= 0 AND qtde_pedida > 0 AND qtde_entregue = 0
ORDER BY ordem_compra, filial_id, produto_id, pedido_id;
