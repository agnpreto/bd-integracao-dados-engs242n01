# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

**Objetivo da reunião:** o cliente sair confiando que os dados de fevereiro/2025 no banco são os mesmos do sistema dele, e sabendo quais pontos ainda dependem de uma decisão dele.

**Números de fevereiro hoje no banco** (para abrir a reunião): 14 linhas de venda, 14 produtos, 173,22 unidades, **R$ 14.093,17**. Desse total, **6 dos 14 produtos (R$ 3.241,24, ou 23%) não existem no cadastro de produtos**, o que já mostra por que a validação é necessária.

## 1. Pontos a validar

**1. O que significa "fevereiro".**
- A data da venda é `data_emissao`? Há venda cancelada, devolvida ou estornada que deveria sair do total?
- O mês deve considerar a data do pedido, da entrega ou da nota, no caso das compras?

**2. Totais do mês, para o cliente comparar com o ERP ou o fechamento de caixa.**
- Quantidade de vendas, unidades e R$ por filial, por dia e por produto (consultas A1 a A3).
- Pedidos e entradas do mês, em quantidade e em R$ (A3 e A4).

**3. Cadastro de produtos e filiais.**
- Os produtos P21 a P28 são vendidos mas não estão em `produtos_filial` (E01). Eles existem? Devem entrar no cadastro?
- As filiais 2 e 3 aparecem nas vendas, mas não no cadastro (E02). São filiais reais?

**4. Preços e custos.**
- O preço vendido quase nunca é o preço de venda cadastrado (E17). É promoção ou o cadastro está desatualizado?
- O que é `preco_unitario`? Ele não bate nem com o preço de compra nem com o de venda (E16).
- Quatro produtos têm preço de venda menor que o de compra (E15): é erro ou liquidação?
- Os preços de P21 a P28 repetem exatamente os de P13 a P20 (E04). Foi copiado?

**5. Quantidades e unidades.** Cinco vendas têm quantidade fracionada (38,6; 20,04; 2,86; 37,11; 3,11) em unidade "UN" (E03). A unidade correta é kg? A quantidade está errada?

**6. Compras.**
- 11 pedidos estão sem ordem de compra (E06), e com isso não se ligam a nenhuma entrada.
- Nove pedidos (21 a 29) repetem pedidos anteriores (E07). Foram lançados duas vezes?
- Em 20 pedidos a data de entrega é anterior à data do pedido (E08).
- O fornecedor do pedido não é o fornecedor cadastrado no produto (E14). Qual vale?

**7. Entradas de mercadoria.**
- As notas NFE19 e NFE20 apontam para ordens de compra que não existem (E09). Os pedidos 19 e 20 deveriam ter ordem 19 e 20?
- 9 entradas têm data anterior ao pedido (E10) e 7 receberam mais do que foi pedido (E11).
- A quantidade "entregue" no pedido não bate com a "recebida" na nota em 18 itens (E12), nem o custo com o preço do pedido (E13).

**8. Estoque.** De qual data é o estoque do cadastro? Três vendas são maiores que o estoque atual (E18).

**9. Uso dos dados.** Que relatórios e decisões vão depender destes números, e que diferença o cliente aceita entre o nosso total e o dele (critério de aceite).

## 2. Técnicas para garantir exatidão e precisão

**Exatidão (os dados estão certos?)**
- **Conciliação de totais:** o cliente tira do sistema dele o total de fevereiro (quantidade e R$, por dia e por filial) e comparamos com A1 e A2. Qualquer diferença vira uma lista a investigar.
- **Conferência por amostragem:** sorteamos algumas linhas (por exemplo 10 vendas e 5 entradas) e o cliente confere cada uma contra o documento de origem (cupom, nota fiscal, pedido).
- **Regras de negócio escritas em SQL:** datas coerentes (entrega depois do pedido), quantidade recebida não maior que a pedida, preço de venda maior que o de compra. Cada regra é uma consulta (bloco C), e o resultado esperado é zero linhas.
- **Integridade entre tabelas:** todo produto vendido existe no cadastro, toda entrada tem pedido, todo pedido tem fornecedor existente.
- **Duplicidades:** buscar linhas repetidas por chave de negócio (produto, datas, preço), não só pela chave técnica.
- **Valores atípicos:** quantidades e preços muito fora do padrão, e valores repetidos demais (o mesmo horário em todas as vendas, o mesmo preço em produtos diferentes).

**Precisão (os números estão exatos?)**
- **Tipos corretos:** dinheiro e quantidade em `numeric` (decimal), não em `float`, para não acumular erro de arredondamento. Datas em `date`, hora em `time`.
- **Conferência da importação:** contagem de linhas planilha x banco e comparação de somas (quantidade e R$) nas duas pontas.
- **Importação repetível:** o script limpa e recarrega; rodar de novo dá o mesmo resultado. Qualquer correção acordada com o cliente é refeita do zero e conferida pela mesma tabela.
- **Não corrigir em silêncio:** erro de dado do cliente não é "arrumado" por nós. Ele é listado, o cliente decide e a decisão fica registrada.

**Fechamento**
- Os pontos da reunião e as decisões do cliente ficam numa ata. A validação só é dada como concluída quando as consultas de erro retornam zero ou cada linha restante tem uma justificativa aceita pelo cliente.

## 3. Consultas preparadas para a reunião

