# Parte 1: Documentação do processo de importação

Equipe **CoreData**: Ana Júlia Pantoja Chagas (265214) e Rafaela da Silva Tavares (2422211).

## Ferramenta utilizada

Script Python `scripts/importar.py` (pandas + openpyxl para ler a planilha; psycopg2 para PostgreSQL ou pymysql para MySQL), corrigido a partir do script do estagiário. A importação foi testada nos dois bancos (PostgreSQL 16 e MariaDB 10.11, compatível com MySQL) e deu o mesmo resultado.

Ordem de execução:

1. `sql/01_ddl_postgres.sql` (ou `sql/01_ddl_mysql.sql`) cria as tabelas.
2. `python scripts/importar.py` carrega a planilha. A conexão vem de variáveis de ambiente (`DB_TIPO`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`); não há senha real no arquivo.
3. O script faz tudo em uma transação (ou grava tudo, ou nada) e termina comparando as linhas da planilha com as linhas gravadas.
4. `sql/05_correcoes.sql` aplica as correções nos dados (PostgreSQL).

## Estrutura da planilha

Arquivo `dados/base_teste.xlsx`, 5 abas, sem alteração.

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| venda (33 linhas) | venda_id | inteiro | 1 a 33, sem repetição |
| | data_emissao | data | janeiro a março de 2025 |
| | horariomov | texto (hh:mm:ss) | todas as linhas com 08:00:00 |
| | produto_id | texto | P1 a P28 |
| | qtde_vendida | decimal | 5 linhas com fração |
| | valor_unitario | decimal | |
| | filial_id | inteiro | 1, 2 e 3 |
| | item | inteiro | sempre 1 |
| | unidade_medida | texto | sempre UN |
| pedido_compra (29 linhas) | pedido_id, item, ordem_compra, qtde_pedida, qtde_entregue, filial_id, fornecedor_id | inteiro | `fornecedor_id` é número (1 a 20) |
| | data_pedido, data_entrega | data | |
| | produto_id, descricao_produto | texto | |
| | preco_compra | decimal | |
| | (sem cabeçalho) colunas M a W | misto | 9 linhas de resíduo (cópia de pedidos 12 a 20 com `qtde_pendente`); ignoradas |
| | qtde_pendente | não existe na planilha | existe no DDL; passou a ser calculada |
| entradas_mercadoria (20 linhas) | data_entrada | data | |
| | nro_nfe | texto | NFE1 a NFE20 |
| | item, ordem_compra, qtde_recebida, filial_id | inteiro | |
| | produto_id, descricao_produto | texto | |
| | custo_unitario | decimal | |
| produtos_filial (20 linhas) | filial_id | inteiro | só filial 1 |
| | idproduto | texto | no DDL a coluna se chama `produto_id` |
| | descricao | texto | |
| | estoque | inteiro | |
| | preco_unitario, preco_compra, preco_venda | decimal | |
| | idfornecedor | texto | formato `F8` (no DDL é numérico) |
| fornecedor (20 linhas) | idfornecedor | texto | `F1` a `F20` |
| | razao_social | texto | |

## Erros encontrados no DDL e como foram corrigidos

Ao rodar `01_ddl_enunciado.sql` no PostgreSQL, 3 comandos falharam (`entradas_mercadoria`, `produtos_filial` e `fornecedor` não foram criadas). Os demais erros foram achados por leitura.

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | A PK usa `ordem_compra`, mas a coluna não existe na tabela (`column "ordem_compra" named in key does not exist`). É a coluna que liga a entrada ao pedido. | Coluna `ordem_compra bigint` criada. |
| produtos_filial | Falta vírgula depois de `idfonecedor int4 NULL` (erro de sintaxe). | Vírgula incluída. |
| produtos_filial | A PK usa `idproduto`, que não existe (a coluna é `produto_id`). | PK `(filial_id, produto_id)`. |
| produtos_filial | Nomes com erro de digitação: `decricao` e `idfonecedor`. | `descricao` e `idfornecedor`. |
| produtos_filial | `filial_id` é `NULL` mas faz parte da PK. `produto_id` é `varchar(255)` enquanto nas outras tabelas é `varchar(25)`. | `filial_id NOT NULL`; `varchar(25)`. |
| produtos_filial | `idfornecedor int4` não tem relação com `fornecedor.idforncedor`, que é `varchar`. Sem FK. | Chave de fornecedor passou a ser numérica, com FK. |
| fornecedor | A PK usa `idproduto`, que não existe nessa tabela. Fornecedor não tem produto na chave. | PK somente `idfornecedor`. |
| fornecedor | Nome da coluna com erro de digitação: `idforncedor`. | `idfornecedor integer` (identity). O código `F1`, `F2`... foi mantido em `codigo_origem`. |
| pedido_compra | Chaves e quantidades em `float8` (`pedido_id`, `item`, `ordem_compra`). Número de ponto flutuante não deve ser chave. | `bigint`, `integer` e `numeric(12,3)`. |
| pedido_compra | `fornecedor_id int4` x `fornecedor.idforncedor varchar`: tipos incompatíveis. `preco_compra float8 DEFAULT 0 NULL` é contraditório. `qtde_pendente` é `NOT NULL` mas a planilha não traz esse dado. | `fornecedor_id integer` com FK. `preco_compra numeric(12,4) NOT NULL`. `qtde_pendente` virou coluna gerada (`qtde_pedida - qtde_entregue`). |
| venda | `::character varying` é sintaxe só do PostgreSQL (não roda no MySQL). `int8` e `float8` também são só do PostgreSQL. | Versão MySQL com `BIGINT` e `DECIMAL`, sem os casts. |
| venda | `horariomov` é `varchar(8)` (um horário guardado como texto). `qtde_vendida float8` permite imprecisão. `produto_id DEFAULT ''` permite produto vazio na PK. A PK se chama `pk_consumo` (nome de outra tabela). | `horariomov time`. `qtde_vendida numeric(12,3) NOT NULL`. Sem default vazio. PK `pk_venda`. |
| todas | `float8` em preços e estoque. Não há FK nem `CHECK`. | `numeric(12,4)`, FKs entre tabelas e `CHECK` contra valores negativos. |
| venda e entradas_mercadoria | FK para pedidos/cadastro não foi criada de propósito: venda tem produtos e filiais fora do cadastro, e `ordem_compra` não é única em `pedido_compra`. | Os dados entram e os problemas são apontados em `sql/04_validacao.sql`. |

## Erros encontrados no script de importação e como foram corrigidos

| Erro | Efeito | Correção |
| --- | --- | --- |
| `excel_para_data` faz `int(valor)` em um `Timestamp` (o pandas já converte as datas) e usa `except:` sem tipo. | Testado: devolve `None` para todas as datas. Em `venda`, `data_emissao` é `NOT NULL`, então todas as 33 linhas falham; nas demais tabelas as datas ficam nulas sem aviso. | Conversão com `pd.Timestamp(valor).date()`. |
| `conn.rollback()` dentro do laço, depois do erro de uma linha. | O rollback desfaz todas as linhas da tabela ainda não confirmadas (o commit só vem no fim). Uma linha ruim apaga as boas. | Uma transação para a carga inteira: qualquer erro desfaz tudo e o script avisa. |
| Mensagem `len(df) registros inseridos` e "concluída com sucesso" sempre. | Mostra o total da planilha mesmo que nada tenha entrado (e `ON CONFLICT DO NOTHING` descarta duplicatas sem avisar). | Conferência final: `SELECT COUNT(*)` de cada tabela comparado com a planilha, com status OK ou DIVERGENTE. Chaves duplicadas são avisadas. |
| Colunas `idfornecedor`, `descricao` no `INSERT` x DDL com `idforncedor`, `decricao`, `idfonecedor`. | Todos os `INSERT` de fornecedor e produtos falham (coluna inexistente). | DDL corrigido; nomes do script e do banco coincidem. |
| `ON CONFLICT (filial_id, produto_id)` e `ON CONFLICT (idfornecedor)`. | Exigem restrição única com essas colunas, que o DDL original não tinha. | PKs corrigidas; duplicidade tratada no próprio script. |
| `idfornecedor` enviado como texto (`F8`) para uma coluna `int4`. | Erro de tipo em `produtos_filial`. | `id_fornecedor()` extrai o número (`F8` → 8); o código original fica em `fornecedor.codigo_origem`. |
| `entradas_mercadoria` insere `ordem_compra`, que não existe no DDL. | Todos os `INSERT` falham. | Coluna criada no DDL. |
| `pedido_compra`: `df.iloc[:, :12]` com renomeação posicional. `qtde_pendente` calculada no script. | Esconde as colunas sem cabeçalho M a W e quebra se a ordem das colunas mudar. | Colunas sem cabeçalho são descartadas com aviso; colunas lidas por nome; `qtde_pendente` é coluna gerada no banco. |
| Senha `1234` fixa no código; comentário com a porta `3006` do MySQL (o certo é `3306`). | Credencial no repositório (o enunciado proíbe); porta errada. | Configuração por variáveis de ambiente, com valor de exemplo; porta 3306. |

## Tratamentos aplicados aos dados

- **Datas:** `Timestamp` do pandas convertido para `date`; nulos permanecem nulos.
- **Tipos:** quantidades e preços como `numeric` (sem ponto flutuante); chaves como inteiros; `horariomov` como `time`.
- **Texto:** `strip()` em todos os campos de texto.
- **Fornecedor:** `F8` vira o número 8 (`idfornecedor`), e o código original é guardado em `codigo_origem`. Assim `pedido_compra.fornecedor_id` (já numérico na planilha) e `produtos_filial.idfornecedor` ligam com `fornecedor` por FK.
- **Padrões:** `ordem_compra` nula vira 0 e horário nulo vira `00:00:00`, como previa o DDL.
- **Resíduo da planilha:** as 11 colunas sem cabeçalho (M a W) de `pedido_compra` não são importadas e a quantidade é avisada na execução.
- **Correção dos dados:** a importação grava a planilha como veio. Em seguida `sql/05_correcoes.sql` corrige o que tem regra objetiva (ligação dos pedidos 19 e 20 às entradas, cadastro dos produtos e filiais vendidos sem cadastro, unidade de quantidades fracionadas, quantidade entregue conforme a nota) com backup (`bkp_<tabela>`) e registro em `correcao_log`. O que depende de decisão do cliente (preços, datas, fornecedor) não é alterado e está listado em `docs/parte4_validacao.md`.
- **Atomicidade:** carga em uma transação e conferência de contagem ao final.

## Conferência final

Resultado do `importar.py` corrigido, igual no PostgreSQL e no MariaDB.

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |
