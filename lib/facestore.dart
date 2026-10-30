import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'employee.dart';
import 'person.dart';

String _now() => DateTime.now().toIso8601String();

List<Employee> _readEmployees(Box box) {
  return box.values.map((data) => Employee.fromMap(data as Map)).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

class FaceStore {
  static const _keyName = 'hive_key';

  // Kedua box dienkripsi AES-256. Kuncinya disimpan di Keystore (Android) /
  // Keychain (iOS) lewat flutter_secure_storage, bukan di dalam file Hive.
  static Future<void> init() async {
    await Hive.initFlutter();
    final cipher = HiveAesCipher(await _loadKey());
    MockServer._box =
        await Hive.openBox('server_employees', encryptionCipher: cipher);
    LocalStore._box =
        await Hive.openBox('local_employees', encryptionCipher: cipher);
  }

  static Future<List<int>> _loadKey() async {
    const storage = FlutterSecureStorage();
    var encoded = await storage.read(key: _keyName);
    if (encoded == null) {
      encoded = base64UrlEncode(Hive.generateSecureKey());
      await storage.write(key: _keyName, value: encoded);
    }
    return base64Url.decode(encoded);
  }
}

/// Server tiruan, berperan sebagai tabel template di PostgreSQL.
/// Setiap perubahan data employee memperbarui created_on.
class MockServer {
  static late Box _box;

  static List<Employee> getEmployees() => _readEmployees(_box);

  /// Setara API cek versi: hanya employee_id dan created_on, tanpa template.
  static Map<String, String> getVersions() {
    return {
      for (final data in _box.values)
        (data as Map)['employee_id'] as String: data['created_on'] as String,
    };
  }

  /// Setara API ambil template, dipanggil hanya jika created_on berbeda.
  static Employee? getEmployee(String employeeId) {
    final data = _box.get(employeeId);
    return data == null ? null : Employee.fromMap(data as Map);
  }

  /// Setara API registrasi: menambah satu foto dan memperbarui created_on.
  static Future<Employee> addFace({
    required String employeeId,
    required String name,
    required FaceEntry face,
  }) async {
    final current = getEmployee(employeeId);
    final faces = [...?current?.faces];
    if (faces.length >= maxFacesPerEmployee) {
      throw StateError('Maksimal $maxFacesPerEmployee foto per employee');
    }
    final employee = Employee(
      employeeId: employeeId,
      name: current?.name ?? name,
      createdOn: _now(),
      faces: [...faces, face],
    );
    await _box.put(employeeId, employee.toMap());
    return employee;
  }

  /// Menghapus satu foto. Mengembalikan null jika employee sudah tidak punya foto.
  static Future<Employee?> removeFace(String employeeId, int index) async {
    final current = getEmployee(employeeId);
    if (current == null || index >= current.faces.length) return current;

    final faces = [...current.faces]..removeAt(index);
    if (faces.isEmpty) {
      await _box.delete(employeeId);
      return null;
    }
    final employee = current.copyWith(createdOn: _now(), faces: faces);
    await _box.put(employeeId, employee.toMap());
    return employee;
  }

  /// Simulasi perubahan dari luar device ini (mis. registrasi ulang yang
  /// disetujui HRD): created_on di server berubah, data lokal belum.
  static Future<void> touch(String employeeId) async {
    final current = getEmployee(employeeId);
    if (current == null) return;
    await _box.put(employeeId, current.copyWith(createdOn: _now()).toMap());
  }

  static Future<void> deleteEmployee(String employeeId) =>
      _box.delete(employeeId);

  static Future<void> clear() => _box.clear();
}

/// Penyimpanan lokal di device, satu-satunya sumber data saat identify.
class LocalStore {
  static late Box _box;

  static List<Employee> getEmployees() => _readEmployees(_box);

  static Future<void> save(Employee employee) =>
      _box.put(employee.employeeId, employee.toMap());

  static Future<void> delete(String employeeId) => _box.delete(employeeId);

  static Future<void> clear() => _box.clear();

  /// Setiap foto menjadi satu entri, sehingga identify membandingkan wajah
  /// dengan semua template milik semua employee.
  static List<Person> toPersonList() {
    return [
      for (final employee in getEmployees())
        for (final face in employee.faces)
          Person(
            name: employee.name,
            faceJpg: face.faceJpg,
            templates: face.templates,
          ),
    ];
  }
}

class SyncResult {
  int added = 0;
  int updated = 0;
  int unchanged = 0;
  int removed = 0;

  @override
  String toString() =>
      'Sync: $added baru, $updated diperbarui, $unchanged tetap, $removed dihapus';
}

/// Bandingkan created_on lokal dengan server. Template hanya ditarik untuk
/// employee yang created_on-nya berbeda atau belum ada di lokal.
Future<SyncResult> syncFromServer() async {
  final result = SyncResult();
  final serverVersions = MockServer.getVersions();
  final localEmployees = {
    for (final employee in LocalStore.getEmployees())
      employee.employeeId: employee,
  };

  for (final entry in serverVersions.entries) {
    final local = localEmployees[entry.key];
    if (local != null && local.createdOn == entry.value) {
      result.unchanged++;
      debugPrint('SYNC ${local.name}: tetap (${local.createdOn})');
      continue;
    }

    final employee = MockServer.getEmployee(entry.key);
    if (employee == null) continue;
    await LocalStore.save(employee);
    if (local == null) {
      result.added++;
      debugPrint('SYNC ${employee.name}: baru (${employee.createdOn})');
    } else {
      result.updated++;
      debugPrint(
          'SYNC ${employee.name}: diperbarui (${local.createdOn} -> ${employee.createdOn})');
    }
  }

  for (final local in localEmployees.values) {
    if (!serverVersions.containsKey(local.employeeId)) {
      await LocalStore.delete(local.employeeId);
      result.removed++;
      debugPrint('SYNC ${local.name}: dihapus (tidak ada di Mock Server)');
    }
  }

  return result;
}
