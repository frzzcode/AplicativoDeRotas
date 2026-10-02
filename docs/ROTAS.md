# Rotas — funcionamento atual

A aba **Rotas** permite selecionar várias ordens de serviço pelo ID ou vários
clientes pelo ID/nome. A localização sempre vem do cadastro do cliente ligado
à seleção. A origem (casa ou oficina) é informada no momento do cálculo.

Não é necessária chave de API, conta em nuvem, cartão de crédito, servidor
local ou `adb reverse`. O celular precisa apenas de acesso à internet.

## Como o cálculo funciona

1. O Nominatim/OpenStreetMap converte cada endereço em latitude e longitude.
2. As coordenadas do cliente são salvas internamente no banco local. O usuário
   não precisa vê-las nem digitá-las.
3. O OSRM calcula uma matriz de distâncias pelas ruas, não em linha reta.
4. O aplicativo encontra a melhor sequência: solução exata para até 10 paradas
   intermediárias e heurística com melhoria 2-opt para quantidades maiores.
5. O OSRM retorna o traçado final e o aplicativo o desenha em azul sobre o mapa
   do OpenStreetMap, com origem e atendimentos numerados.

Se o endereço de um cliente for alterado, as coordenadas antigas são removidas
automaticamente e serão recalculadas na próxima rota. Rua e cidade são os dados
mínimos para selecionar uma parada. UF e CEP são opcionais, mas aumentam a
precisão quando existem ruas ou cidades com nomes semelhantes.

Nesta etapa a rota pode voltar à origem ou terminar em um atendimento fixo. A
prioridade da OS ainda não participa do cálculo. A etapa futura deverá processar
primeiro as OS de prioridade Alta, depois Média e por último Baixa, otimizando a
ordem dentro desses grupos.

## Arquivos principais

- `lib/data/database/db_helper.dart`: banco e migração dos novos campos.
- `lib/data/models/cliente.dart`: dados públicos e coordenadas internas.
- `lib/data/services/geocodificacao_service.dart`: endereço para coordenadas.
- `lib/data/services/rota_service.dart`: chamadas ao OSRM e montagem do resultado.
- `lib/domain/services/otimizador_rota.dart`: algoritmo que ordena as paradas.
- `lib/presentation/widgets/rota_mapa.dart`: mapa, linha azul e marcadores.
- `lib/presentation/screens/rotas_screen.dart`: seleção e exibição da rota.

## Serviços públicos e limites

Este protótipo acadêmico usa as instâncias públicas do Nominatim, OSRM e os
blocos de mapa do OpenStreetMap. O app identifica suas requisições, limita a
geocodificação a uma consulta por segundo e reaproveita coordenadas já obtidas.
Foram limitadas 20 paradas por cálculo.

Esses serviços são adequados para testes e uso leve, mas não oferecem garantia
de disponibilidade. Se o aplicativo crescer, a arquitetura permite trocar os
endereços dos serviços ou hospedar instâncias próprias sem reescrever as telas.
As estimativas não incluem trânsito em tempo real nem a duração dos serviços.

## Preparar o Windows e testar

`flutter_map` usa dependências que precisam de suporte a links simbólicos. No
Windows, ative **Configurações > Sistema > Para desenvolvedores > Modo de
Desenvolvedor** uma única vez. Depois execute:

```powershell
flutter pub get
flutter run
```

O projeto fixa `path_provider_android` em 2.2.23. A série 2.3 passou a usar JNI
e exige a instalação separada do Android SDK 35; a versão fixada mantém o mesmo
cache local e é compatível com o ambiente Android atual deste projeto.

Ao testar, use endereços reais e completos. Confira se todos os marcadores
aparecem, se a linha azul passa pelas ruas e se a lista segue a mesma numeração
do mapa.
