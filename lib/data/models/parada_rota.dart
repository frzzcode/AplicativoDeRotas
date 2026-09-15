import 'cliente.dart';

// Uma seleção aponta para uma OS ou um cliente, sem criar outro cadastro.
class ParadaRota {
  final String chave;
  final String titulo;
  final Cliente cliente;

  const ParadaRota({
    required this.chave,
    required this.titulo,
    required this.cliente,
  });

  bool get enderecoValido =>
      (cliente.endereco?.trim().isNotEmpty ?? false) &&
      (cliente.cidade?.trim().isNotEmpty ?? false);

  String get endereco => [
    cliente.endereco,
    cliente.numero,
    cliente.bairro,
    cliente.cidade,
    'Brasil',
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
}
