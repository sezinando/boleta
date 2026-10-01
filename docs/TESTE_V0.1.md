# Teste V0.1 — Boleta Operacional

## Objetivo

Validar o fluxo da boleta sem risco de envio real.

## Pré-requisitos

- MetaTrader 4.
- Gráfico do símbolo a ser testado.
- Expert Advisor `BOLETA_OPERACIONAL.mq4`.
- `InpTestMode=true`.

## Teste 1 — Inicialização

Esperado:
- painel aparece;
- símbolo atual é mostrado;
- Magic Number é mostrado;
- modo TEST MODE é mostrado;
- contagem de BUY/SELL é exibida.

## Teste 2 — BUY em TEST MODE

Clicar BUY.

Esperado:
- nenhuma ordem real é aberta;
- Journal registra `[BOLETA][TEST] ACTION=BUY`.

## Teste 3 — SELL em TEST MODE

Clicar SELL.

Esperado:
- nenhuma ordem real é aberta;
- Journal registra `[BOLETA][TEST] ACTION=SELL`.

## Teste 4 — CLOSE em TEST MODE

Com ordens existentes do Magic selecionado, clicar CLOSE BUY, CLOSE SELL e CLOSE ALL.

Esperado:
- nenhuma ordem real é fechada;
- cada ação é registrada no Journal.

## Teste 5 — LIVE controlado

Somente depois dos testes anteriores:
1. usar conta DEMO;
2. usar lote mínimo;
3. validar Magic;
4. validar símbolo;
5. validar spread;
6. executar BUY;
7. confirmar ticket;
8. executar CLOSE BUY.

## Critério de aprovação

Não avançar para RED/LOCK, REDUCE ou gestão de cesta enquanto:
- os botões básicos não estiverem funcionando;
- o filtro Symbol + Magic não estiver comprovado;
- TEST MODE não estiver comprovado;
- BUY/SELL/CLOSE não estiverem validados no Journal.
