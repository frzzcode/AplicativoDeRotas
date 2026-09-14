import 'package:flutter/material.dart';
import '../../data/models/cliente.dart';
import '../../data/repositories/cliente_repository.dart';

// Tela com um formulário simples. Cada TextField tem um
// "controller" que guarda o texto digitado pelo usuário.
class NovoClienteScreen extends StatefulWidget {
  final Cliente? cliente;

  const NovoClienteScreen({super.key, this.cliente});

  @override
  State<NovoClienteScreen> createState() => _NovoClienteScreenState();
}

class _NovoClienteScreenState extends State<NovoClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClienteRepository _repository = ClienteRepository();

  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _observacoesController = TextEditingController();

  bool get _editando => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    final cliente = widget.cliente;
    if (cliente == null) return;

    _nomeController.text = cliente.nome;
    _telefoneController.text = cliente.telefone ?? '';
    _enderecoController.text = cliente.endereco ?? '';
    _numeroController.text = cliente.numero ?? '';
    _complementoController.text = cliente.complemento ?? '';
    _bairroController.text = cliente.bairro ?? '';
    _cidadeController.text = cliente.cidade ?? '';
    _observacoesController.text = cliente.observacoes ?? '';
  }

  // Chamado quando o usuário toca em "Salvar"
  Future<void> _salvarCliente() async {
    // valida se o campo obrigatório (nome) foi preenchido
    if (!_formKey.currentState!.validate()) return;

    final cliente = Cliente(
      id: widget.cliente?.id,
      nome: _nomeController.text,
      telefone: _textoOuNulo(_telefoneController),
      endereco: _textoOuNulo(_enderecoController),
      numero: _textoOuNulo(_numeroController),
      complemento: _textoOuNulo(_complementoController),
      bairro: _textoOuNulo(_bairroController),
      cidade: _textoOuNulo(_cidadeController),
      observacoes: _textoOuNulo(_observacoesController),
    );

    if (_editando) {
      await _repository.atualizar(cliente);
    } else {
      await _repository.inserir(cliente);
    }

    // fecha a tela e volta para a lista
    if (mounted) Navigator.pop(context, true);
  }

  String? _textoOuNulo(TextEditingController controller) {
    final texto = controller.text.trim();
    return texto.isEmpty ? null : texto;
  }

  @override
  void dispose() {
    // libera a memória dos controllers quando a tela é fechada
    _nomeController.dispose();
    _telefoneController.dispose();
    _enderecoController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar Cliente' : 'Novo Cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nomeController,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'Informe o nome do cliente';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _telefoneController,
              decoration: const InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(
              controller: _enderecoController,
              decoration: const InputDecoration(labelText: 'Endereço'),
            ),
            TextFormField(
              controller: _numeroController,
              decoration: const InputDecoration(labelText: 'Número'),
              keyboardType: TextInputType.streetAddress,
            ),
            TextFormField(
              controller: _complementoController,
              decoration: const InputDecoration(labelText: 'Complemento'),
            ),
            TextFormField(
              controller: _bairroController,
              decoration: const InputDecoration(labelText: 'Bairro'),
            ),
            TextFormField(
              controller: _cidadeController,
              decoration: const InputDecoration(labelText: 'Cidade'),
            ),
            TextFormField(
              controller: _observacoesController,
              decoration: const InputDecoration(labelText: 'Observações'),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            // Botão grande, fácil de tocar - como pedido no documento
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _salvarCliente,
                child: Text(
                  _editando ? 'Salvar alterações' : 'Salvar cliente',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
