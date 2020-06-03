mixin Depends {
  /// Use this to execute dependent tasks.
  ///
  /// ```dart
  /// Future foobar() => task((drun) => drun.deps([foo('123'), bar('xyz')]).then((_) {
  ///   drun.log('doing foobar`s work, after having run foo & bar concurrently');
  /// }));
  /// ```
  ///
  /// Alternativly this could easily be re-written as:
  ///
  /// ```dart
  /// Future foobar() => task((drun) async {
  ///   await drun.deps([foo('123'), bar('xyz')]);
  ///   drun.log('doing foobar`s work, after having run foo & bar concurrently');
  /// });
  /// ```
  ///
  /// _NOTE: This is simply an alias for [Future.wait]_
  Future<List<T>> deps<T>(Iterable<Future<T>> tasks) =>
      Future.wait(tasks, eagerError: true);
}
