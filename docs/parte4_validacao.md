# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

## 1. Pontos a validar com o cliente

1. **Volume carregado:** confirmar que as 5 tabelas receberam exatamente as linhas da planilha (`20, 20, 33, 29, 20`) e que não houve perda nem duplicação na importação.
2. **Consumo do mês:** apresentar o total vendido em fevereiro/2025 (14 vendas, 173,22 unidades, R$ 14.093,17) e o detalhamento por produto, perguntando se os valores batem com o fechamento do cliente.
3. **Pedidos pendentes:** revisar os produtos requisitados e não recebidos, confirmando se `qtde_entregue = 0` significa realmente "não recebido" e não "informação não preenchida".
4. **Datas:** validar a regra de que a entrega não pode acontecer antes do pedido. Foram encontrados 20 registros com `data_entrega < data_pedido` — é preciso saber se as colunas foram trocadas na origem.
5. **Ordem de compra:** 11 pedidos estão com `ordem_compra = 0` e 2 entradas (ordens 19 e 20) não têm pedido correspondente. Perguntar ao cliente qual é o vínculo correto.
6. **Preços:** 4 produtos têm `preco_venda < preco_compra`, o que gera prejuízo. Confirmar se é erro de digitação ou promoção planejada.
7. **Cadastro de produtos:** 13 vendas referem-se aos códigos `P21` a `P28`, que não existem em `produtos_filial`. Validar se esses produtos precisam ser cadastrados ou se as vendas devem ser reclassificadas.

## 2. Técnicas para garantir exatidão e precisão

- **Reconciliação de contagens:** comparar `COUNT(*)` do banco com o número de linhas de cada aba da planilha.
- **Soma de controle:** totalizar quantidades e valores (`SUM(qtde_vendida)` e `SUM(qtde_vendida * valor_unitario)`) e confrontar com o relatório do cliente.
- **Regras de integridade:** consultas com `WHERE` para detectar datas invertidas, quantidades entregues maiores que as pedidas, preços incoerentes e chaves estrangeiras órfãs (`NOT EXISTS` / `LEFT JOIN ... IS NULL`).
- **Detecção de duplicatas:** `GROUP BY` da chave primária com `HAVING COUNT(*) > 1`.
- **Completeness:** verificar nulos em colunas obrigatórias e códigos fora do padrão (`P1`–`P20`).
- **Rastreabilidade:** cada número apresentado na reunião está associado a uma consulta nomeada em `sql/04_validacao.sql`, para que o cliente possa reproduzir a conferência.

## 3. Consultas preparadas para a reunião

Todas estão em `sql/04_validacao.sql`:

| Consulta | O que mostra |
| --- | --- |
| 1 | Contagem das 5 tabelas — conferência com a planilha |
| 2 | Total de vendas em fevereiro/2025 |
| 3 | Pedidos com data de entrega anterior à data do pedido |
| 4 | Pedidos com `ordem_compra = 0` |
| 5 | Entradas sem pedido correspondente |
| 6 | Produtos com preço de venda menor que o de compra |
| 7 | Vendas de produtos sem cadastro |
| 8 | Pedidos duplicados ou com entrega maior que a requisição |

## Erros encontrados nos dados

| Tabela | Problema | Quantidade | Consulta que mostra |
| --- | --- | --- | --- |
| pedido_compra | `data_entrega` anterior a `data_pedido` | 20 registros | Consulta 3 |
| pedido_compra | `ordem_compra` zerada / ausente | 11 registros | Consulta 4 |
| entradas_mercadoria | Ordem de compra sem pedido (ordens 19 e 20) | 2 registros | Consulta 5 |
| produtos_filial | `preco_venda < preco_compra` (P1, P8, P15, P18) | 4 produtos | Consulta 6 |
| venda | Produtos `P21` a `P28` sem cadastro | 13 linhas / 8 códigos | Consulta 7 |
| pedido_compra | `qtde_entregue > qtde_pedida` | 0 (sem erro) | Consulta 8 |
| pedido_compra | Chave primária duplicada | 0 (sem erro) | Consulta 8 |

Os erros acima são intencionais no material enviado pelo cliente; a validação com ele serve para decidir qual dos lados (planilha, DDL ou regra de negócio) deve ser corrigido antes da carga final.
