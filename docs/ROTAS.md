# Rotas — configuração e funcionamento

A aba Rotas permite selecionar várias OS pelo ID ou clientes por ID/nome.
Os endereços são lidos do cadastro de clientes. A seleção permanece enquanto
você pesquisa outro ID. Use Atualizar após editar cadastros em outra aba.
Rua e cidade são obrigatórias para enviar uma parada; confira número, bairro
e UF (por enquanto inclua a UF no campo cidade, por exemplo Joinville - SC).
Complementos como apartamento não são enviados ao cálculo.

Escolha uma origem completa e o fim: voltar à origem ou um atendimento fixo.
As demais paradas são reorganizadas pelo Google. A Routes API otimiza tempo,
considerando distância e conversões, sem garantir o mínimo absoluto em km.
Nesta etapa não há prioridades, janelas de horário, histórico persistido ou
mapa embutido: os mapas e os trajetos abrem no Google Maps instalado/navegador.
A seleção e o resultado permanecem durante a sessão; fechar o app os descarta.
São até 25 atendimentos por cálculo. OS do mesmo cliente continuam como
atendimentos distintos, podendo ter o mesmo endereço na sequência.

## 1. Google Cloud (necessário antes do cálculo real)

1. Crie/selecione um projeto em https://console.cloud.google.com/.
2. Vincule uma conta de faturamento e ative **Routes API**.
3. Crie uma chave de API e restrinja seu uso à **Routes API**. Ela ficará
   exclusivamente no serviço local, nunca no código/aplicativo/GitHub.
4. Configure cotas diárias e alertas de orçamento conforme o seu limite.
   Otimização é um recurso cobrado; alertas de orçamento não bloqueiam gastos.
5. Não envie a chave por mensagens nem a coloque em arquivos versionados.

Documentação oficial:
- https://developers.google.com/maps/documentation/routes/get-api-key
- https://developers.google.com/maps/documentation/routes/opt-way
- https://developers.google.com/maps/documentation/routes/usage-and-billing
- https://developers.google.com/maps/documentation/urls/get-started

## 2. Iniciar o serviço local no Windows

Na raiz do projeto, em um terminal PowerShell do VS Code:

```powershell
$chaveRotas = Read-Host 'Chave da Routes API' -AsSecureString
$env:GOOGLE_ROUTES_API_KEY = [System.Net.NetworkCredential]::new('', $chaveRotas).Password
$tokenRotas = Read-Host 'Token local (24 ou mais caracteres aleatórios)' -AsSecureString
$env:ROTAS_API_TOKEN = [System.Net.NetworkCredential]::new('', $tokenRotas).Password
dart server/main.dart
```

Mantenha este terminal aberto. O servidor escuta apenas 127.0.0.1:8080.
O token local é uma senha independente da chave do Google.

## 3. Conectar Android físico ou emulador

Em outro terminal:

```powershell
adb devices
adb -s ID_DO_DISPOSITIVO reverse tcp:8080 tcp:8080
```

Se adb não estiver no PATH, use o executável `platform-tools/adb.exe` da
instalação do Android SDK. Essa ligação funciona também por USB, sem liberar
uma porta no firewall ou expor o servidor à rede. Refaça após desconectar.

Copie `config/rotas.example.json` para `config/rotas.local.json` e substitua
o token de exemplo pelo mesmo token usado no terminal. Este arquivo está
ignorado pelo Git. **Não coloque a chave do Google nele.**

```powershell
flutter run -d ID_DO_DISPOSITIVO --dart-define-from-file=config/rotas.local.json
```

Pare e execute novamente após alterar configuração ou código Android.
O acesso HTTP local é permitido apenas no build de depuração.

## Fluxo dos arquivos

- `lib/data/models/parada_rota.dart`: identifica a seleção e monta o endereço.
- `lib/presentation/screens/rotas_screen.dart`: seleção, origem, destino e resultado.
- `lib/data/services/rota_service.dart`: envia pedido ao serviço e valida a sequência.
- `server/main.dart`: autentica o pedido e mantém a chave no computador.
- `server/google_routes.dart`: chama Compute Routes e converte índices na ordem das seleções.
- `MainActivity.kt`: abre links do Maps a pedido do Flutter.

Google Maps URLs possui limites de paradas nos celulares; abrimos até três
intermediárias por link, com a última parada de uma parte iniciando a seguinte.
Isso não divide a otimização: a consulta original calcula todas juntas.
Distância e tempo são estimativas sem trânsito em tempo real e sem duração
dos serviços; o Maps pode recalcular o caminho conforme suas próprias condições.

## Testes e publicação futura

`dart server/rotas_test.dart` testa retorno à origem, destino fixo, correspondência
dos índices, limites e respostas inconsistentes sem consumir API.
Para validar de ponta a ponta, use endereços conhecidos, gere a rota, confira
todas as paradas no Maps e teste os dois tipos de término.

Este servidor é para desenvolvimento local. Para o profissional usar o app
sem computador será necessário hospedá-lo em HTTPS com autenticação por usuário,
limites de requisições e gestão de segredos. O token compartilhado atual serve
somente para os testes. Nenhuma hospedagem ou faturamento é ativado pelo código.
