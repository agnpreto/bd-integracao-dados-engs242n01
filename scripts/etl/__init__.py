"""Importação da planilha base_teste.xlsx em camadas (arquitetura medalhão).

O código é o do script original (estagiário), repartido entre as camadas SEM
alteração de lógica, para que os erros sejam mapeados e corrigidos um a um:

config  -> configurações e conexão          (topo do script original)
bronze  -> leitura das abas da planilha     (pd.read_excel de cada bloco)
prata   -> conversões de cada linha         (excel_para_data e as tuplas de valores)
carga   -> INSERT no banco                  (laços for/try/rollback de cada bloco)

O ponto de entrada é scripts/importar.py.
"""
