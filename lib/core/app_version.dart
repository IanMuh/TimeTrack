class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.prerelease,
    this.buildMetadata,
  });

  final int major;
  final int minor;
  final int patch;
  final String? prerelease;
  final String? buildMetadata;

  bool get isPrerelease => prerelease != null && prerelease!.isNotEmpty;

  static AppVersion parse(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$',
    ).firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Invalid semantic version', value);
    }
    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      prerelease: match.group(4),
      buildMetadata: match.group(5),
    );
  }

  @override
  int compareTo(AppVersion other) {
    final majorCompare = major.compareTo(other.major);
    if (majorCompare != 0) {
      return majorCompare;
    }
    final minorCompare = minor.compareTo(other.minor);
    if (minorCompare != 0) {
      return minorCompare;
    }
    final patchCompare = patch.compareTo(other.patch);
    if (patchCompare != 0) {
      return patchCompare;
    }
    return _comparePrerelease(prerelease, other.prerelease);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  bool operator >(AppVersion other) => compareTo(other) > 0;

  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  String toString() {
    final buffer = StringBuffer('$major.$minor.$patch');
    if (isPrerelease) {
      buffer.write('-$prerelease');
    }
    if (buildMetadata != null && buildMetadata!.isNotEmpty) {
      buffer.write('+$buildMetadata');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    return other is AppVersion &&
        major == other.major &&
        minor == other.minor &&
        patch == other.patch &&
        prerelease == other.prerelease;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease);
}

int _comparePrerelease(String? left, String? right) {
  if (left == null || left.isEmpty) {
    return right == null || right.isEmpty ? 0 : 1;
  }
  if (right == null || right.isEmpty) {
    return -1;
  }

  final leftParts = left.split('.');
  final rightParts = right.split('.');
  final length = leftParts.length < rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < length; index += 1) {
    final result = _comparePrereleasePart(leftParts[index], rightParts[index]);
    if (result != 0) {
      return result;
    }
  }
  return leftParts.length.compareTo(rightParts.length);
}

int _comparePrereleasePart(String left, String right) {
  final leftNumber = int.tryParse(left);
  final rightNumber = int.tryParse(right);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  if (leftNumber != null) {
    return -1;
  }
  if (rightNumber != null) {
    return 1;
  }
  return left.compareTo(right);
}
