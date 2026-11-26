-- 03_transformacoes
-- Nome: Equipe CoreData (Ana Júlia Pantoja Chagas e Rafaela da Silva Tavares)
-- Parte 3: Transformações de Dados e Trigger (PostgreSQL)

-- ---------------------------------------------------------------------
-- Interpretação adotada para "mais de 10 vezes no período":
-- Interpretamos "mais de 10 vezes" como a soma da quantidade requisitada
-- (SUM(pc.qtde_pedida) > 10) por produto e data de solicitação no período,
-- alinhado ao exemplo esperado do enunciado ("12345 - Detergente | 15 | 01/01/2025"),
-- em que a coluna "Qtde Requisitada" exibe o total de unidades pedidas (15).
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_produtos_requisitados(
    p_data_inicio date DEFAULT DATE '2025-01-01',
    p_data_fim    date DEFAULT DATE '2025-03-31'
)
RETURNS TABLE (
    "Produto"          text,
    "Qtde Requisitada" numeric,
    "Data Solicitação" text
)
LANGUAGE sql
AS $$
    SELECT
        CASE
            WHEN NULLIF(TRIM(pc.descricao_produto), '') IS NOT NULL
                THEN pc.produto_id || ' - ' || TRIM(pc.descricao_produto)
            ELSE pc.produto_id
        END AS "Produto",
        SUM(pc.qtde_pedida) AS "Qtde Requisitada",
        TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS "Data Solicitação"
    FROM public.pedido_compra pc
    WHERE pc.data_pedido BETWEEN p_data_inicio AND p_data_fim
    GROUP BY pc.produto_id, pc.descricao_produto, pc.data_pedido
    HAVING SUM(pc.qtde_pedida) > 10
    ORDER BY pc.data_pedido, pc.produto_id;
$$;

-- Execução direta da consulta transformada
SELECT * FROM public.fn_produtos_requisitados ();

-- ---------------------------------------------------------------------
-- 3.4 Trigger que gera automaticamente um novo idfornecedor numérico na
--     tabela produtos_filial relacionado à tabela fornecedor quando
--     idfornecedor for informado como NULL na inserção.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_gerar_idfornecedor_produto()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_novo_id integer;
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        INSERT INTO public.fornecedor (codigo_origem, razao_social)
        VALUES (
            'AUTO-' || NEW.produto_id || '-F' || NEW.filial_id,
            'Fornecedor Automático - ' || NEW.produto_id
        )
        RETURNING idfornecedor INTO v_novo_id;

        NEW.idfornecedor := v_novo_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gerar_idfornecedor_produto ON public.produtos_filial;

CREATE TRIGGER trg_gerar_idfornecedor_produto
BEFORE INSERT ON public.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION public.fn_gerar_idfornecedor_produto();