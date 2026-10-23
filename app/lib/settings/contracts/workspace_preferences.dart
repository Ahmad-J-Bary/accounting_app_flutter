import 'package:flutter/foundation.dart';

@immutable
class WorkspacePreferences {
  final List<String> defaultWorkspaceItemIds;
  final bool rememberLastSection;

  const WorkspacePreferences({
    this.defaultWorkspaceItemIds = const [],
    this.rememberLastSection = true,
  });

  WorkspacePreferences copyWith({
    List<String>? defaultWorkspaceItemIds,
    bool? rememberLastSection,
  }) {
    return WorkspacePreferences(
      defaultWorkspaceItemIds: defaultWorkspaceItemIds ?? this.defaultWorkspaceItemIds,
      rememberLastSection: rememberLastSection ?? this.rememberLastSection,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultWorkspaceItemIds': defaultWorkspaceItemIds,
        'rememberLastSection': rememberLastSection,
      };

  static WorkspacePreferences fromJson(Map<String, dynamic> json) {
    final ids = json['defaultWorkspaceItemIds'];
    return WorkspacePreferences(
      defaultWorkspaceItemIds: ids is List
          ? ids.whereType<String>().toList(growable: false)
          : const [],
      rememberLastSection: json['rememberLastSection'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkspacePreferences &&
      listEquals(other.defaultWorkspaceItemIds, defaultWorkspaceItemIds) &&
      other.rememberLastSection == rememberLastSection;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(defaultWorkspaceItemIds), rememberLastSection);
}