import 'package:flutter/material.dart';
import '../../data/models/cliente.dart';
import '../../data/repositories/cliente_repository.dart';
import 'cliente_detalhes_screen.dart';
import 'novo_cliente_screen.dart';

// Essa tela SÓ desenha coisa na tela e chama o repositório.
// Ela não sabe nada sobre SQL - só sabe que existe um
// ClienteRepository que devolve uma lista de Cliente.
class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final ClienteRepository _repository = ClienteRepository();
  final TextEditingController _pesquisaController = TextEditingController();

  // Guarda a lista de clientes carregada do banco.
  // Usamos um Future porque ler do banco é uma operação assíncrona
  // (não trava a tela enquanto espera a resposta).
  late Future<List<Cliente>> _clientesFuture;

  @override
  void initState() {
    super.initState();
    _carregarClientes();
  }

  // Busca os clientes de novo no banco e atualiza a tela.
  // Chamamos isso toda vez que algo pode ter mudado (ex: depois
  // de cadastrar um cliente novo).
  void _carregarClientes() {
    setState(() {
      _clientesFuture = _repository.listarTodos();
    });
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  List<Cliente> _filtrarClientes(List<Cliente> clientes) {
    final termo = _pesquisaController.text.trim().toLowerCase();
    if (termo.isEmpty) return clientes;

    return clientes.where((cliente) {
      final campos = [
        cliente.id?.toString(),
        cliente.nome,
        cliente.telefone,
        cliente.endereco,
        cliente.numero,
        cliente.complemento,
        cliente.bairro,
        cliente.cidade,
      ];
      return campos.any(
        (campo) => campo?.toLowerCase().contains(termo) ?? false,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: FutureBuilder<List<Cliente>>(
        future: _clientesFuture,
        builder: (context, snapshot) {
          // Enquanto o banco não respondeu, mostra um carregando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final todosClientes = snapshot.data ?? [];
          final clientes = _filtrarClientes(todosClientes);

          // Lista vazia - mostra uma mensagem amigável
          if (todosClientes.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum cliente cadastrado ainda.\nToque no + para adicionar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          // Lista com os clientes encontrados
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _pesquisaController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Pesquisar clientes',
                    hintText: 'Nome, local ou ID',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _pesquisaController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar pesquisa',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _pesquisaController.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              Expanded(
                child: clientes.isEmpty
                    ? const Center(child: Text('Nenhum cliente encontrado.'))
                    : ListView.builder(
                        itemCount: clientes.length,
                        itemBuilder: (context, index) {
                          final cliente = clientes[index];
                          return ListTile(
                            title: Text(cliente.nome),
                            subtitle: Text(
                              'ID #${cliente.id} • ${cliente.telefone ?? 'Sem telefone'}',
                            ),
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ClienteDetalhesScreen(cliente: cliente),
                                ),
                              );
                              _carregarClientes();
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      // Botão flutuante grande, fácil de tocar no celular -
      // como pedido no documento do projeto
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Abre a tela de cadastro e espera ela fechar
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NovoClienteScreen()),
          );
          // Quando voltar, recarrega a lista (pode ter um cliente novo)
          _carregarClientes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
