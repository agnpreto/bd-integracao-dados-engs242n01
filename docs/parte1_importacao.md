# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

Script em **Python** (`scripts/importar.py`) com `pandas` + `openpyxl` para ler a planilha e `psycopg2` (PostgreSQL) ou `pymysql` (MySQL) para gravar no banco. É o script do estagiário, **corrigido**: o original gravava tabelas vazias e dizia "concluída com sucesso" (detalhes abaixo).

Ambientes de teste: PostgreSQL 16 e MariaDB 10.11 (que é compatível com o MySQL). O DDL e o script do MySQL foram executados no MariaDB; vale rodar uma vez no MySQL 8 da máquina de vocês antes da apresentação.

Como reproduzir (na raiz do repositório):

```bash
pip install pandas openpyxl psycopg2-binary pymysql

# PostgreSQL
psql -d meu_banco -f sql/01_ddl_postgres.sql
export DB_NAME=meu_banco DB_USER=postgres DB_PASSWORD='...'   # a senha não fica no código
python scripts/importar.py

# MySQL
mysql loja < sql/01_ddl_mysql.sql
export DB_TIPO=mysql DB_PORT=3306 DB_NAME=loja DB_USER=root DB_PASSWORD='...'
python scripts/importar.py
```

O script pode ser rodado várias vezes: ele limpa as tabelas antes de carregar. No final imprime a tabela de conferência (planilha x banco) e termina com erro se alguma tabela ficar com linhas faltando.

## Estrutura da planilha

A planilha `dados/base_teste.xlsx` tem 5 abas. Os tipos abaixo são os que o Excel entrega; a coluna "No banco" é o tipo do DDL corrigido.

| Aba | Coluna | Tipo na planilha | No banco | Observação |
| --- | --- | --- | --- | --- |
| venda (33 linhas) | venda_id | inteiro | bigint | |
| | data_emissao | data | date | |
| | horariomov | texto (`08:00:00`) | time | igual em todas as linhas |
| | produto_id | texto | varchar(25) | |
| | qtde_vendida | número | numeric(14,4) | tem frações (38,6; 20,04...) |
| | valor_unitario | número | numeric(12,4) | |
| | filial_id | inteiro | int | |
| | item | inteiro | int | |
| | unidade_medida | texto | varchar(3) | |
| pedido_compra (29 linhas) | pedido_id, item, ordem_compra | inteiro | bigint / int | |
| | data_pedido, data_entrega | data | date | |
| | produto_id, descricao_produto | texto | varchar | |
| | qtde_pedida, qtde_entregue | inteiro | numeric(14,4) | |
| | preco_compra | número | numeric(12,4) | |
| | filial_id, fornecedor_id | inteiro | int | |
| | (colunas M a W) | misto | não importadas | 11 colunas **sem título**, com dados em 9 linhas (ver "Tratamentos") |
| entradas_mercadoria (20 linhas) | data_entrada | data | date | |
| | nro_nfe | texto (`NFE1`) | varchar(255) | |
| | item, ordem_compra | inteiro | int / bigint | |
| | produto_id, descricao_produto | texto | varchar | |
| | qtde_recebida, custo_unitario | número | numeric | |
| | filial_id | inteiro | int | |
| produtos_filial (20 linhas) | filial_id | inteiro | int | |
| | **idproduto** | texto | `produto_id` varchar(25) | nome diferente das outras abas |
| | descricao | texto | varchar(255) | |
| | estoque, preco_unitario, preco_compra, preco_venda | número | numeric | |
| | idfornecedor | texto (`F8`) | int | vira `8` |
| fornecedor (20 linhas) | idfornecedor | texto (`F1` a `F20`) | int | vira `1` a `20` |
| | razao_social | texto | varchar(255) | |

## Erros encontrados no DDL e como foram corrigidos

