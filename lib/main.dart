// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'about.dart';
import 'settings.dart';
import 'employee.dart';
import 'employeeview.dart';
import 'facestore.dart';
import 'facedetectionview.dart';

typedef EnrollTarget = ({String id, String name});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FaceStore.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Face Recognition',
        theme: ThemeData(
          // Define the default brightness and colors.
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: MyHomePage(title: 'Face Recognition'));
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  String _warningState = "";
  bool _visibleWarning = false;
  List<Employee> _employees = [];
  Map<String, String> _serverVersions = {};

  final _facesdkPlugin = FacesdkPlugin();

  @override
  void initState() {
    super.initState();

    init();
  }

  Future<void> init() async {
    int facepluginState = -1;
    String warningState = "";
    bool visibleWarning = false;

    try {
      if (Platform.isAndroid) {
        await _facesdkPlugin
            .setActivation(
                "PjnUMBHfBhtT/oa8ySF6mwinqAj2oBls4vSsDmsdrpL/xHwPLtq9Dll/4IIe2KIkXQEh81/21yQhK"
                "AUQOmCvuuNcaZX+DS/EBhinprH+Y+XBzdGz2KWKEZjeDnhoSo8ql1CDDmMiCdRleZ7PbcPv10/dkdI"
                "mwGLFerErQxL/qKIz+8CQqOryw/7RjpNgkbpufY+Nd635HN3dbG4Z+AKdpsl2hB+hl/16O1IhQiGia"
                "4V2+1q9PsFfj6HFST+CQD17kXfsXkoQzMsFwQn4BSuyiiPUdHfJ+EFYMoeF96Jhqfe1CH3af41l0wK"
                "LNqXthBE24m96v06lDFPXkxDOCZCzug==")
            .then((value) => facepluginState = value ?? -1);
      } else {
        await _facesdkPlugin
            .setActivation(
                "LvqLS/kUqek3yNzQYaskd7H2oQZeZ/9msTJ16au/DAz0ZcDtnJUqlY6Du5YffkGKZ2oWlCrE8JBJfb"
                "rVcPvchPnZv6ZDOSZ9R1JCg+KlmyCQ2s6Xre6nhcjoAjvKbVhY3wFpwWOeKuvsCzv6hmKf5YBUMa6I"
                "yTwcqsoCKbcVq5mJDWbWpQXwKOiFXwhmyXHBruWzI1Jd6i6cNzYRixgqLWi1sS3Kak5EiHhc91TKPd"
                "LmZkLQQwWxr2OFSS8s3MRhrooAxxRU7XVglU+cg7tpqjvMcUSfbcLE8OYCV8DDIZfbBpEp5y1YN/gg"
                "OpX04tojhkSIhX9l5MRTiZfMdovaZg==")
            .then((value) => facepluginState = value ?? -1);
      }

      if (facepluginState == 0) {
        await _facesdkPlugin
            .init()
            .then((value) => facepluginState = value ?? -1);
      }
    } catch (e) {}

    // Setara saat membuka halaman login: cek created_on ke server dulu.
    final syncResult = await syncFromServer();
    debugPrint(syncResult.toString());
    await SettingsPageState.initSettings();

    final prefs = await SharedPreferences.getInstance();
    int? livenessLevel = prefs.getInt("liveness_level");

    try {
      await _facesdkPlugin
          .setParam({'check_liveness_level': livenessLevel ?? 0});
    } catch (e) {}

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    if (facepluginState == -1) {
      warningState = "Invalid license!";
      visibleWarning = true;
    } else if (facepluginState == -2) {
      warningState = "License expired!";
      visibleWarning = true;
    } else if (facepluginState == -3) {
      warningState = "Invalid license!";
      visibleWarning = true;
    } else if (facepluginState == -4) {
      warningState = "No activated!";
      visibleWarning = true;
    } else if (facepluginState == -5) {
      warningState = "Init error!";
      visibleWarning = true;
    }

    setState(() {
      _warningState = warningState;
      _visibleWarning = visibleWarning;
    });
    refreshEmployees();
  }

  void showToast(String message) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  void refreshEmployees() {
    setState(() {
      _employees = LocalStore.getEmployees();
      _serverVersions = MockServer.getVersions();
    });
  }

  Future<void> syncEmployees() async {
    final result = await syncFromServer();
    refreshEmployees();
    showToast(result.toString());
  }

  Future<void> deleteAllEmployees() async {
    await MockServer.clear();
    await LocalStore.clear();
    refreshEmployees();
    showToast("All employee deleted!");
  }

  Future<void> deleteFace(Employee employee, int index) async {
    final updated = await MockServer.removeFace(employee.employeeId, index);
    if (updated == null) {
      await LocalStore.delete(employee.employeeId);
    } else {
      await LocalStore.save(updated);
    }
    refreshEmployees();
    showToast("Foto dihapus!");
  }

  Future<void> onEmployeeAction(Employee employee, String action) async {
    switch (action) {
      case 'server_update':
        await MockServer.touch(employee.employeeId);
        showToast("created_on di Mock Server berubah, lokal belum. Tekan Sync.");
      case 'server_delete':
        await MockServer.deleteEmployee(employee.employeeId);
        showToast("Dihapus di Mock Server, lokal belum. Tekan Sync.");
      case 'delete':
        await MockServer.deleteEmployee(employee.employeeId);
        await LocalStore.delete(employee.employeeId);
        showToast("Employee dihapus!");
    }
    refreshEmployees();
  }

  Future<void> showEnrollTarget() async {
    final employees = MockServer.getEmployees();
    var newName = "";

    final target = await showDialog<EnrollTarget>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pilih Employee'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration:
                    const InputDecoration(labelText: 'Nama employee baru'),
                textCapitalization: TextCapitalization.words,
                onChanged: (value) => newName = value,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final employee in employees)
                      ListTile(
                        title: Text(employee.name),
                        subtitle: Text(
                            '${employee.faces.length}/$maxFacesPerEmployee foto'),
                        enabled: employee.faces.length < maxFacesPerEmployee,
                        onTap: () => Navigator.pop(dialogContext,
                            (id: employee.employeeId, name: employee.name)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final name = newName.trim();
              if (name.isEmpty) return;
              final exists = employees
                  .any((e) => e.name.toLowerCase() == name.toLowerCase());
              if (exists) {
                showToast("Nama sudah ada, pilih dari daftar");
                return;
              }
              Navigator.pop(dialogContext, (
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name,
              ));
            },
            child: const Text('Tambah Baru'),
          ),
        ],
      ),
    );

    if (target != null) showEnrollSource(target);
  }

  void showEnrollSource(EnrollTarget target) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Enroll foto untuk ${target.name}'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(sheetContext);
                enrollFace(target, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(sheetContext);
                enrollFace(target, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> enrollFace(EnrollTarget target, ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image == null) return;

      var rotatedImage =
          await FlutterExifRotation.rotateImage(path: image.path);

      final faces = await _facesdkPlugin.extractFaces(rotatedImage.path);
      if (faces.length == 0) {
        showToast("No face detected!");
        return;
      }
      if (faces.length > 1) {
        showToast("Terdeteksi lebih dari 1 wajah, gunakan foto dengan 1 wajah");
        return;
      }

      final face = FaceEntry(
        templates: faces[0]['templates'],
        faceJpg: faces[0]['faceJpg'],
      );
      debugPrint('ENROLL ${target.name}: liveness=${faces[0]['liveness']}');

      // Setara API registrasi: simpan ke server, lalu saat itu juga ke lokal
      // dengan created_on yang sama.
      final employee = await MockServer.addFace(
        employeeId: target.id,
        name: target.name,
        face: face,
      );
      await LocalStore.save(employee);
      refreshEmployees();

      showToast(
          "Foto ${employee.faces.length}/$maxFacesPerEmployee tersimpan untuk ${employee.name}");
    } catch (e) {
      debugPrint('enroll error: $e');
      showToast("Enroll gagal: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        toolbarHeight: 70,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync dari Mock Server',
            onPressed: syncEmployees,
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.only(left: 16.0, right: 16.0),
        child: Column(
          children: <Widget>[
            const Card(
                color: Color.fromARGB(255, 0x49, 0x45, 0x4F),
                child: ListTile(
                  leading: Icon(Icons.tips_and_updates),
                  subtitle: Text(
                    'KBY-AI offers SDKs for face recognition, liveness detection, and id document recognition.',
                    style: TextStyle(fontSize: 13),
                  ),
                )),
            const SizedBox(
              height: 6,
            ),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                      label: const Text('Enroll'),
                      icon: const Icon(
                        Icons.person_add,
                        // color: Colors.white70,
                      ),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          // foregroundColor: Colors.white70,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12.0)),
                          )),
                    onPressed: showEnrollTarget,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                      label: const Text('Identify'),
                      icon: const Icon(
                        Icons.person_search,
                      ),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12.0)),
                          )),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => FaceRecognitionView(
                                    personList: LocalStore.toPersonList(),
                                  )),
                        );
                      }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                      label: const Text('Settings'),
                      icon: const Icon(
                        Icons.settings,
                      ),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12.0)),
                          )),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SettingsPage(
                                    homePageState: this,
                                  )),
                        );
                      }),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                      label: const Text('About'),
                      icon: const Icon(
                        Icons.info,
                      ),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12.0)),
                          )),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AboutPage()),
                        );
                      }),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            Expanded(
                child: Stack(
              children: [
                EmployeeView(
                  employees: _employees,
                  serverVersions: _serverVersions,
                  homePageState: this,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Visibility(
                        visible: _visibleWarning,
                        child: Container(
                          width: double.infinity,
                          height: 40,
                          color: Colors.redAccent,
                          child: Center(
                            child: Text(
                              _warningState,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ))
                  ],
                )
              ],
            )),
            const SizedBox(
              height: 4,
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(
                  image: AssetImage('assets/ic_kby.png'),
                  width: 48,
                ),
                SizedBox(width: 4),
                Text('KBY-AI Technology',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color.fromARGB(255, 60, 60, 60),
                    ))
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
