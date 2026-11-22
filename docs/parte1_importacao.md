# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

- **Banco:** PostgreSQL 18, schema `integracao` no banco `postgres`, administrado pelo pgAdmin 4.
- **Importação:** script Python (`scripts/importar.py`) com pandas e openpyxl (leitura da planilha) e psycopg2 (gravação no banco). As dependências estão em `requirements.txt`, e os dados de conexão são lidos de um arquivo `.env` fora do versionamento (modelo em `.env.example`).
- **Conferência:** consultas `SELECT COUNT(*)` no pgAdmin.

## Estrutura da planilha

A planilha `dados/base_teste.xlsx` tem 5 abas. As abas têm linhas vazias formatadas abaixo dos dados; as linhas com dados são as contadas abaixo.

| Aba | Linhas | Coluna | Tipo na planilha | Observação |
| --- | --- | --- | --- | --- |
| fornecedor | 20 | idfornecedor | texto | Códigos no formato `F1` a `F20` |
|  |  | razao_social | texto |  |
| produtos_filial | 20 | filial_id | inteiro | Todas as linhas são da filial 1 |
|  |  | idproduto | texto | No banco, coluna `produto_id` |
|  |  | descricao | texto |  |
|  |  | estoque | inteiro |  |
|  |  | preco_unitario, preco_compra, preco_venda | decimal |  |
|  |  | idfornecedor | texto | Códigos `F*` |
| pedido_compra | 29 | pedido_id, item | inteiro |  |
|  |  | data_pedido, data_entrega | data |  |
|  |  | produto_id, descricao_produto | texto |  |
|  |  | ordem_compra | inteiro | Liga o pedido à entrada de mercadoria |
|  |  | qtde_pedida, qtde_entregue | inteiro |  |
|  |  | filial_id | inteiro |  |
|  |  | preco_compra | decimal |  |
|  |  | fornecedor_id | inteiro | Numérico, enquanto o cadastro usa `F*` |
|  |  | (11 colunas sem cabeçalho) | variados | Têm dados nas linhas 22 a 30 (cópia dos pedidos 12 a 20) |
| entradas_mercadoria | 20 | data_entrada | data |  |
|  |  | nro_nfe, produto_id, descricao_produto | texto |  |
|  |  | item, ordem_compra, qtde_recebida, filial_id | inteiro |  |
|  |  | custo_unitario | decimal |  |
| venda | 33 | venda_id, filial_id, item | inteiro |  |
|  |  | data_emissao | data |  |
|  |  | horariomov | texto | Formato `HH:MM:SS` |
|  |  | produto_id, unidade_medida | texto |  |
|  |  | qtde_vendida | decimal | Há quantidades fracionadas |
|  |  | valor_unitario | decimal |  |

A coluna `qtde_pendente` de `pedido_compra` não existe na planilha: é calculada na importação (`qtde_pedida − qtde_entregue`).

## Erros encontrados no DDL e como foram corrigidos

O DDL original (`sql/01_ddl_enunciado.sql`) foi executado no PostgreSQL 18 pelo pgAdmin 4, tabela por tabela. A versão corrigida está em `sql/01_ddl_postgres.sql`.

As tabelas foram criadas no schema `integracao`, no banco `postgres`. As tabelas `venda` e `pedido_compra` foram criadas sem erro. As outras três tinham erros, alguns apontados pelo PostgreSQL e outros que só apareceriam na importação.

### Erros que impediam a criação das tabelas

| Tabela | Erro | Mensagem do PostgreSQL | Correção |
| --- | --- | --- | --- |
| entradas_mercadoria | A chave primária usa a coluna `ordem_compra`, que não foi declarada na tabela | `ERROR: column "ordem_compra" named in key does not exist` (SQL state 42703) | Coluna `ordem_compra float8 DEFAULT 0 NOT NULL` adicionada, com o mesmo tipo de `pedido_compra.ordem_compra`, pois é o campo que liga a entrada ao pedido de compra |
| produtos_filial | Falta a vírgula entre a última coluna (`idfonecedor int4 NULL`) e o `CONSTRAINT` | `ERROR: syntax error at or near "("` (SQL state 42601) | Vírgula adicionada |
| produtos_filial | A chave primária usa `idproduto`, mas a coluna foi declarada como `produto_id` | `ERROR: column "idproduto" named in key does not exist` (SQL state 42703) | Chave primária passou a usar `(filial_id, produto_id)`, mantendo o nome `produto_id` igual ao das outras tabelas |
| fornecedor | A chave primária é `(idforncedor, idproduto)`, mas `idproduto` não existe nesta tabela | `ERROR: column "idproduto" named in key does not exist` (SQL state 42703) | Chave primária passou a ser só `idfornecedor`: a tabela é um cadastro, com um registro por fornecedor, e a aba `fornecedor` da planilha não tem produto |

