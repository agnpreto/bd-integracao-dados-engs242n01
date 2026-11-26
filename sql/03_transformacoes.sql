-- 3.1 Formata os identificadores e as datas das tabelas transacionais.
-- A venda usa a descrição do catálogo da mesma filial, quando disponível.
SELECT v.venda_id,
       CONCAT_WS(' - ', v.produto_id, NULLIF(BTRIM(p.descricao), '')) AS produto,
       TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS data_emissao
FROM public.venda v
LEFT JOIN public.produtos_filial p USING (filial_id, produto_id)
ORDER BY v.data_emissao, v.venda_id, v.filial_id, v.item;

SELECT e.ordem_compra,
       CONCAT_WS(' - ', e.produto_id, NULLIF(BTRIM(e.descricao_produto), '')) AS produto,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY') AS data_entrada
FROM public.entradas_mercadoria e
ORDER BY e.data_entrada, e.ordem_compra, e.nro_nfe, e.item;

SELECT filial_id, CONCAT_WS(' - ', produto_id, NULLIF(BTRIM(descricao), '')) AS produto
FROM public.produtos_filial
ORDER BY filial_id, produto_id;

-- 3.2 Mais de 10 vezes = mais de 10 pedidos distintos contendo o produto,
-- em fevereiro de 2025. Várias linhas no mesmo pedido contam uma só vez.
-- A quantidade exibida é a soma das unidades solicitadas no dia.
WITH periodo AS (
    SELECT *
    FROM public.pedido_compra
    WHERE data_pedido >= DATE '2025-02-01' AND data_pedido < DATE '2025-03-01'
),
frequentes AS (
    SELECT produto_id, COUNT(DISTINCT pedido_id) AS requisicoes
    FROM periodo
    GROUP BY produto_id
    HAVING COUNT(DISTINCT pedido_id) > 10
)
SELECT CONCAT_WS(' - ', p.produto_id, MIN(NULLIF(BTRIM(p.descricao_produto), ''))) AS produto,
       SUM(p.qtde_pedida) AS qtde_requisitada,
       TO_CHAR(p.data_pedido, 'DD/MM/YYYY') AS data_solicitacao,
       f.requisicoes AS requisicoes_no_mes
FROM periodo p
JOIN frequentes f USING (produto_id)
GROUP BY p.produto_id, p.data_pedido, f.requisicoes
ORDER BY p.data_pedido, p.produto_id;

SELECT pedido_id, CONCAT_WS(' - ', produto_id, NULLIF(BTRIM(descricao_produto), '')) AS produto,
       TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_solicitacao,
       TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega
FROM public.pedido_compra
ORDER BY data_pedido, pedido_id, item;

-- 3.3 Gera um ID numérico vinculado a um fornecedor pendente quando o
-- produto é inserido sem essa referência. Cadastro explícito é preservado.
-- Instale após a carga inicial. A trigger roda somente para linhas inseridas.
BEGIN;

SELECT SETVAL(
    PG_GET_SERIAL_SEQUENCE('public.fornecedor', 'idfornecedor'),
    GREATEST(
        COALESCE((SELECT MAX(idfornecedor) FROM public.fornecedor), 1),
        COALESCE(PG_SEQUENCE_LAST_VALUE(
            PG_GET_SERIAL_SEQUENCE('public.fornecedor', 'idfornecedor')::REGCLASS
        ), 1)
    )
);

CREATE OR REPLACE FUNCTION public.gerar_fornecedor_produto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    novo_id BIGINT;
BEGIN
    LOOP
        INSERT INTO public.fornecedor (razao_social)
        VALUES ('Fornecedor a identificar')
        ON CONFLICT (idfornecedor) DO NOTHING
        RETURNING idfornecedor INTO novo_id;
        EXIT WHEN FOUND;
    END LOOP;

    UPDATE public.produtos_filial
    SET idfornecedor = novo_id
    WHERE filial_id = NEW.filial_id AND produto_id = NEW.produto_id;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_gerar_fornecedor_produto ON public.produtos_filial;
CREATE TRIGGER trg_gerar_fornecedor_produto
AFTER INSERT ON public.produtos_filial
FOR EACH ROW
WHEN (NEW.idfornecedor IS NULL)
EXECUTE FUNCTION public.gerar_fornecedor_produto();
COMMIT;
