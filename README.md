# AplicativoDeRotas

Aplicativo mobile desenvolvido para a disciplina de Engenharia de Software 2. O projeto auxilia profissionais autônomos de assistência técnica a gerenciar clientes, ordens de serviço e, futuramente, planejar rotas de atendimento considerando distância e prioridade.

## Funcionalidades implementadas

- Cadastro, consulta, edição e exclusão de clientes;
- Identificador interno para cada cliente;
- Pesquisa de clientes por nome, telefone, endereço, bairro, cidade ou ID;
- Armazenamento local com SQLite.
- Cadastro e consulta de ordens de serviço;
- Catálogo inicial pesquisável de ar-condicionado por marca, modelo, BTUs e potência.
- Planejamento de rota por OS ou cliente, com sequência otimizada;
- Mapa OpenStreetMap com traçado azul, distância e tempo estimados.

## Rotas

A aba Rotas permite selecionar várias OS ou vários clientes. O app localiza os
endereços com BrasilAPI e Nominatim/OpenStreetMap, calcula distâncias rodoviárias
e o traçado com OSRM e apresenta a sequência recomendada no mapa. Não é
necessária chave de API nem cartão de crédito. Veja [o guia de rotas](docs/ROTAS.md).
As prioridades das OS ficam para uma próxima etapa.

## Tecnologias utilizadas

- Flutter;
- Dart;
- SQLite (`sqflite`).
