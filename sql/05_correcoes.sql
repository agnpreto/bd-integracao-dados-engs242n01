-- 05_correcoes
-- Nome: Equipe CoreData (Ana Júlia Pantoja Chagas e Rafaela da Silva Tavares)
-- Correção dos dados após a importação (PostgreSQL). Rodar DEPOIS de importar.py.
--
-- Princípios:
--   * a planilha original não é alterada; as correções são feitas no banco;
--   * antes de corrigir, o estado original de cada tabela é copiado para bkp_<tabela>;
--   * cada alteração fica registrada em correcao_log (valor antes, valor depois, motivo);
--   * o script pode ser rodado mais de uma vez (não duplica nada);
--   * só se corrige o que tem regra objetiva. O que depende de decisão do cliente
--     (preços, datas, fornecedor) NÃO é alterado: ver "NÃO CORRIGIDO" no final.

BEGIN;

-- ---------------------------------------------------------------------
-- 0. Backup do estado original e tabela de log
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bkp_fornecedor      AS SELECT * FROM public.fornecedor;
CREATE TABLE IF NOT EXISTS public.bkp_produtos_filial AS SELECT * FROM public.produtos_filial;
CREATE TABLE IF NOT EXISTS public.bkp_venda           AS SELECT * FROM public.venda;
CREATE TABLE IF NOT EXISTS public.bkp_pedido_compra   AS SELECT * FROM public.pedido_compra;
CREATE TABLE IF NOT EXISTS public.bkp_entradas_mercadoria AS SELECT * FROM public.entradas_mercadoria;

CREATE TABLE IF NOT EXISTS public.correcao_log (
    id           serial PRIMARY KEY,
    data_hora    timestamptz NOT NULL DEFAULT now(),
    codigo       varchar(10) NOT NULL,   -- C1, C2... (ver abaixo)
    tabela       varchar(50) NOT NULL,
    chave        text        NOT NULL,
    campo        varchar(50),
    valor_antes  text,
    valor_depois text,
    motivo       text        NOT NULL
);

-- ---------------------------------------------------------------------
-- C1 - Pedidos 19 e 20 sem ordem_compra, mas com entrada correspondente
-- Nos pedidos 1 a 18, ordem_compra = pedido_id, e as notas NFE19 e NFE20 trazem as ordens
-- 19 e 20 para os mesmos produtos (P19 e P20). Os pedidos ficaram com 0 por erro de preenchimento.
-- Pedidos 21 a 29 (ordem 0) NÃO são alterados: não há entrada para eles.
-- ---------------------------------------------------------------------
INSERT INTO public.correcao_log (codigo, tabela, chave, campo, valor_antes, valor_depois, motivo)
SELECT 'C1', 'pedido_compra', 'pedido_id=' || p.pedido_id || ', produto=' || p.produto_id,
       'ordem_compra', p.ordem_compra::text, p.pedido_id::text,
       'ordem_compra = 0 e existe entrada (' || e.nro_nfe || ') com ordem igual ao pedido_id, mesmo produto e filial'
FROM   public.pedido_compra p
JOIN   public.entradas_mercadoria e
       ON e.ordem_compra = p.pedido_id AND e.produto_id = p.produto_id AND e.filial_id = p.filial_id
WHERE  p.ordem_compra = 0;

UPDATE public.pedido_compra p
SET    ordem_compra = p.pedido_id
FROM   public.entradas_mercadoria e
WHERE  p.ordem_compra = 0
  AND  e.ordem_compra = p.pedido_id AND e.produto_id = p.produto_id AND e.filial_id = p.filial_id;

-- ---------------------------------------------------------------------
-- C2 - Produtos vendidos sem cadastro (P21 a P28) e filiais 2 e 3 sem cadastro
-- Cria o cadastro mínimo de cada combinação filial/produto que aparece em venda.
-- Valores: preço de venda = preço médio praticado; preço de compra e estoque = 0 (desconhecidos);
-- fornecedor = registro provisório "A CONFIRMAR". Descrição marcada como pendente de confirmação.
-- ---------------------------------------------------------------------
INSERT INTO public.fornecedor (codigo_origem, razao_social)
SELECT 'PENDENTE', 'FORNECEDOR A CONFIRMAR (cadastro provisório)'
WHERE  NOT EXISTS (SELECT 1 FROM public.fornecedor WHERE codigo_origem = 'PENDENTE');

INSERT INTO public.correcao_log (codigo, tabela, chave, campo, valor_antes, valor_depois, motivo)
SELECT 'C2', 'produtos_filial', 'filial=' || v.filial_id || ', produto=' || v.produto_id,
       'linha inteira', NULL, 'linha criada',
       'produto vendido sem cadastro nessa filial; cadastro provisório a confirmar com o cliente'
FROM  (SELECT DISTINCT filial_id, produto_id FROM public.venda) v
WHERE  NOT EXISTS (SELECT 1 FROM public.produtos_filial p
                   WHERE p.filial_id = v.filial_id AND p.produto_id = v.produto_id);

INSERT INTO public.produtos_filial
       (filial_id, produto_id, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor)
SELECT v.filial_id, v.produto_id,
       'Produto ' || SUBSTRING(v.produto_id FROM 2) || ' (cadastro a confirmar)',
       0, ROUND(AVG(v.valor_unitario), 4), 0, ROUND(AVG(v.valor_unitario), 4),
       (SELECT idfornecedor FROM public.fornecedor WHERE codigo_origem = 'PENDENTE')