### Erros que o PostgreSQL aceita, mas que impediriam a importação

| Tabela | Erro | Consequência | Correção |
| --- | --- | --- | --- |
| produtos_filial | Nome de coluna `decricao` escrito errado | O INSERT na coluna `descricao` falharia | Renomeada para `descricao`, como na planilha |
| produtos_filial | Nome de coluna `idfonecedor` escrito errado | O INSERT na coluna `idfornecedor` falharia | Renomeada para `idfornecedor`, como na planilha |
| produtos_filial | `idfonecedor` com tipo `int4`, mas a planilha traz códigos como "F8" | Erro de conversão de tipo em todas as linhas | Tipo alterado para `varchar(25)`, igual a `fornecedor.idfornecedor` |
| produtos_filial | `filial_id` declarado como `NULL`, mas faz parte da chave primária | O PostgreSQL força `NOT NULL` sozinho; o MySQL recusa o comando | Declarado `NOT NULL` |
| produtos_filial | `produto_id` com `varchar(255)`, enquanto nas outras tabelas é `varchar(25)` | Tamanhos diferentes para o mesmo dado | Padronizado em `varchar(25)` |
| fornecedor | Nome de coluna `idforncedor` escrito errado | O INSERT na coluna `idfornecedor` falharia | Renomeada para `idfornecedor`, como na planilha |

## Erros encontrados no script de importação e como foram corrigidos

O script original (versão do commit `a503d97`, só com a conexão ajustada para o `.env` e o schema `integracao`) terminou com a mensagem "Importação concluída com sucesso!", mas a conferência no banco mostrou outro resultado:

| Tabela | Linhas na planilha | O script informou | Linhas no banco | Linhas com data |
| --- | --- | --- | --- | --- |
| venda | 33 | 33 inseridos | 0 | 0 |
| pedido_compra | 29 | 29 inseridos | 29 | 0 |
| entradas_mercadoria | 20 | 20 inseridos | 20 | 0 |
| fornecedor | 20 | 20 inseridos | 20 | — |
| produtos_filial | 20 | 20 inseridos | 20 | — |

