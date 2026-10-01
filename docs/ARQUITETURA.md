# Arquitetura da Boleta Operacional

## Camadas

### 1. UI
Responsável somente por:
- criar/remover objetos gráficos;
- exibir estado;
- receber cliques;
- encaminhar comandos.

### 2. Command Layer
Representa ações operacionais:
- BUY;
- SELL;
- CLOSE BUY;
- CLOSE SELL;
- CLOSE ALL;
- RED/LOCK (fase posterior);
- REDUCE (fase posterior).

A UI não deve manipular ordens diretamente.

### 3. Execution Layer
Responsável por:
- validar símbolo;
- validar lote;
- validar spread;
- validar trading permitido;
- enviar/fechar ordens;
- registrar resultado e erro.

### 4. Order State
Responsável por consolidar:
- quantidade de ordens;
- BUY lots;
- SELL lots;
- exposição líquida;
- preço médio;
- lucro;
- drawdown operacional;
- Magic Number.

### 5. Safety
Antes de qualquer ação:
- validar contexto;
- validar parâmetros;
- registrar intenção;
- executar;
- registrar resultado.

## Seleção de ordens

A primeira versão deve usar:

- Symbol = símbolo do gráfico;
- Magic = parâmetro configurável;
- Type = BUY/SELL;
- estado = OPEN.

Isso evita que a boleta interfira em operações de outros EAs ou símbolos.

## Test Mode

O Test Mode deve impedir envio real de ordens e registrar:

`[BOLETA][TEST] ACTION=BUY LOT=0.01 SYMBOL=XAUUSD`

Somente após validação do fluxo o modo LIVE será utilizado.

## Não fazer no MVP

Não incluir ainda:
- martingale;
- recovery;
- grid automático;
- trailing;
- fechamento automático por lucro;
- regras R4/R5/R10;
- lógica do Zeus.

Essas funcionalidades devem ser adicionadas como módulos independentes.
