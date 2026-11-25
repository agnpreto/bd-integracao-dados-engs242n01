-- 03_transformacoes
-- Nome: Vitor Davi Pereira Soares
-- Banco: PostgreSQL 18, schema integracao.
-- Parte 3: transformações de dados.


-- 3.1 e 3.2 Produto no formato "P1 - Produto 1" e data em DD/MM/YYYY
-- CONCAT_WS ignora valores nulos: sem descrição, mostra só o código, sem " - "
-- sobrando no final ("onde houver" do enunciado).

-- Pedidos de compra
SELECT CONCAT_WS(' - ', produto_id, NULLIF(descricao_produto, '')) AS produto,
       qtde_pedida,
       TO_CHAR(data_pedido, 'DD/MM/YYYY')                        AS data_solicitacao
FROM integracao.pedido_compra;

-- Vendas: a tabela venda não tem descrição, então ela vem do cadastro da filial.
-- Produtos sem cadastro (P21 a P28, ver Parte 4) aparecem só com o código.
SELECT CONCAT_WS(' - ', v.produto_id, pf.descricao) AS produto,
       v.qtde_vendida,
       TO_CHAR(v.data_emissao, 'DD/MM/YYYY')        AS data_venda
FROM integracao.venda v
LEFT JOIN integracao.produtos_filial pf
       ON pf.produto_id = v.produto_id AND pf.filial_id = v.filial_id;

-- Produtos (o cadastro não tem data)
SELECT CONCAT_WS(' - ', produto_id, NULLIF(descricao, '')) AS produto,
       preco_venda
FROM integracao.produtos_filial;


-- 3.3 Produtos requisitados mais de 10 vezes em fevereiro de 2025
-- "Mais de 10 vezes" = mais de 10 unidades pedidas (SUM(qtde_pedida) > 10).
-- Contando pedidos, nenhum produto passaria de 10: cada um tem no máximo 2.
SELECT CONCAT(produto_id, ' - ', descricao_produto) AS "Produto",
       SUM(qtde_pedida)                         AS "Qtde Requisitada",
       TO_CHAR(data_pedido, 'DD/MM/YYYY')       AS "Data Solicitação"
FROM integracao.pedido_compra
WHERE data_pedido BETWEEN '2025-02-01' AND '2025-02-28'
GROUP BY produto_id, descricao_produto, data_pedido
HAVING SUM(qtde_pedida) > 10
ORDER BY data_pedido;


-- 3.4 Trigger: gera um idfornecedor numérico para o produto novo
-- Se o produto for inserido sem idfornecedor, a trigger pega o maior número
-- de fornecedor (F20 -> 20), soma 1, cria o fornecedor F21 e grava esse código
-- no produto. A parte numérica é sequencial; o prefixo "F" mantém o mesmo
-- padrão dos códigos que vieram da planilha (F1 a F20), para o produto se
-- relacionar com a tabela fornecedor. Execute com o usuário dono do schema.

CREATE OR REPLACE FUNCTION integracao.fn_gera_idfornecedor()
RETURNS trigger AS $$
DECLARE
    proximo int;
BEGIN
    IF NEW.idfornecedor IS NULL THEN
        SELECT COALESCE(MAX(REPLACE(idfornecedor, 'F', '')::int), 0) + 1
          INTO proximo
          FROM integracao.fornecedor;

        NEW.idfornecedor := 'F' || proximo;

        INSERT INTO integracao.fornecedor (idfornecedor, razao_social)
        VALUES (NEW.idfornecedor, CONCAT('Fornecedor ', NEW.idfornecedor));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_gera_idfornecedor
BEFORE INSERT ON integracao.produtos_filial
FOR EACH ROW
EXECUTE FUNCTION integracao.fn_gera_idfornecedor();


-- Teste (o ROLLBACK desfaz tudo no final)
BEGIN;
INSERT INTO integracao.produtos_filial (filial_id, produto_id, descricao)
VALUES (1, 'P99', 'Produto teste');

SELECT produto_id, idfornecedor FROM integracao.produtos_filial WHERE produto_id = 'P99';  -- espera F21
SELECT idfornecedor, razao_social FROM integracao.fornecedor WHERE idfornecedor = 'F21';  -- fornecedor criado
ROLLBACK;