No log, cada uma das 33 vendas falhou com `o valor nulo na coluna "data_emissao" da relação "venda" viola a restrição de não-nulo`.

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` faz `int(valor)` esperando o número serial do Excel, mas o pandas já entrega a data convertida (`Timestamp`). O `int()` falha e o `except` genérico devolve `None` | Nenhuma venda entrou (`data_emissao` é NOT NULL). Em `pedido_compra` e `entradas_mercadoria` todas as datas foram gravadas como NULL, sem nenhum aviso | Conversão de data que aceita data já convertida, serial do Excel, ISO e DD/MM/AAAA. Data que não converte é registrada como erro, nunca vira NULL em silêncio |
| O total impresso é `len(df)`, o tamanho da planilha, e não o que entrou | O script informou "33 registros inseridos em venda" com 0 linhas no banco | O total vem de `SELECT COUNT(*)` no banco, comparado com o número de linhas aprovadas |
| Mensagem final "Importação concluída com sucesso!" fixa | Sucesso anunciado mesmo com 33 erros | A mensagem de sucesso só aparece se a contagem do banco bater; caso contrário o script termina com erro |
| `conn.rollback()` a cada linha com erro, com `commit()` só no fim da tabela | Um erro desfaz também todas as linhas anteriores da mesma tabela, que já tinham sido contadas como inseridas | Gravação em uma única transação, depois de validar todos os dados; se algo falhar, nada é gravado e o motivo aparece |
| Valores vazios substituídos por valores inventados (`0` em preços e `ordem_compra`, filial `1`, horário `00:00:00`) | Dados errados entrariam no banco como se fossem verdadeiros | Vazio em coluna que aceita NULL vira NULL; vazio em coluna obrigatória rejeita a linha, com o motivo |
| `str(row[...])` sem checar vazio em `idfornecedor`, `razao_social`, `produto_id` e `descricao` | Um campo vazio seria gravado como o texto `"nan"` | Vazio é tratado antes da conversão |
| `pedido_compra`: `df.iloc[:, :12]` corta as colunas pela posição e renomeia pela ordem | As 11 colunas sem cabeçalho, que têm dados, são descartadas sem verificação; se a ordem das colunas mudar, valores vão para o campo errado | Colunas lidas pelo nome; as colunas sem cabeçalho são descartadas pelo nome e cada linha com conteúdo nelas é registrada |
| `ON CONFLICT ... DO NOTHING` em todos os INSERTs | Linhas com chave duplicada seriam ignoradas sem aviso | Duplicidade de chave verificada antes da carga e registrada; sem `DO NOTHING`, um conflito vira erro visível |
| Senha fixa no código (`"password": "1234"`) | Credencial exposta no repositório | Conexão lida do `.env`, que não é versionado |
| Um `INSERT` por linha, em laço | Lento e difícil de conferir | Inserção em lote (`execute_values`) |

## Tratamentos aplicados aos dados

O script foi reorganizado em camadas, no modelo da arquitetura medalhão. Os dados passam de uma camada para a outra em memória:

```
scripts/importar.py      ponto de entrada: bronze → prata → carga → conferência
scripts/etl/config.py    caminhos e conexão (.env)
scripts/etl/bronze.py    lê a planilha como veio
scripts/etl/prata.py     limpa, converte e valida
scripts/etl/carga.py     grava no banco e confere
```

1. **Bronze:** lê as 5 abas com todas as células como texto, sem converter nem descartar nada, e anota a linha da planilha de cada registro.
2. **Prata:** para cada tabela, com os nomes de coluna do DDL corrigido:
   - **Conversão de tipos:** datas (serial do Excel, ISO ou DD/MM/AAAA), números, inteiros e textos, com espaços nas pontas removidos.
   - **Normalização:** `idproduto` → `produto_id`; colunas sem cabeçalho descartadas; `qtde_pendente` calculada.
   - **Validações que rejeitam a linha:** campo obrigatório vazio, valor que não converte, texto maior que a coluna, chave primária duplicada.
   - **Validações que geram aviso:** inconsistências de negócio. A linha entra no banco para poder ser mostrada por SQL na validação com o cliente (Parte 4).
3. **Carga:** em uma única transação, apaga o conteúdo das 5 tabelas, insere os registros aprovados e confere o `COUNT(*)` de cada tabela. Executar de novo dá sempre o mesmo resultado.

Cada ocorrência é gravada em `docs/relatorio_importacao.csv` (tabela, linha da planilha, coluna, valor, nível e motivo). Na planilha atual nenhuma linha foi rejeitada, e foram registrados estes avisos:

| Tabela | Aviso | Linhas |
| --- | --- | --- |
| produtos_filial | Preço de compra maior que o de venda | 4 |
| pedido_compra | Dados em 11 colunas sem cabeçalho, à direita da tabela (cópia dos pedidos 12 a 20) | 9 |
| pedido_compra | Pedido sem ordem de compra (`ordem_compra = 0`) | 11 |
| pedido_compra | Data de entrega anterior à data do pedido | 20 |
| pedido_compra | `fornecedor_id` numérico, sem correspondência no cadastro de fornecedor (códigos `F*`) | 29 |
| pedido_compra | Pedidos que repetem produto, data e preço de outro pedido (pedidos 12 a 20 e 21 a 29) | 18 |
| entradas_mercadoria | Entrada sem pedido com a mesma `ordem_compra` (ordens 19 e 20) | 2 |
| entradas_mercadoria | Quantidade recebida diferente da `qtde_entregue` do pedido | 18 |
| entradas_mercadoria | Quantidade recebida maior que a pedida | 7 |
| entradas_mercadoria | Entrada anterior à data do pedido | 9 |
| venda | Quantidade fracionada vendida em unidade (`UN`) | 5 |
| venda | Produto vendido que não existe em `produtos_filial` (P21 a P28) | 13 |
| venda | Filial sem produtos cadastrados (filiais 2 e 3) | 4 |

## Conferência final

| Tabela | Linhas na planilha | Aprovadas na prata | Linhas no banco |
| --- | --- | --- | --- |
| fornecedor | 20 | 20 |  |
| produtos_filial | 20 | 20 |  |
| pedido_compra | 29 | 29 |  |
| entradas_mercadoria | 20 | 20 |  |
| venda | 33 | 33 |  |
