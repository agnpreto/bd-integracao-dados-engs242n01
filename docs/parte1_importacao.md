# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

## Estrutura da planilha

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
|  |  |  |  |

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

| Erro | Efeito | Correção |
| --- | --- | --- |
|  |  |  |

## Tratamentos aplicados aos dados

(conversão de tipos, validações, normalizações)

## Conferência final

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor |  |  |
| produtos_filial |  |  |
| pedido_compra |  |  |
| entradas_mercadoria |  |  |
| venda |  |  |
