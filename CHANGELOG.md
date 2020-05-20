## [2.6.1](https://github.com/brad-jones/drun/compare/v2.6.0...v2.6.1) (2020-05-20)


### Bug Fixes

* **reflect:** it is possible to have multiple prefixes of the same name ([2a28ac5](https://github.com/brad-jones/drun/commit/2a28ac5aa90ef868063f1db611320d43e20dbd1f))

# [2.6.0](https://github.com/brad-jones/drun/compare/v2.5.0...v2.6.0) (2020-05-19)


### Features

* **run:** functin that combines the other runX functions ([8dce0f1](https://github.com/brad-jones/drun/commit/8dce0f1ad9c6554eef95f8a58f25a43997924dcf))

# [2.5.0](https://github.com/brad-jones/drun/compare/v2.4.1...v2.5.0) (2020-05-19)


### Features

* **runifchanged:** function that executes only if files have changed ([d1bd522](https://github.com/brad-jones/drun/commit/d1bd522050a6350af3245afddecdf0b984e73c81))

## [2.4.1](https://github.com/brad-jones/drun/compare/v2.4.0...v2.4.1) (2020-05-19)


### Bug Fixes

* **pubspec:** crypto is now a lib dependency ([2bed7ec](https://github.com/brad-jones/drun/commit/2bed7ecc5065db4feb033bd81da4c1250bddf6a1))

# [2.4.0](https://github.com/brad-jones/drun/compare/v2.3.0...v2.4.0) (2020-05-19)


### Features

* **runifnotfound:** new function that only runs if files are not found ([486c245](https://github.com/brad-jones/drun/commit/486c2455ff05ac231cff15eb4de58ff1185639ad))

# [2.3.0](https://github.com/brad-jones/drun/compare/v2.2.0...v2.3.0) (2020-05-19)


### Features

* **runonce:** will run a task only once for a single drun execution ([deae68f](https://github.com/brad-jones/drun/commit/deae68fb95f8a307139624df9cb13c89a09ba687))

# [2.2.0](https://github.com/brad-jones/drun/compare/v2.1.1...v2.2.0) (2020-05-19)


### Features

* **log:** add some simple logging functionality ([1348950](https://github.com/brad-jones/drun/commit/1348950beec0f69f3a4e4bd4af80132bf6474167))

## [2.1.1](https://github.com/brad-jones/drun/compare/v2.1.0...v2.1.1) (2020-05-14)


### Bug Fixes

* **reflect:** allow other types of members inside options class ([a4ff2df](https://github.com/brad-jones/drun/commit/a4ff2df5d82a6210cf3615aa0b9b80cd77c905f8))

# [2.1.0](https://github.com/brad-jones/drun/compare/v2.0.3...v2.1.0) (2020-05-08)


### Features

* drun the binary now installs dart and run pub get if needed ([5b18bdf](https://github.com/brad-jones/drun/commit/5b18bdfda33995a4f4c898d028ff4279d5e671d7))

## [2.0.3](https://github.com/brad-jones/drun/compare/v2.0.2...v2.0.3) (2020-05-07)


### Bug Fixes

* **archives:** make sure the execute bit is set ([2bc9912](https://github.com/brad-jones/drun/commit/2bc99129c8dca105cae53143002c3802e9ddda07))

## [2.0.2](https://github.com/brad-jones/drun/compare/v2.0.1...v2.0.2) (2020-04-22)


### Bug Fixes

* **windows:** strip leaing slash from root makefile path ([dba938b](https://github.com/brad-jones/drun/commit/dba938be9adcee37544a2423cae19ed207083d68))

## [2.0.1](https://github.com/brad-jones/drun/compare/v2.0.0...v2.0.1) (2020-04-22)


### Bug Fixes

* **windows:** normalize paths when looking for root makefile ([5271990](https://github.com/brad-jones/drun/commit/5271990ba5457e037d32c94c7b8c97cb9c3e89ea))

# [2.0.0](https://github.com/brad-jones/drun/compare/v1.1.5...v2.0.0) (2020-04-22)


### Features

* **global-options:** allow options to be shared between tasks ([3037980](https://github.com/brad-jones/drun/commit/303798012fb15df53cf151110cc17b4398e6a63d))


### BREAKING CHANGES

* **global-options:** fairly significant changes although none are
breaking I believe, but without a test suite it's hard to say. If this is v2,
then v3 will include a full test suite, I promise :)

## [1.1.5](https://github.com/brad-jones/drun/compare/v1.1.4...v1.1.5) (2020-04-15)


### Bug Fixes

* **windows:** updated dexecve which uses ProcessStartMode.inheritStdio ([4a33877](https://github.com/brad-jones/drun/commit/4a3387735be0a77e472fd439888fbc3289df1899))

## [1.1.4](https://github.com/brad-jones/drun/compare/v1.1.3...v1.1.4) (2020-04-15)


### Bug Fixes

* **stdin:** another fix for dexecve ([642a510](https://github.com/brad-jones/drun/commit/642a5103e4d2bbab5f019055d05de1816bdda94c))

## [1.1.3](https://github.com/brad-jones/drun/compare/v1.1.2...v1.1.3) (2020-04-15)


### Bug Fixes

* **help:** format option names with param-case ([0cbcfbf](https://github.com/brad-jones/drun/commit/0cbcfbf87ef03af8b06c2271138dc8cab8bbd48c))
* **stdin:** the new version of dexecve should handle stdin ([2b8e084](https://github.com/brad-jones/drun/commit/2b8e084b1ec938e7bdb8a08f6fe7ce4bb6e45051))

## [1.1.2](https://github.com/brad-jones/drun/compare/v1.1.1...v1.1.2) (2020-03-18)


### Bug Fixes

* **binary:** make use of our new packages dexeca and dexecve ([efea46d](https://github.com/brad-jones/drun/commit/efea46d99d3acfeec65ed5145f059e1e3f4b98f8))

## [1.1.1](https://github.com/brad-jones/drun/compare/v1.1.0...v1.1.1) (2020-03-18)


### Bug Fixes

* **example:** renamed the file to main.dart ([7b6ddda](https://github.com/brad-jones/drun/commit/7b6ddda373a75e61a811dc5bede6dba11a195295))

# [1.1.0](https://github.com/brad-jones/drun/compare/v1.0.11...v1.1.0) (2020-03-18)


### Features

* **example:** added one ([c5d8514](https://github.com/brad-jones/drun/commit/c5d851447fe2618045a981b757f78519a0c29267))

## [1.0.11](https://github.com/brad-jones/drun/compare/v1.0.10...v1.0.11) (2020-03-10)


### Bug Fixes

* **release:** search and replace logic incorrect ([54c0e25](https://github.com/brad-jones/drun/commit/54c0e254f8075c72b4050ad8df4a4b5a235f7e9f))

## [1.0.10](https://github.com/brad-jones/drun/compare/v1.0.9...v1.0.10) (2020-03-10)


### Bug Fixes

* **release:** github actions is kind of a pain ([284eb1e](https://github.com/brad-jones/drun/commit/284eb1e6dfb4cd27dd79e7eafe9bf9d435e35e14))

## [1.0.9](https://github.com/brad-jones/drun/compare/v1.0.8...v1.0.9) (2020-03-10)


### Bug Fixes

* **release:** actually I don't think we need this at all ([bed5970](https://github.com/brad-jones/drun/commit/bed5970109667813c1b3797ae3ebd46a24641ae7))
* **release:** make commits uses semantic-release-bot ([31c04ff](https://github.com/brad-jones/drun/commit/31c04ff8b1a7c398774dd767cd304eb0acb10c29))

## [1.0.8](https://github.com/brad-jones/drun/compare/v1.0.7...v1.0.8) (2020-03-10)


### Bug Fixes

* **release:** well I believe this is sorted now ([e9621f5](https://github.com/brad-jones/drun/commit/e9621f531bf4e8d4307a6c402a4dc13c0a9b4bf3))

## [1.0.7](https://github.com/brad-jones/drun/compare/v1.0.6...v1.0.7) (2020-03-10)


### Bug Fixes

* **release:** ok try again ([62ae53f](https://github.com/brad-jones/drun/commit/62ae53f5c8e6cfa188e15f9a885ed000263a711a))

## [1.0.6](https://github.com/brad-jones/drun/compare/v1.0.5...v1.0.6) (2020-03-10)


### Bug Fixes

* **release:** perhaps our expiration logic is not correct ([c9fecc8](https://github.com/brad-jones/drun/commit/c9fecc826cdf4617987824f10a6703655b50a6a9))

## [1.0.5](https://github.com/brad-jones/drun/compare/v1.0.4...v1.0.5) (2020-03-10)


### Bug Fixes

* **release:** added git email and name to allow git changes to be pushed ([b4a8d3c](https://github.com/brad-jones/drun/commit/b4a8d3c22617cd412a7220d3ae5613c5928a6534))

## [1.0.4](https://github.com/brad-jones/drun/compare/v1.0.3...v1.0.4) (2020-03-10)


### Bug Fixes

* **release:** more debugging ([9bec3d9](https://github.com/brad-jones/drun/commit/9bec3d9d3779763af0704bb8eac1aeb6049b53e3))

## [1.0.3](https://github.com/brad-jones/drun/compare/v1.0.2...v1.0.3) (2020-03-10)


### Bug Fixes

* **release:** this is not making any sense, sorry for the dud releases ([02fa62d](https://github.com/brad-jones/drun/commit/02fa62db974fa5dbd7dd9c94ec4f6f387d000287))

## [1.0.2](https://github.com/brad-jones/drun/compare/v1.0.1...v1.0.2) (2020-03-10)


### Bug Fixes

* **release:** homebrew and scoop failed to release due to git auth issue ([568d3b1](https://github.com/brad-jones/drun/commit/568d3b136060a59128669417922efaa82ee84639))

## [1.0.1](https://github.com/brad-jones/drun/compare/v1.0.0...v1.0.1) (2020-03-10)


### Bug Fixes

* **description:** pub.dev told us our description is too short ([418dc03](https://github.com/brad-jones/drun/commit/418dc03a58b2f7a117953e3d5bbf8b6669eca4f8))

# 1.0.0 (2020-03-10)


### Features

* initial release ([762618c](https://github.com/brad-jones/drun/commit/762618c0832504f740023d955c6fdb223e385b91))
