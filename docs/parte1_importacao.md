# Parte 1 — Documentação da importação

A planilha `dados/base_teste.xlsx` contém **122 linhas de dados** em cinco abas. A carga usa Python 3, openpyxl e o driver do banco escolhido. A lógica original, a carga corrigida e as consultas foram testadas inicialmente no PostgreSQL 17.5 via PGlite. Os DDLs e a rotina de carga corrigida também foram executados nos servidores locais PostgreSQL 19.0 e MySQL 8.4.13. Nas duas cargas locais, foram usadas as bibliotecas cliente nativas de cada banco com a rotina de importação do repositório.

## Estrutura da planilha

| Aba | Colunas e tipos na origem |
| --- | --- |
| `fornecedor` | `idfornecedor` e `razao_social` são textos. |
| `produtos_filial` | `filial_id` e `estoque` são inteiros. `preco_unitario`, `preco_compra` e `preco_venda` são numéricos. `idproduto`, `descricao` e `idfornecedor` são textos. |
| `pedido_compra` | `pedido_id`, `item`, `ordem_compra`, `qtde_pedida`, `filial_id`, `qtde_entregue` e `fornecedor_id` são inteiros. `data_pedido` e `data_entrega` são datas Excel. `produto_id` e `descricao_produto` são textos. `preco_compra` é numérico. |
| `entradas_mercadoria` | `data_entrada` é data Excel. `nro_nfe`, `produto_id` e `descricao_produto` são textos. `item`, `ordem_compra`, `qtde_recebida` e `filial_id` são inteiros. `custo_unitario` é numérico. |
| `venda` | `venda_id`, `filial_id` e `item` são inteiros. `data_emissao` é data Excel. `horariomov`, `produto_id` e `unidade_medida` são textos. `qtde_vendida` e `valor_unitario` são numéricos. |

Na carga, datas viram `DATE` e horários viram `TIME`. Quantidades e valores monetários usam precisão decimal de seis e quatro casas, respectivamente. Códigos como `P21` e `NFE19` continuam textuais. O campo `idproduto` da planilha vira `produto_id` no banco e a quantidade pendente é calculada como pedida menos entregue.

## DDL original e correções

| Tabela | Erro ou incompatibilidade | Ajuste |
| --- | --- | --- |
| `entradas_mercadoria` | PostgreSQL retornou `42703` porque `ordem_compra` aparece na chave primária sem existir na tabela. | A coluna foi incluída como inteira e obrigatória. |
| `produtos_filial` | PostgreSQL retornou `42601` no parêntese da chave primária. Faltava a vírgula após `idfonecedor`. A chave também referenciava `idproduto`, e a coluna declarada era `produto_id`. | Corrigidos a vírgula, a chave `(filial_id, produto_id)` e os nomes `descricao` e `idfornecedor`. |
| `fornecedor` | PostgreSQL retornou `42703` porque a chave também referenciava `idproduto`, ausente na tabela. A coluna de fornecedor estava grafada `idforncedor`. | Adotada a chave simples `idfornecedor`. |
| `fornecedor`, `produtos_filial` e `pedido_compra` | A planilha usa códigos `F1` a `F20` no cadastro e nos produtos, enquanto os pedidos usam inteiros de 1 a 20. | A carga converte o código de fornecedor pelo sufixo numérico, preserva `F1` a `F20` como `codigo_origem` e usa chaves estrangeiras numéricas. |
| DDL MySQL | Esquema `public`, tipos abreviados e casts `::` são específicos do PostgreSQL. | O DDL MySQL usa o banco selecionado, InnoDB e `AUTO_INCREMENT` na chave do fornecedor. |

O número da ordem é a referência entre pedido e entrada. Produto e filial completam a correspondência. O valor 0 foi preservado como ausência de ordem vinculada. A FK de fornecedor é aplicada durante a carga. A correspondência entre produtos, pedidos e notas é conferida em SQL para que inconsistências existentes na fonte permaneçam rastreáveis.

## Importação original e correções