Rodamos o `sql/01_ddl_enunciado.sql` no PostgreSQL. Resultado: só `venda` e `pedido_compra` foram criadas; as outras três deram erro.

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | `ERROR: column "ordem_compra" named in key does not exist`: a PK usa `ordem_compra`, mas a coluna não foi declarada | Coluna `ordem_compra bigint NOT NULL` criada |
| produtos_filial | `syntax error at or near "("`: falta a vírgula depois de `idfonecedor int4 NULL` | Vírgula colocada |
| produtos_filial | PK usa `idproduto`, que não existe (a coluna é `produto_id`) | PK `(filial_id, produto_id)` |
| produtos_filial | Typos `decricao` e `idfonecedor` | `descricao` e `idfornecedor` |
| produtos_filial | `produto_id` é `varchar(255)`, nas outras tabelas é `varchar(25)` | Padronizado em `varchar(25)` |
| fornecedor | `ERROR: column "idproduto" named in key does not exist`: PK cita `idproduto`, e fornecedor nem tem produto | PK só em `idfornecedor` |
| fornecedor | Typo `idforncedor` | `idfornecedor` |
| fornecedor / produtos_filial / pedido_compra | Mesmo código com tipos diferentes: `varchar` em fornecedor, `int4` nas outras duas | Código numérico (`int`) nas três; `idfornecedor` virou identity (precisa para a trigger da Parte 3) |
| pedido_compra, entradas_mercadoria | `pedido_id`, `item` e `ordem_compra` como `float8`, inclusive dentro de PK | Inteiros (`bigint`/`int`) |
| todas | Quantidades e dinheiro em `float8` (arredondamento) | `numeric` |
| venda | PK chamada `pk_consumo` (nome de outra tabela) | `pk_venda` |
| venda | `horariomov` como `varchar(8)` | `time` |
| venda | `produto_id DEFAULT ''` e `qtde_vendida NULL` | Sem default vazio; `qtde_vendida NOT NULL` |
| venda, demais | `filial_id` com `int8` em uma tabela e `int4` nas outras | `int` em todas |
| pedido_compra | `fornecedor_id DEFAULT 0`: não existe fornecedor 0 | Sem default |
| pedido_compra | `qtde_pendente` digitada à mão, pode divergir | Coluna calculada: `qtde_pedida - qtde_entregue` |
| colunas de PK | `DEFAULT 0` / `'0'` permite gravar chave zerada sem perceber | Defaults removidos |
| todas | Nenhuma chave estrangeira | FKs criadas onde os dados permitem (ver abaixo) |
| MySQL | `public.` e `::character varying` não existem no MySQL | Versão própria: `sql/01_ddl_mysql.sql` |

**FKs que ficaram de fora de propósito:** `venda → produtos_filial` e `entradas_mercadoria → pedido_compra`. Os dados do cliente violam essas relações (produtos P21 a P28 vendidos mas não cadastrados; entradas NFE19 e NFE20 com ordem de compra que não existe em nenhum pedido). Com a FK, essas linhas não entrariam e não conseguiríamos mostrar o erro ao cliente. As violações estão listadas em `sql/04_validacao.sql`.

## Erros encontrados no script de importação e como foram corrigidos

Para medir o estrago, rodamos o script original contra o DDL do cliente **com só os erros de sintaxe consertados** (mesmos tipos do enunciado):

