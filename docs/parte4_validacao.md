# Parte 4: Roteiro de validação com o cliente (fevereiro/2025)

Equipe **CoreData**. Todas as consultas estão em `sql/04_validacao.sql`; o código de cada uma (R1, E1...) aparece nas tabelas abaixo.

**Abertura da reunião (o que dizer ao cliente):** "Carregamos a planilha que vocês enviaram sem alterar nenhum dado. Todas as linhas entraram. Hoje vamos confirmar com vocês os totais de fevereiro e decidir juntos o que fazer com as inconsistências que encontramos, porque só vocês sabem qual dos dois valores está certo."

## 1. Pontos a validar

1. **Completude da carga:** o banco tem as mesmas linhas da planilha (fornecedor 20, produtos 20, pedidos 29, entradas 20, vendas 33). Consulta R1.
2. **Totais de fevereiro/2025:** nº de vendas, quantidade total e valor total em R$, contra o relatório do sistema do cliente. Consultas R2 e R3. O banco tem 14 linhas de venda em fevereiro, 173,22 unidades e R$ 14.093,17.
3. **Período:** a base traz vendas de janeiro (12) e março (7), além de fevereiro (14). Confirmar se o cliente quer só fevereiro no relatório e se as demais linhas são do mesmo lote.
4. **Cadastro de produtos:** os produtos P21 a P28 vendem, mas não existem no cadastro. Perguntar se são produtos novos, de outra filial ou erro de digitação. Em fevereiro, isso afeta 6 das 14 linhas de venda. E1 e E2.
5. **Filiais:** o cadastro só tem a filial 1, mas há vendas nas filiais 2 e 3. Perguntar se a lista de produtos delas existe. E2.
6. **Preços:** o preço vendido não coincide com o preço de venda do cadastro em nenhuma das 20 vendas com cadastro (E4); em 4 produtos o preço de venda é menor que o de compra (E16); e `preco_unitario` não bate com nenhum dos outros dois (E17). Perguntar qual é o preço oficial e o que significa `preco_unitario`.
7. **Quantidades fracionadas em UN:** 5 vendas (ex.: 38,6 UN). Perguntar se a unidade está errada (kg?) ou se a quantidade está errada. E3.
8. **Ciclo de compra:** pedidos sem `ordem_compra` (E7), entregas anteriores ao pedido (E8), pedidos repetidos (E9), entradas sem pedido (E11), recebido maior que o pedido (E12), quantidade e preço do pedido diferentes da nota (E13, E14). Perguntar qual fonte vale quando pedido e nota divergem.
9. **Fornecedores:** o fornecedor do pedido é diferente do fornecedor do cadastro do produto em 22 pedidos (E10). Perguntar qual é o correto.
10. **Resultado das duas consultas pedidas:** conferir com o cliente a lista de "requisitados e não recebidos" (11 pedidos, 9 produtos; consulta 2.2 de `02_consultas.sql`) e o total vendido por produto em fevereiro (consulta 2.1), por amostragem.

## 2. Técnicas para garantir exatidão e precisão

- **Reconciliação de contagem e de soma (totais de controle):** linhas por tabela e soma de quantidade e de valor em R$, comparadas com o sistema de origem. Qualquer diferença é investigada antes de seguir.
- **Amostragem manual:** o cliente escolhe algumas vendas e pedidos e confere, linha a linha, com o documento original (nota, cupom).
- **Tipos exatos:** `numeric` em vez de `float` em dinheiro e quantidade (evita 0,1 + 0,2 ≠ 0,3), `date` e `time` em vez de texto.
- **Integridade referencial e `CHECK`:** chaves estrangeiras e restrições impedem lixo novo (produto inexistente, valor negativo, fornecedor inexistente).
- **Verificações de consistência cruzada:** consultas que comparam tabelas entre si (pedido x entrada, venda x cadastro, preço do pedido x custo da nota).
- **Regras de negócio como consulta:** datas em ordem lógica, recebido não maior que pedido, chave única sem duplicata.
- **Detecção de duplicatas e de valores repetidos suspeitos:** E9 e E5.
- **Carga atômica e repetível:** o script grava tudo ou nada e pode ser rodado de novo com o mesmo resultado.
- **Dados originais preservados:** nada foi corrigido em silêncio; a planilha original não foi alterada. Cada correção é decisão registrada com o cliente.
- **Registro:** a lista de erros desta página, com a consulta que reproduz cada um.

## 3. Consultas preparadas para a reunião

(Arquivo `sql/04_validacao.sql`.)

| Consulta | O que mostra | Para que serve na reunião |
| --- | --- | --- |
| R1 | Linhas no banco x linhas na planilha, por tabela | Provar que a carga está completa |
| R2 | Totais de fevereiro: linhas, produtos, quantidade, valor, primeira e última venda | O cliente confere contra o sistema dele |
| R3 | Vendas por mês | Mostrar que a base tem janeiro e março |
| E1 a E6 | Problemas em `venda` | Decidir cadastro, filial, unidade e preço |
| E7 a E10 | Problemas em `pedido_compra` | Decidir ordem de compra, datas, duplicatas e fornecedor |
| E11 a E15 | Cruzamento pedido x entrada | Decidir qual fonte vale |
| E16 a E18 | Problemas em `produtos_filial` e `fornecedor` | Decidir preço e fornecedor |
| Resumo final | Quantidade de linhas com erro por verificação | Fechar a reunião com a lista de pendências |

