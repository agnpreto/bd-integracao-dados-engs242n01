-- 03_transformacoes
-- Nome: Merivaldo Ferreira de Aquino Filho
-- Parte 3: Transformações de dados
USE loja_integracao;

-- 1) e 2) Pedidos de compra: concatena produto_id + descricao_produto no formato
--         "P12 - Detergente" (quando há descrição) e converte datas para DD/MM/YYYY.
SELECT
    CONCAT_WS(' - ', pc.produto_id, NULLIF(TRIM(pc.descricao_produto), '')) AS produto,
    pc.qtde_pedida AS `Qtde Requisitada`,
    DATE_FORMAT(pc.data_pedido, '%d/%m/%Y') AS `Data Solicitação`,
    DATE_FORMAT(pc.data_entrega, '%d/%m/%Y') AS `Data Entrega`
FROM pedido_compra pc
ORDER BY pc.data_pedido, pc.produto_id;

-- 1) e 2) Vendas: mesma concatenação, usando a descrição do cadastro de produtos.
SELECT
    CONCAT_WS(' - ', v.produto_id, NULLIF(TRIM(pf.descricao), '')) AS produto,
    v.qtde_vendida AS `Qtde Vendida`,
    ROUND(v.qtde_vendida * v.valor_unitario, 2) AS `Valor (R$)`,
    DATE_FORMAT(v.data_emissao, '%d/%m/%Y') AS `Data Emissão`
FROM venda v
LEFT JOIN (
    SELECT produto_id, MIN(descricao) AS descricao
    FROM produtos_filial
    GROUP BY produto_id
) pf ON pf.produto_id = v.produto_id
ORDER BY v.data_emissao, v.produto_id;

-- 3) Somente os produtos requisitados mais de 10 vezes no período.
--    INTERPRETAÇÃO ADOTADA: "mais de 10 vezes" significa quantidade total
--    requisitada (soma de qtde_pedida) maior que 10 em fevereiro/2025. O exemplo
--    do enunciado mostra "Qtde Requisitada 15", ou seja, 15 unidades, não 15 pedidos.
--    Pela contagem de pedidos, nenhum produto passa de 2 requisições no mês.
SELECT
    CONCAT_WS(' - ', pc.produto_id, NULLIF(TRIM(pc.descricao_produto), '')) AS produto,
    SUM(pc.qtde_pedida) AS `Qtde Requisitada`,
    DATE_FORMAT(MIN(pc.data_pedido), '%d/%m/%Y') AS `Data Solicitação`
FROM pedido_compra pc
WHERE pc.data_pedido >= '2025-02-01'
  AND pc.data_pedido <  '2025-03-01'
GROUP BY pc.produto_id, pc.descricao_produto
HAVING SUM(pc.qtde_pedida) > 10
ORDER BY `Qtde Requisitada` DESC;

-- 4) Trigger: gera automaticamente um novo idfornecedor quando o produto é
--    inserido sem fornecedor. A parte numérica é o maior código atual + 1 e o
--    registro é criado em fornecedor para manter o relacionamento por FK.
DROP TRIGGER IF EXISTS trg_gera_idfornecedor;
DELIMITER //
CREATE TRIGGER trg_gera_idfornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
BEGIN
    DECLARE v_novo VARCHAR(25);

    IF NEW.idfornecedor IS NULL OR TRIM(NEW.idfornecedor) = '' THEN
        SELECT CONCAT(
                   'F',
                   COALESCE(MAX(CAST(REGEXP_REPLACE(idfornecedor, '[^0-9]', '') AS UNSIGNED)), 0) + 1
               )
          INTO v_novo
          FROM fornecedor;

        INSERT INTO fornecedor (idfornecedor, razao_social)
        VALUES (v_novo, CONCAT('Fornecedor gerado automaticamente ', v_novo));

        SET NEW.idfornecedor = v_novo;
    END IF;
END//
DELIMITER ;

-- Teste opcional da trigger (descomente para validar no DBeaver):
-- INSERT INTO produtos_filial
--     (filial_id, produto_id, descricao, estoque, idfornecedor)
-- VALUES (99, 'P99', 'Produto teste trigger', 0, NULL);
-- SELECT idfornecedor, razao_social FROM fornecedor WHERE idfornecedor = 'F21';
-- SELECT produto_id, idfornecedor FROM produtos_filial WHERE produto_id = 'P99';
-- DELETE FROM produtos_filial WHERE produto_id = 'P99';
-- DELETE FROM fornecedor WHERE idfornecedor = 'F21';
