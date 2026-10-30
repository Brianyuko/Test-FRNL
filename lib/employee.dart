import 'dart:typed_data';

const int maxFacesPerEmployee = 5;

class FaceEntry {
  final Uint8List templates;
  final Uint8List faceJpg;

  const FaceEntry({
    required this.templates,
    required this.faceJpg,
  });

  factory FaceEntry.fromMap(Map data) {
    return FaceEntry(
      templates: data['templates'] as Uint8List,
      faceJpg: data['face_jpg'] as Uint8List,
    );
  }

  Map<String, Object> toMap() {
    return {
      'templates': templates,
      'face_jpg': faceJpg,
    };
  }
}

class Employee {
  final String employeeId;
  final String name;
  final String createdOn;
  final List<FaceEntry> faces;

  const Employee({
    required this.employeeId,
    required this.name,
    required this.createdOn,
    required this.faces,
  });

  factory Employee.fromMap(Map data) {
    return Employee(
      employeeId: data['employee_id'] as String,
      name: data['name'] as String,
      createdOn: data['created_on'] as String,
      faces: (data['faces'] as List)
          .map((face) => FaceEntry.fromMap(face as Map))
          .toList(),
    );
  }

  Map<String, Object> toMap() {
    return {
      'employee_id': employeeId,
      'name': name,
      'created_on': createdOn,
      'faces': faces.map((face) => face.toMap()).toList(),
    };
  }

  Employee copyWith({String? createdOn, List<FaceEntry>? faces}) {
    return Employee(
      employeeId: employeeId,
      name: name,
      createdOn: createdOn ?? this.createdOn,
      faces: faces ?? this.faces,
    );
  }
}