Também ficam prontas as consultas 2.1 e 2.2 (`sql/02_consultas.sql`) e a função `fn_produtos_requisitados` (`sql/03_transformacoes.sql`).

## Erros encontrados nos dados

"Antes" é o resultado de `sql/04_validacao.sql` logo após a importação. "Depois" é o resultado da mesma consulta após `sql/05_correcoes.sql`. A unidade é a linha devolvida (nas verificações E5 e E9, o grupo).

| Tabela | Problema | Antes | Depois | Consulta | Situação |
| --- | --- | --- | --- | --- | --- |
| venda | Produto vendido que não existe no cadastro (P21 a P28) | 13 (6 em fev.) | 0 | E1 | Corrigido (C2): cadastro provisório criado |
| venda | Venda em filial sem cadastro (filiais 2 e 3) | 4 | 0 | E2 | Corrigido (C2) |
| venda | Quantidade fracionada em unidade UN (ex.: 38,6) | 5 | 0 | E3 | Corrigido (C3): unidade trocada para KG. **Hipótese a confirmar** |
| venda | Preço vendido diferente do `preco_venda` do cadastro | 20 | 20 | E4 | Não corrigido: depende do cliente |
| venda | Mesmo valor em produtos diferentes (P13 e P21, P14 e P22...) | 8 grupos | 8 | E5 | Não corrigido: depende do cliente |
| venda | Horário (08:00:00) e item (1) iguais em todas as linhas | 33 | 33 | E6 | Não corrigido: não há dado melhor |
| pedido_compra | Sem `ordem_compra` (0) | 11 | 9 | E7 | Corrigido em parte (C1): pedidos 19 e 20 ligados às entradas. Os pedidos 21 a 29 não têm entrada e ficam como "requisitados e não recebidos" |
| pedido_compra | Data de entrega anterior à data do pedido | 20 | 20 | E8 | Não corrigido: não se sabe qual data está errada. Nova regra (C5) impede novos casos |
| pedido_compra | Possível duplicidade: pedidos 21 a 29 repetem produto, datas e preço dos pedidos 12 a 20, com quantidade diferente | 9 grupos | 9 | E9 | Não corrigido: mantidos de propósito, pois são os pedidos sem recebimento da consulta 2.2 |
| pedido_compra | Fornecedor do pedido diferente do fornecedor do cadastro do produto | 22 | 22 | E10 | Não corrigido: o pedido pode usar outro fornecedor |
| pedido_compra | 11 colunas sem cabeçalho (M a W) com 9 linhas de resíduo; falta a coluna `qtde_pendente` | 9 linhas | não importadas | inspeção da planilha | Tratado na importação: colunas ignoradas, `qtde_pendente` calculada |
| entradas_mercadoria | Entrada sem pedido correspondente (NFE19 e NFE20) | 2 | 0 | E11 | Corrigido (C1) |
| pedido x entrada | `qtde_entregue` do pedido diferente de `qtde_recebida` da nota | 18 | 0 | E13 | Corrigido (C4): `qtde_entregue` passa a ser a soma recebida; `qtde_pendente` recalculada |
| entradas_mercadoria | Recebido maior que o pedido | 7 | 8 | E12 | Não corrigido: divergência real (subiu para 8 porque o pedido 19 agora está ligado à NFE19) |
| pedido x entrada | `preco_compra` do pedido diferente do `custo_unitario` da nota | 18 | 20 | E14 | Não corrigido: o preço negociado pode diferir do da nota (subiu para 20 com os pedidos 19 e 20 ligados) |
| pedido x entrada | Entrada com data anterior à do pedido | 9 | 11 | E15 | Não corrigido: depende do cliente (subiu para 11 com os pedidos 19 e 20 ligados) |
| produtos_filial | Preço de venda menor que o preço de compra (P1, P8, P15, P18) | 4 | 4 | E16 | Não corrigido: depende do cliente |
| produtos_filial | `preco_unitario` sem relação com compra ou venda | 20 | 20 | E17 | Não corrigido: depende do cliente |
| fornecedor | Fornecedor sem produto e sem pedido | 0 | 0 | E18 | Sem erro |
| DDL | Erros do DDL do enunciado | ver `docs/parte1_importacao.md` | corrigidos | rodar `01_ddl_enunciado.sql` | Corrigido nos dois DDLs |

## Correções aplicadas (`sql/05_correcoes.sql`)

O script guarda uma cópia do estado original (`bkp_<tabela>`) e registra cada alteração em `correcao_log` (valor antes, valor depois, motivo). Pode ser rodado mais de uma vez sem duplicar alterações (testado).

| Código | O que faz | Linhas |
| --- | --- | --- |
| C1 | Pedidos 19 e 20: `ordem_compra` 0 passa a 19 e 20, igual às notas NFE19 e NFE20 | 2 |
| C2 | Cria o cadastro provisório de 8 combinações filial/produto que existiam só em `venda`, com um fornecedor "A CONFIRMAR". Cria a FK `venda` para `produtos_filial` | 8 |
| C3 | Vendas com quantidade fracionada em UN passam a KG (hipótese, a confirmar) | 5 |
| C4 | `qtde_entregue` do pedido passa a ser a soma recebida nas entradas | 20 |
| C5 | Regra `CHECK` impede novas linhas com data de entrega anterior ao pedido | prevenção |

**Para a reunião:** os itens "Não corrigido" são a pauta com o cliente. Cada um precisa de uma resposta dele (qual preço, qual data, qual fornecedor), porque corrigir por suposição falsificaria o dado.