Todas estão em `sql/04_validacao.sql`.

| Bloco | Consultas | O que mostram |
| --- | --- | --- |
| A | A1, A2 | Vendas de fevereiro por filial e por dia: linhas, unidades e R$ |
| A | A3, A4 | Pedidos e entradas de fevereiro: quantidades e valores |
| A | A5 | Pedidos de fevereiro sem nenhuma entrada, para o cliente confirmar se a mercadoria não chegou |
| B | B1, B2 | Linhas no banco x planilha (20, 20, 29, 20, 33) e se alguma data ficou vazia |
| C | E01 a E18 | Uma consulta por erro, listando as linhas com problema |
| D | Resumo | Todos os erros numa tabela só, com tipo e quantidade (para abrir ou fechar a reunião) |

A consulta de produto x mês (2.1) está em `sql/02_consultas.sql` e serve de base para o cliente conferir produto por produto.

## Erros encontrados nos dados

**Tipo:** *ERRO* = não pode acontecer; *CONFIRMAR* = pode ter explicação de negócio, depende do cliente.

| Cód. | Tipo | Tabela | Problema | Qtd | Consulta que mostra |
| --- | --- | --- | --- | --- | --- |
| E01 | ERRO | venda | Venda de produto que não existe em `produtos_filial` (P21 a P28) | 13 | E01 |
| E02 | ERRO | venda | Vendas em filiais 2 e 3, que não existem no cadastro | 4 | E02 |
| E03 | ERRO | venda | Quantidade fracionada com unidade UN | 5 | E03 |
| E04 | CONFIRMAR | venda | Mesmo valor unitário em produtos diferentes (P21 a P28 repetem P13 a P20) | 21 | E04 |
| E05 | CONFIRMAR | venda | Horário `08:00:00` em todas as vendas | 33 | E05 |
| E06 | ERRO | pedido_compra | Pedido sem ordem de compra (`ordem_compra = 0`) | 11 | E06 |
| E07 | ERRO | pedido_compra | Pedidos duplicados (21 a 29 repetem 12 a 20, com ordem 0 e outra quantidade) | 9 | E07 |
| E08 | ERRO | pedido_compra | Data de entrega anterior à data do pedido | 20 | E08 |
| E09 | ERRO | entradas_mercadoria | Entrada sem pedido: NFE19 e NFE20 apontam para ordens inexistentes | 2 | E09 |
| E10 | ERRO | entradas_mercadoria | Mercadoria recebida antes de o pedido ser feito | 9 | E10 |
| E11 | ERRO | entradas_mercadoria | Quantidade recebida maior que a pedida | 7 | E11 |
| E12 | ERRO | pedido x entrada | Quantidade entregue no pedido diferente da recebida na entrada | 18 | E12 |
| E13 | CONFIRMAR | pedido x entrada | Custo da entrada diferente do preço do pedido | 18 | E13 |
| E14 | ERRO | pedido x produto | Fornecedor do pedido diferente do fornecedor do produto | 22 | E14 |
| E15 | ERRO | produtos_filial | Preço de venda menor que o de compra | 4 | E15 |
| E16 | CONFIRMAR | produtos_filial | `preco_unitario` sem relação com preço de compra nem de venda | 20 | E16 |
| E17 | CONFIRMAR | venda x produto | Preço vendido diferente do preço de venda cadastrado | 20 | E17 |
| E18 | CONFIRMAR | venda x produto | Venda maior que o estoque atual | 3 | E18 |
| E19 | ERRO | planilha (pedido_compra) | 11 colunas sem título (M a W) com dados em 9 linhas (pedidos 21 a 29); na cópia, P19 e P20 trazem quantidade pedida 40 e 86, mas os pedidos 19 e 20 têm 20 e 25 nas colunas normais | 9 linhas | Planilha (ver abaixo) |
| E20 | ERRO | planilha (produtos_filial, fornecedor) | Código do fornecedor como texto (`F8`), mas pedido_compra usa número e o DDL pedia `int4` | 40 linhas | Planilha |
| E21 | ERRO | planilha (produtos_filial) | Coluna chamada `idproduto`; nas outras abas é `produto_id` | 1 coluna | Planilha |

Os erros E19 a E21 estão na planilha e não chegam ao banco (o script trata os três), por isso não têm consulta SQL. Para mostrá-los:

```python
import pandas as pd
p = pd.read_excel("dados/base_teste.xlsx", sheet_name="pedido_compra")
extras = p.iloc[:, 12:]                                   # E19: colunas M a W
print(extras.shape[1], "colunas extras;", int(extras.notna().any(axis=1).sum()), "linhas com dados")
pf = pd.read_excel("dados/base_teste.xlsx", sheet_name="produtos_filial")
print(pf.columns.tolist(), pf["idfornecedor"].head(3).tolist())   # E20 e E21
```

**Erros do DDL e do script** (que também faziam parte do material com erros) estão em `docs/parte1_importacao.md`.

**Ressalva sobre E06 e E09.** Os pedidos 19 e 20 têm `ordem_compra = 0`, mas existem entradas para as ordens 19 e 20. A hipótese mais provável é que a ordem foi digitada errada nesses dois pedidos. Por isso, na consulta 2.2 eles aparecem como "não recebidos". Isso precisa ser confirmado com o cliente antes de tratar a lista como definitiva.