| Tabela | Linhas na planilha | Linhas no banco | O que o script imprimiu |
| --- | --- | --- | --- |
| fornecedor | 20 | 20 | "20 registros inseridos" |
| produtos_filial | 20 | **0** | "20 registros inseridos" |
| pedido_compra | 29 | 29, mas **todas as datas NULL** | "29 registros inseridos" |
| entradas_mercadoria | 20 | 20, mas **todas as datas NULL** | "20 registros inseridos" |
| venda | 33 | **0** | "33 registros inseridos" e "Importação concluída com sucesso!" |

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` faz `int(valor)`, mas o pandas já entrega a data como `Timestamp`. O `except:` sem tipo engole o erro e devolve `None` | **Todas as datas viram NULL** em silêncio. Em `venda`, `data_emissao` é NOT NULL, então as 33 linhas falham | Conversão aceita Timestamp, texto e número serial do Excel; data inválida gera erro com o número da linha |
| `conn.rollback()` dentro do loop, com `commit` só no fim da tabela | Um único erro desfaz **todas as linhas já inseridas** daquela tabela. Foi o que esvaziou `produtos_filial` | Linhas são convertidas e validadas antes; o INSERT da tabela é feito de uma vez, e falha de banco é reportada |
| Mensagem imprime `len(df)` (linhas lidas), não as linhas gravadas | Diz "20 inseridos" com a tabela vazia; "sucesso" com 0 linhas | Conta com `SELECT COUNT(*)` e compara com a planilha; sai com erro se divergir |
| `ON CONFLICT ... DO NOTHING` | Linhas repetidas ou com chave duplicada somem sem aviso | Duplicidade de chave é detectada antes e listada |
| `idfornecedor` enviado como texto (`'F8'`) para coluna `int4` | `produtos_filial` falha em todas as linhas | `F8` vira `8` (regex), igual em fornecedor, produtos e pedidos |
| Nomes dos campos do INSERT diferentes dos do DDL original (`idfornecedor` x `idforncedor`, `descricao` x `decricao`) | O script não funciona com o DDL do cliente | Script e DDL corrigido usam os mesmos nomes |
| `df.iloc[:, :12]` e renomeação por lista, por **posição** | Se a ordem das colunas mudar, os valores caem na coluna errada; as 11 colunas extras são descartadas sem aviso | Leitura por **nome** de coluna; extras com dados geram aviso |
| `qtde_pendente` calculada no Python | Valor pode divergir do banco | Coluna calculada no banco |
| Senha `1234` escrita no código | Contra a regra do README | Variáveis de ambiente (`DB_PASSWORD`) |
| Comentário "porta do MySQL 3006" e só PostgreSQL | Porta certa é 3306; o script não serve para MySQL | Suporta `DB_TIPO=postgres` ou `mysql` |
| Caminho `dados/base_teste.xlsx` relativo ao terminal | Só funciona rodando da raiz do repositório | Caminho calculado a partir do arquivo do script |
| `float()` para dinheiro | Ruído de ponto flutuante | `Decimal` |
| Sem conferência final | Ninguém percebe linhas faltando | Tabela planilha x banco no fim |

## Tratamentos aplicados aos dados

- **Datas:** Timestamp do pandas vira `date`; `horariomov` vira `time`.
- **Números:** vão como `Decimal` (sem ruído de float). `qtde_pendente` não é importada, porque o banco calcula.
- **Texto:** `TRIM` em todos os campos; descrição vazia vira NULL.
- **Fornecedor:** código `F8` vira o número `8` na aba `fornecedor` e na `produtos_filial`. A aba `pedido_compra` já usa números (`1` a `20`).
- **Coluna `idproduto`** da aba `produtos_filial` é gravada em `produto_id`, como nas outras tabelas.
- **Colunas M a W de `pedido_compra`** (sem título, com dados em 9 linhas, nos pedidos 21 a 29) **não são importadas**: parecem uma cópia deslocada dos pedidos 12 a 20 (têm até uma coluna de "pendente"). O script avisa quando encontra isso. A conferência foi feita com o pandas (`p.iloc[:, 12:].notna().any(axis=1).sum()` dá 9).
- **Dados do cliente não foram "consertados":** erros de negócio (datas impossíveis, pedidos duplicados, produtos sem cadastro etc.) foram importados como vieram, para podermos mostrá-los ao cliente. A lista completa está em `docs/parte4_validacao.md`.
- **Reexecução segura:** as tabelas são limpas antes de cada carga, e a sequência do `idfornecedor` (PostgreSQL) é ajustada para o maior id importado, para a trigger da Parte 3 não repetir número.

## Conferência final

Saída do script corrigido, nos dois bancos (PostgreSQL 16 e MariaDB 10.11):

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |

Nenhuma data ficou vazia (`sql/04_validacao.sql`, consulta B2).