| Problema | Efeito observado ou possível | Tratamento |
| --- | --- | --- |
| O conversor original aplicava `int()` também às datas nativas do Excel. | As 58 datas dos 29 pedidos viraram `NULL`. As 33 vendas falharam pela restrição de `data_emissao`. | O conversor aceita datas reais, seriais do Excel e datas textuais. |
| O script fixava a ordem e truncava as colunas do pedido sem registrar o conteúdo residual. | As nove linhas com dados em `M:W` passavam despercebidas. | Campos carregados pelo cabeçalho. As células adicionais ficaram no JSON de origem e na listagem de ocorrências. |
| A recuperação de erro interrompia a transação da aba. | Um erro posterior podia desfazer inserções anteriores. | Savepoint por linha e transação da carga, incluindo a auditoria. |
| O script usava tamanho da planilha em mensagens de inserção. | Algumas abas anunciavam linhas inseridas mesmo com a tabela ausente ou vazia. | Contadores de inseridas, existentes e rejeitadas, conferidos com `COUNT(*)`. |
| Senha fixa e caminho relativo ao terminal. | Configuração dependia da máquina. | Credenciais pelo ambiente e caminho padrão a partir da raiz do projeto. |

## Contagens verificadas

A coluna original usa o DDL do repositório com execução por instrução e a lógica do importador original reproduzida sobre a planilha. A carga corrigida foi executada nas bases locais `integracao_corrigida` (PostgreSQL) e `integracao_mysql` (MySQL), inicialmente vazias.

| Tabela | Planilha | Banco com a lógica original | PostgreSQL corrigido | MySQL corrigido |
| --- | ---: | ---: | ---: | ---: |
| `fornecedor` | 20 | Tabela ausente | 20 | 20 |
| `produtos_filial` | 20 | Tabela ausente | 20 | 20 |
| `pedido_compra` | 29 | 29, com datas nulas | 29 | 29 |
| `entradas_mercadoria` | 20 | Tabela ausente | 20 | 20 |
| `venda` | 33 | 0 | 33 | 33 |
| **Total de registros** | **122** | **29** | **122** | **122** |

Ambas as cargas locais tiveram zero rejeições e as contagens conferiram em todas as tabelas. No teste de repetição em PostgreSQL via PGlite, as 122 linhas foram reconhecidas como existentes e as contagens permaneceram iguais. O teste da trigger inseriu um produto sem fornecedor e confirmou o cadastro vinculado de ID **21**. O teste usou transação revertida para retirar o registro de demonstração.

## Como reproduzir

Na raiz do repositório, mantenha o arquivo original em `dados/base_teste.xlsx`. Crie bases vazias e configure credenciais conforme sua instalação. O comando de reprodução do DDL original continua após cada erro para registrar as três falhas.

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install openpyxl psycopg2-binary mysql-connector-python

createdb integracao_original
createdb integracao_corrigida
psql -X -d integracao_original -f sql/01_ddl_enunciado.sql
psql -X -v ON_ERROR_STOP=1 -d integracao_corrigida -f sql/01_ddl_postgres.sql
PGDATABASE=integracao_corrigida python scripts/importar.py
psql -X -v ON_ERROR_STOP=1 -d integracao_corrigida -f sql/02_consultas.sql
psql -X -v ON_ERROR_STOP=1 -d integracao_corrigida -f sql/03_transformacoes.sql
psql -X -v ON_ERROR_STOP=1 -d integracao_corrigida -f sql/04_validacao.sql
```

As opções `PGHOST`, `PGPORT` e `PGUSER` podem ser definidas no ambiente. Use `.pgpass` para as credenciais do PostgreSQL. Para o MySQL, configure `MYSQL_HOST`, `MYSQL_PORT` e `MYSQL_PASSWORD` conforme necessário. O exemplo pressupõe uma base separada chamada `integracao_mysql` e um usuário local autorizado.

```sh
mysql -u seu_usuario -p -e 'CREATE DATABASE integracao_mysql'
mysql -u seu_usuario -p integracao_mysql < sql/01_ddl_mysql.sql
MYSQL_USER=seu_usuario MYSQL_DATABASE=integracao_mysql python scripts/importar.py --sgbd mysql
```

O importador imprime as contagens das cinco abas. Para conferir a carga no MySQL, execute `SELECT COUNT(*)` em cada tabela e compare o resultado com o quadro acima. As consultas das Partes 2 a 4 foram escritas e verificadas em PostgreSQL.