FROM   public.venda v
WHERE  NOT EXISTS (SELECT 1 FROM public.produtos_filial p
                   WHERE p.filial_id = v.filial_id AND p.produto_id = v.produto_id)
GROUP  BY v.filial_id, v.produto_id;

-- Agora toda venda tem cadastro: a FK pode existir (antes ela barraria os dados da planilha)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_venda_produto') THEN
        ALTER TABLE public.venda
            ADD CONSTRAINT fk_venda_produto FOREIGN KEY (filial_id, produto_id)
            REFERENCES public.produtos_filial (filial_id, produto_id);
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- C3 - Quantidade fracionada em unidade "UN"
-- Unidade (UN) não admite fração (38,6 UN). Hipótese adotada: a unidade está errada e o item é vendido
-- por peso. Troca-se a unidade para KG e mantém-se a quantidade, o que preserva os totais de
-- quantidade e de R$. HIPÓTESE A CONFIRMAR COM O CLIENTE (o valor antigo fica em correcao_log).
-- ---------------------------------------------------------------------
INSERT INTO public.correcao_log (codigo, tabela, chave, campo, valor_antes, valor_depois, motivo)
SELECT 'C3', 'venda', 'venda_id=' || venda_id || ', produto=' || produto_id,
       'unidade_medida', unidade_medida, 'KG',
       'quantidade fracionada (' || qtde_vendida || ') em unidade UN; hipótese: item vendido por peso'
FROM   public.venda
WHERE  unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida);

UPDATE public.venda
SET    unidade_medida = 'KG'
WHERE  unidade_medida = 'UN' AND qtde_vendida <> TRUNC(qtde_vendida);

-- ---------------------------------------------------------------------
-- C4 - qtde_entregue do pedido diferente da quantidade realmente recebida na nota
-- A entrada de mercadoria (nota fiscal) é o registro físico do recebimento; qtde_entregue do pedido
-- passa a ser a soma do recebido nas entradas ligadas pela ordem_compra. qtde_pendente (coluna
-- gerada) é recalculada pelo banco. Pedidos sem entrada ficam como estão.
-- ---------------------------------------------------------------------
INSERT INTO public.correcao_log (codigo, tabela, chave, campo, valor_antes, valor_depois, motivo)
SELECT 'C4', 'pedido_compra', 'pedido_id=' || p.pedido_id || ', produto=' || p.produto_id,
       'qtde_entregue', p.qtde_entregue::text, r.recebido::text,
       'qtde_entregue do pedido diferente da soma recebida nas entradas da ordem ' || p.ordem_compra
FROM   public.pedido_compra p
JOIN  (SELECT ordem_compra, produto_id, filial_id, SUM(qtde_recebida) AS recebido
       FROM   public.entradas_mercadoria
       GROUP  BY ordem_compra, produto_id, filial_id) r
       ON r.ordem_compra = p.ordem_compra AND r.produto_id = p.produto_id AND r.filial_id = p.filial_id
WHERE  p.ordem_compra <> 0 AND p.qtde_entregue <> r.recebido;

UPDATE public.pedido_compra p
SET    qtde_entregue = r.recebido
FROM  (SELECT ordem_compra, produto_id, filial_id, SUM(qtde_recebida) AS recebido
       FROM   public.entradas_mercadoria
       GROUP  BY ordem_compra, produto_id, filial_id) r
WHERE  r.ordem_compra = p.ordem_compra AND r.produto_id = p.produto_id AND r.filial_id = p.filial_id
  AND  p.ordem_compra <> 0 AND p.qtde_entregue <> r.recebido;

-- ---------------------------------------------------------------------
-- C5 - Prevenção: data de entrega não pode ser anterior à data do pedido
-- NOT VALID: vale para novas linhas e alterações; as 20 linhas antigas com o problema
-- continuam listadas na validação (E8) até o cliente informar a data correta.
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_pedido_datas') THEN
        ALTER TABLE public.pedido_compra
            ADD CONSTRAINT ck_pedido_datas
            CHECK (data_entrega IS NULL OR data_pedido IS NULL OR data_entrega >= data_pedido) NOT VALID;
    END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------
-- NÃO CORRIGIDO (depende de decisão do cliente; alterar seria inventar dado)
--   E4/E16/E17  preços: o preço vendido é o fato da venda; o cadastro pode ser preço de tabela.
--               Preço de venda abaixo do custo e o significado de preco_unitario precisam de resposta.
--   E5          valores iguais em produtos diferentes: só o cliente sabe o preço real.
--   E8/E15      datas fora de ordem: não há como saber qual das duas datas está errada.
--   E9          pedidos 21 a 29 parecem repetição dos pedidos 12 a 20 (mesmas datas e preço, quantidade
--               diferente). Foram MANTIDOS: são os pedidos sem recebimento que a consulta 2.2 lista;
--               excluí-los seria apagar requisições possivelmente reais.
--   E10         fornecedor do pedido x do cadastro: o pedido pode legitimamente usar outro fornecedor.
--   E12/E14     recebido maior que o pedido e custo da nota diferente do pedido: divergência real
--               de negócio, não erro de digitação.
--   E6          horário 08:00:00 e item 1 em todas as vendas: não há dado melhor para colocar no lugar.
-- ---------------------------------------------------------------------

-- Conferência do que foi alterado
SELECT codigo, tabela, COUNT(*) AS alteracoes FROM public.correcao_log GROUP BY codigo, tabela ORDER BY codigo;
