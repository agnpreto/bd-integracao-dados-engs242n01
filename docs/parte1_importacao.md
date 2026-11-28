# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

Python 3.15 com `pandas` para ler a planilha `dados/base_teste.xlsx` e `PyMySQL` para gravar no MySQL 8 (localhost:3306, banco `loja_integracao`). O DDL foi executado no DBeaver e o script de importação no PowerShell. A senha do banco não está no código: ela é lida da variável de ambiente `DB_PASSWORD`.

## Estrutura da planilha

| Aba | Colunas | Linhas |
| --- | --- | --- |
| fornecedor | idfornecedor, razao_social | 20 |
| produtos_filial | filial_id, idproduto, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor | 20 |
| pedido_compra | pedido_id, data_pedido, item, produto_id, descricao_produto, ordem_compra, qtde_pedida, filial_id, data_entrega, qtde_entregue, preco_compra, fornecedor_id (mais 11 colunas vazias) | 29 |
| entradas_mercadoria | data_entrada, nro_nfe, item, produto_id, descricao_produto, ordem_compra, qtde_recebida, filial_id, custo_unitario | 20 |
| venda | venda_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario, filial_id, item, unidade_medida | 33 |

## Erros encontrados no DDL e como foram corrigidos

| Tabela | Erro | Correção |
| --- | --- | --- |
| todas | prefixo `public.` do PostgreSQL | removido |
| venda | `horariomov varchar(8)` | `TIME NOT NULL DEFAULT '00:00:00'` |
| venda, pedido_compra | tipos `int8`, `float8`, `int4` do PostgreSQL | `BIGINT`, `INT` e `DECIMAL` |
| produtos_filial | colunas `decricao` e `idfonecedor` com grafia errada | `descricao` e `idfornecedor` |
| produtos_filial | PK referenciava `idproduto`, coluna inexistente | PK `(filial_id, produto_id)` |
| fornecedor | coluna `idforncedor` e PK com `idproduto` inexistente | `idfornecedor` como chave primária |
| entradas_mercadoria | PK usava `ordem_compra` sem declarar a coluna | coluna `ordem_compra BIGINT NOT NULL` adicionada |
| pedido_compra | `fornecedor_id int4` | `VARCHAR(25)`, pois os IDs são `F1` a `F20` |
| produtos_filial | faltava vínculo com o fornecedor | FK `fk_produtos_fornecedor` |

## Erros encontrados no script de importação e como foram corrigidos

| Erro | Efeito | Correção |
| --- | --- | --- |
| `import psycopg2` | biblioteca de outro SGBD | trocado por `import pymysql` |
| `INSERT INTO public....` | tabela inexistente no MySQL | prefixo `public.` removido |
| `ON CONFLICT (...) DO NOTHING` | sintaxe inválida no MySQL | linhas removidas |
| datas do Excel lidas como serial/número | colunas `DATE` com valores errados | função `excel_para_data` (epoch 1899-12-30 e `Timestamp.date()`) |
| `fornecedor_id` numérico em pedido_compra (1 a 20) | não casava com `F1` a `F20` da tabela fornecedor | `"F" + str(int(...))` |
| falta de `conn.commit()` | alterações não persistiam no banco | commit após cada INSERT |
| sem contagem final | impossível conferir a carga | `SELECT COUNT(*)` das 5 tabelas no final |

## Tratamentos aplicados aos dados

- `df.columns.str.strip()` para remover espaços dos cabeçalhos.
- `df.iloc[:, :12]` em `pedido_compra` para descartar colunas vazias geradas pela exportação do Excel.
- `pd.notna(...)` com valores padrão (`0`, `None`, `"00:00:00"`) para campos nulos.
- `str(...).strip()` nos textos e conversão para `float`/`int` nos campos numéricos.
- Senha lida de `os.environ.get("DB_PASSWORD", "senha_exemplo")`, sem credencial gravada no arquivo.

## Conferência final

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |
