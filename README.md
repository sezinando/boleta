# BOLETA — Boleta Operacional

Repositório oficial da boleta operacional MT4.

## Objetivo

Construir uma boleta operacional independente do SENTINEL, com arquitetura simples, previsível e auditável para execução manual de ordens e gestão operacional da cesta.

## Princípios

- **Segurança antes de automação:** nenhuma regra de recuperação deve ser embutida na primeira versão.
- **Separação de responsabilidades:** interface, execução e gestão de ordens ficam isoladas.
- **Estado explícito:** a boleta deve sempre mostrar o estado operacional atual.
- **Ações reversíveis quando possível:** fechar/reduzir posições exige confirmação quando houver risco operacional relevante.
- **Compatibilidade MT4/MQL4:** código orientado ao ambiente MetaTrader 4.
- **Evolução incremental:** cada funcionalidade entra com documentação e teste.

## MVP

1. Identificação do símbolo e conta.
2. Visualização de BUY/SELL, lotes, preço médio, lucro e exposição.
3. Execução manual de BUY e SELL.
4. Fechamento de posições BUY/SELL.
5. Close All.
6. Seleção por Magic Number.
7. Registro operacional no Journal.
8. Modo TEST/DRY-RUN antes de habilitar execução real.

## Estrutura

```
MQL4/
  Experts/
    BOLETA_OPERACIONAL.mq4

docs/
  ARQUITETURA.md
  ROADMAP.md
```

## Regra importante

A boleta não deve assumir comportamento do Zeus, AW Recovery ou SENTINEL sem que a regra seja explicitamente especificada e testada.
