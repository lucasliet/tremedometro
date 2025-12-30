class File {
  File(String path);
  Future<bool> exists() async => false;
  Future<void> delete() async {}
}

class Directory {
  Directory(String path);
  String get path => '';
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}
