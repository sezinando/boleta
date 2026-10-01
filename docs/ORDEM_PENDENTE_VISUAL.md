# V0.2 — Ordem Pendente Visual

## Conceito

A boleta possui dois conceitos diferentes:

1. **Ordem a mercado:** BUY/SELL envia imediatamente, respeitando TEST MODE e validações.
2. **Ordem pendente visual:** o primeiro clique **não envia ordem**. Ele cria uma ferramenta gráfica para projetar a operação.

## Fluxo da ordem pendente visual

### Estado 0 — Inicial

- botão mostra `DESENHAR ORDEM`;
- nenhuma linha operacional existe;
- nenhum envio é possível por esse fluxo.

### Estado 1 — Planejamento

Ao pressionar `DESENHAR ORDEM`:

- é selecionada a direção atualmente indicada por BUY/SELL;
- é criada uma linha azul de Entrada;
- é criada uma linha vermelha de Stop Loss;
- é criada uma linha verde de Take Profit;
- as três linhas podem ser arrastadas diretamente no gráfico;
- nenhuma ordem é enviada.

### Estado 2 — Cálculo dinâmico

Sempre que uma linha for movimentada, a boleta recalcula:

- distância Entrada → Stop em pontos;
- distância Entrada → Gain em pontos;
- risco financeiro em moeda da conta;
- impacto percentual sobre o saldo;
- ganho financeiro;
- impacto percentual positivo sobre o saldo;
- relação R:R;
- tipo resultante da pendente: BUY LIMIT, BUY STOP, SELL LIMIT ou SELL STOP.

O cálculo utiliza `MODE_TICKVALUE` e `MODE_TICKSIZE` do símbolo para converter a distância de preço em valor monetário por lote.

## Estado 3 — Confirmação

O operador pressiona `CONFIRMAR ORDEM`.

Somente neste momento:

- a geometria é validada;
- o tipo da ordem pendente é determinado;
- o lote é normalizado;
- spread e permissão de negociação são validados;
- no LIVE MODE, a ordem é enviada;
- no TEST MODE, a ação é apenas registrada no Journal.

Após sucesso, as três linhas são removidas e a boleta retorna ao estado inicial.

## Estado 4 — Cancelamento

`CANCELAR` remove as linhas sem enviar ordem e retorna ao estado inicial.

## Regra de segurança

Mover qualquer linha nunca envia uma ordem.

O único ponto de entrada para a execução da ordem pendente é `CONFIRMAR ORDEM`.

## Lote

O lote pode ser:

- digitado diretamente;
- decrementado pelo botão `−`;
- incrementado pelo botão `+`.

O lote é normalizado conforme o lote mínimo/máximo e o passo operacional configurado.

## Direção

BUY e SELL também definem a direção usada pelo planejador visual.

Se o planejador estiver ativo, clicar BUY ou SELL muda a direção do planejamento sem enviar uma ordem a mercado.

## Próximas evoluções

- etiquetas de preço diretamente nas linhas;
- painel de cálculo mais rico;
- alerta visual quando R:R estiver abaixo de um limite;
- cálculo sobre Equity além de Balance;
- validação de distância mínima da corretora;
- seleção explícita de LIMIT/STOP;
- confirmação visual antes de ações destrutivas.
