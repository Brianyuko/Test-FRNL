import 'package:flutter/material.dart';
import 'employee.dart';
import 'main.dart';

class EmployeeView extends StatelessWidget {
  final List<Employee> employees;
  final Map<String, String> serverVersions;
  final MyHomePageState homePageState;

  const EmployeeView({
    super.key,
    required this.employees,
    required this.serverVersions,
    required this.homePageState,
  });

  String _formatDate(String isoDate) =>
      isoDate.replaceFirst('T', ' ').split('.').first;

  String _syncStatus(Employee employee) {
    final serverCreatedOn = serverVersions[employee.employeeId];
    if (serverCreatedOn == null) return 'Tidak ada di Mock Server';
    if (serverCreatedOn != employee.createdOn) return 'Perlu sync';
    return 'Sinkron';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Lokal: ${employees.length} employee · Mock Server: ${serverVersions.length} employee',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: employees.length,
            itemBuilder: (BuildContext context, int index) {
              final employee = employees[index];
              return Card(
                child: ExpansionTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(20.0),
                    child: Image.memory(
                      employee.faces.first.faceJpg,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(employee.name),
                  subtitle: Text(
                    '${employee.faces.length}/$maxFacesPerEmployee foto · ${_syncStatus(employee)}\n'
                    'created_on: ${_formatDate(employee.createdOn)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) =>
                        homePageState.onEmployeeAction(employee, action),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'server_update',
                        child: Text('Simulasi: update di Mock Server'),
                      ),
                      PopupMenuItem(
                        value: 'server_delete',
                        child: Text('Simulasi: hapus di Mock Server'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Hapus employee'),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < employee.faces.length; i++)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.memory(
                                    employee.faces[i].faceJpg,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () =>
                                        homePageState.deleteFace(employee, i),
                                    child: const CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.close, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
