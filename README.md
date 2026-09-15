# AplicativoDeRotas

Aplicativo mobile desenvolvido para a disciplina de Engenharia de Software 2. O projeto auxilia profissionais autônomos de assistência técnica a gerenciar clientes, ordens de serviço e, futuramente, planejar rotas de atendimento considerando distância e prioridade.

## Funcionalidades implementadas

- Cadastro, consulta, edição e exclusão de clientes;
- Identificador interno para cada cliente;
- Pesquisa de clientes por nome, telefone, endereço, bairro, cidade ou ID;
- Armazenamento local com SQLite.
- Cadastro e consulta de ordens de serviço;
- Catálogo inicial pesquisável de ar-condicionado por marca, modelo, BTUs e potência.

## Rotas (integração em configuração)

A aba Rotas permite seleção múltipla de OS/clientes e prepara o cálculo da
sequência pela Google Routes API. O cálculo real exige ativação da API,
faturamento e configuração do serviço local. Veja [o guia de rotas](docs/ROTAS.md).
O mapa abre no Google Maps do Android. Prioridades ficam para outra etapa.

## Tecnologias utilizadas

- Flutter;
- Dart;
- SQLite (`sqflite`).
