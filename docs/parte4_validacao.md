# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

O objetivo da reunião é o cliente sair dela sabendo três coisas:

- os dados de fevereiro que estão no banco são os mesmos da planilha que ele enviou;
- os totais batem com os controles dele;
- cada inconsistência encontrada foi mostrada e tem uma decisão sobre o que fazer.

As consultas citadas estão em [`sql/04_validacao.sql`](../sql/04_validacao.sql). O bloco A traz o fechamento do mês e o bloco B, um erro por consulta.

## 1. Pontos a validar

### 1.1 A carga está completa

| O que mostrar | Consulta | Resultado |
| --- | --- | --- |
| Linhas no banco × linhas na planilha, por tabela | A1 | venda 33/33, pedido_compra 29/29, entradas_mercadoria 20/20, produtos_filial 20/20, fornecedor 20/20 |
| Quantas vendas são de fevereiro e quantas ficam fora | A2 | Janeiro: 12, fevereiro: 14, março: 7. Só fevereiro entra no fechamento |

### 1.2 Os números de fevereiro batem com os do cliente

| O que mostrar | Consulta | Resultado |
| --- | --- | --- |
| Faturamento do mês por filial e total | A3 | Filial 1: 13 vendas, R$ 13.545,64. Filial 2: 1 venda, R$ 547,53. **Total: 14 vendas, R$ 14.093,17** |
| Vendas por produto (quantidade e R$) | A4 / Parte 2.1 | 14 produtos. 6 deles (P22 a P27) não têm cadastro e somam R$ 3.241,24 do total |
| Pedidos de compra do mês: quantidade pedida × recebida | A5 | 17 pedidos: 5 recebidos em parte, 3 recebidos a mais e 9 sem nenhum recebimento |
| Notas fiscais de entrada do mês | A6 | 10 notas |

O cliente confere esses totais com o relatório do sistema de origem, com o faturamento das notas de saída e com o caixa. Uma diferença aqui pesa mais do que qualquer outro ponto.

### 1.3 Decisões que só o cliente pode tomar

São as inconsistências da seção "Erros encontrados nos dados". Para cada uma, o cliente diz se o dado está certo (é uma regra do negócio que não conhecíamos), se deve ser corrigido na origem ou se deve ser corrigido no banco. As mais importantes para fevereiro:

1. **Vendas de produtos sem cadastro (P22 a P27)** e **venda na filial 2**, que não tem produtos cadastrados. Os produtos existem e faltam no cadastro, ou as vendas estão erradas? Elas têm a mesma data e o mesmo preço das vendas 13 a 20 (consulta B5) e parecem cópias.
2. **Pedidos duplicados (21 a 29).** Repetem produto, data e preço dos pedidos 12 a 20, sem ordem de compra. São pedidos complementares ou duplicidade? Se forem duplicidade, inflam as quantidades requisitadas.
3. **Ordem de compra dos pedidos 19 e 20.** Estão com ordem 0, mas existem as notas NFE19 e NFE20 com ordem 19 e 20 para os mesmos produtos. É bem provável que a ordem não tenha sido preenchida no pedido.
4. **Datas impossíveis.** Entrega antes do pedido e mercadoria recebida antes de ser pedida.
5. **Divergência de quantidades e preços** entre o pedido, a nota fiscal e o cadastro.
6. **Preço de compra maior que o de venda** em 4 produtos, o que significa margem negativa.

## 2. Técnicas para garantir exatidão e precisão

1. **Reconciliação de contagens.** O número de linhas de cada tabela no banco é comparado com o número de linhas da planilha (A1). Não se confia na mensagem do script de importação: na primeira execução ele disse "33 registros inseridos" com 0 vendas gravadas (ver Parte 1).
2. **Reconciliação de totais.** A soma de quantidade e de valor do mês (A3/A4) é comparada com um total que o cliente calcula pelo sistema dele. Um registro perdido ou duplicado aparece como diferença de valor.
3. **Integridade referencial.** Toda venda precisa ter produto cadastrado na filial (B1, B2). Toda entrada precisa de um pedido (B14). Todo produto precisa ter fornecedor (B20). O DDL não tem chaves estrangeiras, então essas consultas fazem esse papel.
4. **Regras de negócio.** Datas em ordem cronológica (B8, B16), quantidades coerentes (B13, B15), quantidade inteira para unidade `UN` (B3) e preço de compra menor que o de venda (B18).
5. **Detecção de duplicidade.** Registros que repetem os mesmos valores com outra chave (B5, B10).
6. **Consistência entre tabelas.** O mesmo dado gravado em dois lugares precisa ser igual: o preço de compra no pedido, na nota e no cadastro (B17, B19), e o fornecedor no pedido e no cadastro (B11).
7. **Precisão numérica.** Os valores em R$ são somados primeiro e arredondados para 2 casas só no final (`ROUND(SUM(...)::numeric, 2)`), para não acumular erro de arredondamento.
8. **Amostragem com o cliente.** Para cada erro, mostrar 2 ou 3 linhas lado a lado com o documento de origem (nota fiscal, pedido) e confirmar qual dos dois está certo.
9. **Reexecução.** As consultas ficam salvas e podem ser rodadas de novo depois de cada correção, até o bloco B voltar vazio ou ficar só com o que o cliente aceitou como regra.

