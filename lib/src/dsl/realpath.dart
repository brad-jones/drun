import 'dart:io';
import 'package:path/path.dart' as p;

mixin Realpath {
  /// Canonicalizes [path].
  ///
  /// This is guaranteed to return the same path for two different input paths
  /// if and only if both input paths point to the same location.
  ///
  /// Additionally some convenience replacements are performed:
  /// - When [path] starts with `~` it will be replaced with users home dir
  /// - When [path] starts with `!` it will be replaced by the projects root dir
  ///
  /// The projects root dir is assumed to be where a `.git` folder is found.
  /// Consider this example:
  ///
  /// - `/home/user/acme-project`
  ///   - .git
  ///   - assets
  ///     - image.jpg
  ///   - Makefile.dart: `realpath('!/assets/image.jpg')` = `/home/user/acme-project/assets/image.jpg`
  ///     - projects
  ///       - foo
  ///         - Makefile.dart `realpath('!/assets/image.jpg')` = `/home/user/acme-project/assets/image.jpg`
  ///       - bar
  ///         - Makefile.dart `realpath('!/assets/image.jpg')` = `/home/user/acme-project/assets/image.jpg`
  ///
  /// So regardless of if the working directory is `/home/user/acme-project` and
  /// child Makefiles have been included or the current working directory is
  /// `/home/user/acme-project/projects/foo` and the user is operating `drun`
  /// against a standalone Makefile, paths can always be resolved correctly.
  ///
  /// If this logic is not suitable (eg: git is not being used) then you may
  /// provide your very own [rootFinder] function.
  String realpath(String path, {String Function() rootFinder}) {
    if (!p.isAbsolute(path)) {
      if (path.startsWith('~/')) {
        path = p.join(
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'],
          path.substring(2),
        );
      } else if (path.startsWith('!/')) {
        path = p.join(_repoRoot(rootFinder), path.substring(2));
      }
    }
    return p.canonicalize(path);
  }

  static String _repoRootCache;
  static String _repoRoot([String Function() rootFinder]) {
    if (_repoRootCache == null) {
      if (rootFinder != null) {
        _repoRootCache = rootFinder();
      } else {
        var dir = Directory.current;
        while (!Directory(p.join(dir.path, '.git')).existsSync()) {
          dir = dir.parent;
        }
        _repoRootCache = p.canonicalize(dir.path);
      }
    }
    return _repoRootCache;
  }
}
