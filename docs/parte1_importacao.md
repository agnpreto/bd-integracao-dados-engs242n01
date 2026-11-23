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

A primeira correção foi a da `excel_para_data`, que impedia as datas de entrarem. Os outros problemas do script estão mapeados abaixo. Eles foram mantidos no código de propósito: as funções originais foram preservadas para que cada erro possa ser analisado e corrigido separadamente.

| Erro | Efeito | Situação |
| --- | --- | --- |
| `excel_para_data` faz `int(valor)` esperando o número serial do Excel, mas o pandas já entrega a data convertida (`Timestamp`). O `int()` falha e o `except` genérico devolve `None` | Nenhuma venda entrou (`data_emissao` é NOT NULL). Em `pedido_compra` e `entradas_mercadoria` todas as datas foram gravadas como NULL, sem nenhum aviso | **Corrigido.** A função aceita data já convertida (`Timestamp`/`datetime`) e serial do Excel (número). Um valor em outro formato gera erro com a mensagem `data em formato inesperado`, em vez de virar NULL em silêncio |
| `ON CONFLICT ... DO NOTHING` em todos os INSERTs | Uma linha com chave já existente é ignorada sem aviso. Na reexecução depois da correção das datas, as 29 linhas de `pedido_compra` e as 20 de `entradas_mercadoria` gravadas com data NULL **não foram atualizadas** | **Contornado.** As duas tabelas foram esvaziadas com `DELETE` antes de rodar o script de novo. O comportamento continua no código |
| O total impresso é `len(df)`, o tamanho da planilha, e não o que entrou | O script informou "33 registros inseridos em venda" com 0 linhas no banco | **Mantido.** A conferência é feita no banco com `SELECT COUNT(*)` (ver "Conferência final") |
| Mensagem final "Importação concluída com sucesso!" fixa | Sucesso anunciado mesmo com 33 erros | **Mantido.** Mesma conferência no banco |
| `conn.rollback()` a cada linha com erro, com `commit()` só no fim da tabela | Um erro desfaz também todas as linhas anteriores da mesma tabela, que já tinham sido contadas como inseridas | **Mantido.** Na execução final nenhuma linha deu erro, então nada foi desfeito |
| Valores vazios substituídos por valores inventados (`0` em preços e `ordem_compra`, filial `1`, horário `00:00:00`) | Dados errados entrariam no banco como se fossem verdadeiros | **Mantido.** A planilha atual não tem células vazias nessas colunas, então nenhum valor foi inventado nesta carga |
| `str(row[...])` sem checar vazio em `idfornecedor`, `razao_social`, `produto_id` e `descricao` | Um campo vazio seria gravado como o texto `"nan"` | **Mantido.** Não ocorre na planilha atual |
| `pedido_compra`: `df.iloc[:, :12]` corta as colunas pela posição e renomeia pela ordem | As 11 colunas sem cabeçalho, que têm dados nas linhas 22 a 30, são descartadas sem verificação; se a ordem das colunas mudar, valores vão para o campo errado | **Mantido.** As 12 primeiras colunas estão na ordem esperada. O conteúdo das colunas descartadas foi registrado como erro nos dados (Parte 4) |
| Senha fixa no código (`"password": "1234"`) | Credencial exposta no repositório | **Corrigido.** A conexão é lida do `.env`, que não é versionado |
| Um `INSERT` por linha, em laço | Lento em bases grandes | **Mantido.** Com 122 linhas no total, o tempo não é um problema |

## Tratamentos aplicados aos dados

O script foi reorganizado em camadas, no modelo da arquitetura medalhão, **sem mudar a lógica das funções originais**: cada trecho do `importar.py` original foi movido para a camada correspondente. Os dados passam de uma camada para a outra em memória.

```
scripts/importar.py      ponto de entrada: conecta e chama bronze → prata → carga, tabela por tabela
scripts/etl/config.py    caminho da planilha, schema e conexão (lidos do .env)
scripts/etl/bronze.py    lê cada aba da planilha
scripts/etl/prata.py     converte cada linha nos valores do INSERT
scripts/etl/carga.py     executa os INSERTs e o commit
```

1. **Bronze (leitura):** `pd.read_excel` de cada aba e remoção de espaços nos nomes das colunas.
2. **Prata (conversão e normalização):**
   - **Datas:** `excel_para_data` converte para `date` (já corrigida, ver acima).
   - **Números:** `float()` para quantidades, preços e chaves `float8`; `int()` para `filial_id`, `venda_id`, `item` e `fornecedor_id`.
   - **Textos:** `str().strip()` remove espaços nas pontas de códigos e descrições.
   - **Normalização de nomes:** em `produtos_filial`, `idproduto` da planilha vai para a coluna `produto_id` do banco. Em `pedido_compra`, as 12 primeiras colunas são renomeadas para os nomes do DDL e as colunas sem cabeçalho ficam de fora.
   - **Campo calculado:** `qtde_pendente = qtde_pedida − qtde_entregue`.
3. **Carga:** `INSERT ... ON CONFLICT DO NOTHING` linha a linha, com `commit` ao final de cada tabela.

A ordem de carga é fornecedor → produtos_filial → pedido_compra → entradas_mercadoria → venda, ou seja, cadastros primeiro e movimentos depois.

### Validações

A validação dos dados foi feita depois da carga, por SQL. Assim os dados com problema ficam no banco, e o cliente pode vê-los na reunião de validação (Parte 4):

- **Validação da carga:** contagem de linhas e de datas preenchidas por tabela, comparada com a planilha (ver "Conferência final").
- **Validação de conteúdo:** 21 consultas em `sql/04_validacao.sql`, uma por tipo de erro (datas fora de ordem, pedidos duplicados, produtos sem cadastro, quantidades e preços divergentes etc.). A lista completa, com as quantidades, está em `docs/parte4_validacao.md`.

## Conferência final

Depois da correção da `excel_para_data`, `pedido_compra` e `entradas_mercadoria` foram esvaziadas (por causa do `ON CONFLICT DO NOTHING`) e o script foi executado de novo. Resultado no banco:

```sql
SELECT 'venda' AS tabela, COUNT(*) AS linhas, COUNT(data_emissao) AS com_data FROM integracao.venda
UNION ALL SELECT 'pedido_compra',       COUNT(*), COUNT(data_pedido)  FROM integracao.pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*), COUNT(data_entrada) FROM integracao.entradas_mercadoria
UNION ALL SELECT 'produtos_filial',     COUNT(*), NULL::bigint        FROM integracao.produtos_filial
UNION ALL SELECT 'fornecedor',          COUNT(*), NULL::bigint        FROM integracao.fornecedor;
```

| Tabela | Linhas na planilha | Linhas no banco | Linhas com data |
| --- | --- | --- | --- |
| fornecedor | 20 | 20 | — |
| produtos_filial | 20 | 20 | — |
| pedido_compra | 29 | 29 | 29 |
| entradas_mercadoria | 20 | 20 | 20 |
| venda | 33 | 33 | 33 |

Todas as linhas da planilha estão no banco, com todas as datas preenchidas.
