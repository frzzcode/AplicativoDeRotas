// Representação interna de um ponto do mapa. O usuário nunca precisa digitar
// esses valores: o app os obtém automaticamente a partir do endereço.
class Coordenada {
  final double latitude;
  final double longitude;

  const Coordenada({required this.latitude, required this.longitude});

  String get osrm => '$longitude,$latitude';
}
