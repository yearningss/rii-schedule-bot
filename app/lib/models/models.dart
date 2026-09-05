// Модели данных для мобильного приложения расписания РИИ

class GroupItem {
  final int id;
  final String name;
  final int course;

  GroupItem({required this.id, required this.name, required this.course});

  factory GroupItem.fromJson(Map<String, dynamic> json) {
    return GroupItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      course: json['course'] is int ? json['course'] : int.parse(json['course'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'course': course};
}

class ParaTime {
  final int startMinutes;
  final int endMinutes;
  final String startStr;
  final String endStr;

  ParaTime({
    required this.startMinutes,
    required this.endMinutes,
    required this.startStr,
    required this.endStr,
  });

  factory ParaTime.parse(String? timeStr, int defaultParaNum) {
    final defaultTimes = {
      1: ParaTime(startMinutes: 8 * 60 + 30, endMinutes: 10 * 60 + 0, startStr: "08:30", endStr: "10:00"),
      2: ParaTime(startMinutes: 10 * 60 + 10, endMinutes: 11 * 60 + 40, startStr: "10:10", endStr: "11:40"),
      3: ParaTime(startMinutes: 12 * 60 + 10, endMinutes: 13 * 60 + 40, startStr: "12:10", endStr: "13:40"),
      4: ParaTime(startMinutes: 13 * 60 + 50, endMinutes: 15 * 60 + 20, startStr: "13:50", endStr: "15:20"),
      5: ParaTime(startMinutes: 15 * 60 + 30, endMinutes: 17 * 60 + 0, startStr: "15:30", endStr: "17:00"),
      6: ParaTime(startMinutes: 17 * 60 + 10, endMinutes: 18 * 60 + 40, startStr: "17:10", endStr: "18:40"),
    };

    if (timeStr == null || timeStr.trim().isEmpty) {
      return defaultTimes[defaultParaNum] ?? ParaTime(startMinutes: 0, endMinutes: 0, startStr: "", endStr: "");
    }

    final cleaned = timeStr.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' - ').replaceAll('.', ':').trim();
    final match = RegExp(r'(\d{1,2})[:.](\d{2})\s*-\s*(\d{1,2})[:.](\d{2})').firstMatch(cleaned);
    if (match != null) {
      final sH = int.parse(match.group(1)!);
      final sM = int.parse(match.group(2)!);
      final eH = int.parse(match.group(3)!);
      final eM = int.parse(match.group(4)!);
      return ParaTime(
        startMinutes: sH * 60 + sM,
        endMinutes: eH * 60 + eM,
        startStr: "${sH.toString().padLeft(2, '0')}:${sM.toString().padLeft(2, '0')}",
        endStr: "${eH.toString().padLeft(2, '0')}:${eM.toString().padLeft(2, '0')}",
      );
    }
    return defaultTimes[defaultParaNum] ?? ParaTime(startMinutes: 0, endMinutes: 0, startStr: "", endStr: "");
  }
}

class ParaItem {
  final int paraNum;
  final bool isDouble;
  final String? subj1;
  final String? type1;
  final String? aud1;
  final String? teacher1;
  final String? teachPost1;
  final String? subj2;
  final String? type2;
  final String? aud2;
  final String? teacher2;
  final String? teachPost2;

  ParaItem({
    required this.paraNum,
    required this.isDouble,
    this.subj1,
    this.type1,
    this.aud1,
    this.teacher1,
    this.teachPost1,
    this.subj2,
    this.type2,
    this.aud2,
    this.teacher2,
    this.teachPost2,
  });

  factory ParaItem.fromJson(int num, Map<String, dynamic> json) {
    return ParaItem(
      paraNum: num,
      isDouble: json['isDouble'] == true,
      subj1: json['subj1'],
      type1: json['type1'],
      aud1: json['aud1'],
      teacher1: json['teacher1'],
      teachPost1: json['teachPost1'],
      subj2: json['subj2'],
      type2: json['type2'],
      aud2: json['aud2'],
      teacher2: json['teacher2'],
      teachPost2: json['teachPost2'],
    );
  }
}

class UserProfile {
  final int? userId;
  final int? groupId;
  final String? groupName;
  final int subgroup;
  final String? authToken;

  UserProfile({
    this.userId,
    this.groupId,
    this.groupName,
    this.subgroup = 0,
    this.authToken,
  });

  UserProfile copyWith({
    int? userId,
    int? groupId,
    String? groupName,
    int? subgroup,
    String? authToken,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      subgroup: subgroup ?? this.subgroup,
      authToken: authToken ?? this.authToken,
    );
  }
}
