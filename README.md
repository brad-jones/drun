# drun

![Pub Version](https://img.shields.io/pub/v/drun)
![.github/workflows/main.yml](https://github.com/brad-jones/drun/workflows/.github/workflows/main.yml/badge.svg?branch=master)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)
[![KeepAChangelog](https://img.shields.io/badge/Keep%20A%20Changelog-1.0.0-%23E05735)](https://keepachangelog.com/)
[![License](https://img.shields.io/github/license/brad-jones/drun.svg)](https://github.com/brad-jones/drun/blob/master/LICENSE)

A dartlang task runner, write functions and call them in your terminal.

## Installation

- Install dartlang <https://dart.dev/get-dart>
- Then install drun globally: `pub global activate drun`
- Then install drun into your local project where your `Makefile.dart` resides.

### Experimental dart2native binaries

You may prefer to install the global `drun` command as single statically compiled binary.

> _NOTE: You still need the dart SDK installed!_

#### Direct download

Go to https://github.com/brad-jones/drun/releases and download the archive for
your Operating System, extract the `drun` binary and and add it to your `$PATH`.

#### Curl Bash

```
curl -L https://github.com/brad-jones/drun/releases/latest/download/drun-linux-x64.tar.gz -o- | sudo tar -xz -C /usr/bin drun
```

#### RPM package

```
sudo rpm -i https://github.com/brad-jones/drun/releases/latest/download/drun-linux-x64.rpm
```

#### DEB package

```
curl -sLO https://github.com/brad-jones/drun/releases/latest/download/drun-linux-x64.deb && sudo dpkg -i drun-linux-x64.deb && rm drun-linux-x64.deb
```

#### Homebrew

<https://brew.sh>

```
brew install brad-jones/tap/drun
```

#### Scoop

<https://scoop.sh>

```
scoop bucket add brad-jones https://github.com/brad-jones/scoop-bucket.git;
scoop install drun;
```

## Usage

_pubspec.yaml_

```yaml
name: my_project

dependencies:
  # You should probably fix the version of drun but leaving it blank will
  # download the latest version and get you started.
  drun:
```

_Makefile.dart_

```dart
import 'package:drun/drun.dart';
Future main(argv) => drun(argv);
Future myTask() => task((drun) => drun.log('Hello World'));
```

Execute with `drun my-task`

> see [./example/README.md](./example/README.md) for more details