## 3. Consultas preparadas para a reunião

### Bloco A: fechamento do mês

| Consulta | O que mostra |
| --- | --- |
| A1 | Linhas por tabela, para comparar com a planilha |
| A2 | Quantidade de vendas por mês |
| A3 | Vendas de fevereiro por filial (quantidade e R$) |
| A4 | Vendas de fevereiro por produto (igual à Parte 2.1) |
| A5 | Pedidos de fevereiro com a quantidade pedida e a recebida |
| A6 | Notas fiscais de entrada de fevereiro e o valor recebido |

### Bloco B: um erro por consulta

Cada consulta devolve só as linhas com problema. A tabela abaixo traz o resultado na base inteira.

## Erros encontrados nos dados

| # | Tabela | Problema | Quantidade | Consulta |
| --- | --- | --- | --- | --- |
| 1 | venda | Produto vendido que não existe no cadastro da filial (P21 a P28) | 13 vendas (6 em fev.) | B1 |
| 2 | venda | Venda em filial sem produtos cadastrados (filiais 2 e 3) | 4 vendas (1 em fev.) | B2 |
| 3 | venda | Quantidade fracionada vendida em unidade `UN` | 5 vendas (2 em fev.) | B3 |
| 4 | venda | Preço praticado diferente do preço de venda do cadastro | 20 vendas (todas as que têm cadastro) | B4 |
| 5 | venda | Vendas "copiadas": mesmo dia e preço de outra venda, com outro produto | 13 vendas | B5 |
| 6 | venda | Todas as vendas às 08:00:00 e com item 1 (horário padrão, não o real) | 33 vendas | B6 |
| 7 | venda | Quantidade vendida maior que o estoque cadastrado | 3 vendas | B7 |
| 8 | pedido_compra | Data de entrega anterior à data do pedido | 20 pedidos | B8 |
| 9 | pedido_compra | Pedido sem ordem de compra (`ordem_compra = 0`) | 11 pedidos | B9 |
| 10 | pedido_compra | Pedidos duplicados (21 a 29 repetem 12 a 20) | 9 pares | B10 |
| 11 | pedido_compra | Fornecedor do pedido diferente do fornecedor do produto no cadastro | 22 pedidos | B11 |
| 12 | pedido_compra | Data de entrega preenchida, mas nada entregue | 11 pedidos | B12 |
| 13 | pedido_compra | `qtde_entregue` diferente do total recebido nas notas fiscais | 18 pedidos | B13 |
| 14 | entradas_mercadoria | Nota fiscal sem pedido correspondente (ordens 19 e 20) | 2 notas | B14 |
| 15 | entradas_mercadoria | Quantidade recebida maior que a pedida | 7 notas | B15 |
| 16 | entradas_mercadoria | Mercadoria recebida antes de ser pedida | 9 notas | B16 |
| 17 | entradas_mercadoria | Custo na nota diferente do preço de compra do pedido | 18 notas | B17 |
| 18 | produtos_filial | Preço de compra maior que o preço de venda (P1, P8, P15, P18) | 4 produtos | B18 |
| 19 | produtos_filial | Preço de compra do cadastro diferente do preço do pedido | 29 pedidos | B19 |
| 20 | fornecedor | Fornecedor com mais de um produto (F7, F18, F19) e sem produto (F14, F15, F16). Não é necessariamente erro; o cliente confirma | 6 fornecedores | B21 |
| 21 | planilha | 11 colunas sem cabeçalho na aba `pedido_compra`, com dados nas linhas 22 a 30. Não foram importadas; ver Parte 1 | 9 linhas | — |

Todo `idfornecedor` usado em `produtos_filial` existe na tabela `fornecedor` (B20 volta vazio).
