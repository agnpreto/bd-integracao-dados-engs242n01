# Parte 4 — Validação dos dados de fevereiro de 2025

## Roteiro da reunião

1. Confirmar o recorte de 01 a 28 de fevereiro, as filiais e as regras de devoluções, descontos e arredondamento do relatório do cliente.
2. Comparar o relatório de vendas por dia e filial com o banco. O arquivo apresenta **14 linhas de venda, 14 produtos, 173,22 na quantidade e R$ 14.093,17** no mês. Se houver divergência, recalcular uma amostra desde a planilha até o total.
3. Validar as compras usando a ordem, a filial, o produto e as notas fiscais. Fevereiro tem oito pedidos com ordem positiva, cinco com saldo pendente e três com entradas acima da quantidade pedida. Outros nove pedidos do mês, somando 86 unidades, têm ordem zero.
4. Conferir as duas notas que ficaram sem pedido correspondente e o bloco extra sobre as ordens 19 e 20. Pedir os registros do sistema de origem para confirmar os vínculos e as quantidades antes de atualizar o banco.
5. Confirmar se o cadastro de catálogo está completo e se a unidade de medida `UN` admite quantidade fracionária. Verificar se a coluna `data_entrega` indica previsão ou recebimento efetivo.
6. Registrar, por ocorrência, chave, linha do Excel, consulta, decisão, responsável e prazo. Rodar novamente as consultas após a confirmação das correções.

## Técnicas de conferência

- Reconciliar as contagens por aba com o banco e revisar a auditoria por linha. As cinco contagens totalizaram 122.
- Conferir os agrupamentos por dia, filial e produto com um relatório independente para o mesmo período. Somar os valores com aritmética decimal e arredondar o resultado final para centavos.
- Selecionar amostras de vendas, compras parciais, recebimentos acima do pedido e entradas sem vínculo. Verificar quantidade, preço, data, identificação e NF-e.
- Mostrar ao cliente a diferença entre a quantidade entregue no pedido e a quantidade recebida nas notas. Confirmar qual relatório e qual data de corte orientam a operação.
- Recalcular a frequência de compra por pedidos distintos. A maior frequência em fevereiro foi de duas requisições por produto, então o filtro “mais de 10 vezes” retornou zero linhas.

## Ocorrências observadas na planilha

As contagens abrangem toda a base, salvo indicação de fevereiro. Uma mesma linha pode aparecer em mais de uma verificação.

| Ocorrência | Quantidade | Identificação ou evidência | Consulta |
| --- | ---: | --- | --- |
| Conteúdo adicional sem cabeçalho em pedidos | 9 linhas | Excel `M22:W30`. Sete blocos remetem às ordens 12 a 18, já presentes no bloco com cabeçalho. Os blocos das ordens 19 e 20 ficam como evidência para o cliente. | V2 e V12 |
| Pedido com ordem zero e entrega registrada em quantidade zero | 11 pedidos | Pedidos 19 a 29. Nove pedidos são de fevereiro. Sem uma ordem válida, a entrada física permanece sem confirmação. | V5 e V13 |
| Entrada sem pedido correspondente | 2 notas | `NFE19` e `NFE20`. O bloco sem cabeçalho tem referências a essas ordens. | V5 e V12 |
| Pedido com data de entrega anterior à solicitação | 20 pedidos | Exemplos `3`, `6` e `7`. Convém confirmar o significado da data com o cliente. | V6 |
| Entrada com data anterior à solicitação associada | 9 notas | Ordens `6`, `7`, `11`, `12`, `13`, `14`, `15`, `16` e `18`. | V6 |
| Quantidade entregue no pedido diverge das notas | 18 ordens vinculadas | Na ordem 1, o pedido indica 10 entregues e a nota registra 77. | V10 |
| Quantidade recebida acima da pedida | 7 das 18 ordens vinculadas | Ordens `2`, `3`, `5`, `7`, `11`, `15` e `16`. Em fevereiro, as ordens `11`, `15` e `16` aparecem no fechamento. | V7 e V10 |
| Venda sem produto cadastrado na filial | 13 linhas | Produtos `P21` a `P28`. O cadastro fornecido cobre a filial 1 e os códigos `P1` a `P20`. | V5 |
| Venda com quantidade fracionária em `UN` | 5 linhas | Vendas `4`, `8`, `12`, `16` e `26`. Confirmar a regra de unidade com o cliente. | V11 |

A Parte 2 retorna, em toda a base, dez grupos com recebimento parcial e 11 requisições sem ordem vinculada. Os registros sem ordem são apresentados por pedido para evitar agrupá-los como se pertencessem à mesma compra. O saldo das ordens usa as quantidades registradas nas notas. O campo `qtde_pendente` do pedido vem da diferença entre quantidade solicitada e entregue informada no próprio pedido.

## Consultas preparadas para a reunião

| Consulta | O que apresenta |
| --- | --- |
| V1 e V2 | Contagens da carga e rastreabilidade de células sem cabeçalho, erros e duplicidades. |
| V3 e V4 | Totais de vendas e verificação de quantidades, preços, custos e estoques inválidos ou que precisam de contexto. |
| V5 e V6 | Referências ausentes e datas incoerentes. |
| V7 | Saldo das ordens solicitadas em fevereiro com notas registradas até o fechamento. |
| V8 e V9 | Descrições divergentes e ordens compartilhadas que possam exigir regra de alocação. |
| V10 e V11 | Divergência entre pedido e nota, excesso recebido e venda fracionada em `UN`. |
| V12 e V13 | Bloco auxiliar sem cabeçalho e requisições sem ordem válida em fevereiro. |
| V14 | Frequência de requisições e explicação do resultado vazio do filtro da Parte 3. |

As consultas V1 a V14 estão em `sql/04_validacao.sql`. As verificações V4, V8 e V9 retornaram zero ocorrências para esta planilha.
