import 'dart:io';
import 'package:yaml/yaml.dart';

// Konfigurasi
const String outputFile = 'gemini.md';
const List<String> includedExtensions = ['.dart', '.yaml', '.json'];
const List<String> excludedDirs = [
  '.dart_tool',
  'build',
  'android',
  'ios',
  'web',
  'linux',
  'macos',
  'windows',
  'test',
];

// Struktur untuk menyimpan statistik
class ProjectStats {
  int totalDartFiles = 0;
  int totalLines = 0;
  Map<String, int> categoryCount = {
    'models': 0,
    'screens': 0,
    'pages': 0,
    'services': 0,
    'widgets': 0,
    'controllers': 0,
    'utils': 0,
    'providers': 0,
  };
  List<String> allDartFiles = [];
}

void main() async {
  final rootDir = Directory.current;
  final buffer = StringBuffer();
  final stats = ProjectStats();

  print('🔍 Scanning project...');

  // Header
  buffer.writeln('# 📱 PROJECT CONTEXT REPORT\n');
  buffer.writeln('**Generated on:** ${DateTime.now()}\n');
  buffer.writeln('---\n');

  // 1. Project Overview
  await _writeProjectOverview(buffer);

  // 2. Dependencies Analysis
  await _writeDependenciesAnalysis(buffer);

  // 3. Scan dan hitung statistik
  await _collectProjectStats(rootDir, stats);

  // 4. Code Statistics
  _writeCodeStatistics(buffer, stats);

  // 5. Project Structure
  buffer.writeln('## 📂 Project Structure\n');
  buffer.writeln('```');
  await _listDirectory(rootDir, buffer);
  buffer.writeln('```\n');

  // 6. Key Components
  _writeKeyComponents(buffer, stats);

  // 7. App Routes (jika ada)
  await _writeAppRoutes(buffer);

  // 8. State Management Detection
  await _detectStateManagement(buffer);

  // 9. Configuration Files
  buffer.writeln('## 🔧 Configuration Files\n');
  await _appendFileContent('pubspec.yaml', buffer);
  await _appendFileContent('analysis_options.yaml', buffer);

  // 10. Critical Files Content
  buffer.writeln('## 🔑 Critical Files Content\n');
  await _appendFileContent('lib/main.dart', buffer);
  
  // Tambah file-file penting lainnya jika ada
  final importantFiles = [
    'lib/app.dart',
    'lib/routes.dart',
    'lib/constants/app_constants.dart',
    'lib/config/app_config.dart',
  ];
  
  for (var file in importantFiles) {
    await _appendFileContent(file, buffer);
  }

  // 11. Models Content (max 5 files)
  await _appendCategoryFiles(buffer, 'Models', stats.allDartFiles, ['model'], 5);

  // 12. Screens/Pages Content (max 5 files)
  await _appendCategoryFiles(buffer, 'Screens/Pages', stats.allDartFiles, ['screen', 'page'], 5);

  // 13. Services Content (max 3 files)
  await _appendCategoryFiles(buffer, 'Services', stats.allDartFiles, ['service'], 3);

  // Simpan ke file
  final file = File(outputFile);
  await file.writeAsString(buffer.toString());
  
  print('✅ Berhasil membuat $outputFile!');
  print('📊 Total: ${stats.totalDartFiles} files, ${stats.totalLines} lines');
  print('📄 File size: ${(await file.length() / 1024).toStringAsFixed(2)} KB');
  print('\n🚀 Sekarang feed file ini ke Gemini CLI!');
}

Future<void> _writeProjectOverview(StringBuffer buffer) async {
  buffer.writeln('## 📋 Project Overview\n');
  
  final pubspecFile = File('pubspec.yaml');
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();
    final yaml = loadYaml(content);
    
    buffer.writeln('- **Project Name:** ${yaml['name'] ?? 'N/A'}');
    buffer.writeln('- **Description:** ${yaml['description'] ?? 'N/A'}');
    buffer.writeln('- **Version:** ${yaml['version'] ?? 'N/A'}');
    
    if (yaml['environment'] != null) {
      final env = yaml['environment'];
      buffer.writeln('- **Flutter SDK:** ${env['sdk'] ?? 'N/A'}');
    }
  }
  
  buffer.writeln('- **Working Directory:** ${Directory.current.path}');
  buffer.writeln('\n---\n');
}

Future<void> _writeDependenciesAnalysis(StringBuffer buffer) async {
  buffer.writeln('## 📦 Dependencies Analysis\n');
  
  final pubspecFile = File('pubspec.yaml');
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();
    final yaml = loadYaml(content);
    
    // Core Dependencies
    if (yaml['dependencies'] != null) {
      buffer.writeln('### Core Dependencies:\n');
      final deps = yaml['dependencies'] as YamlMap;
      deps.forEach((key, value) {
        if (key != 'flutter') {
          final version = value is YamlMap ? value['version'] ?? value : value;
          buffer.writeln('- `$key`: $version');
        }
      });
      buffer.writeln();
    }
    
    // Dev Dependencies
    if (yaml['dev_dependencies'] != null) {
      buffer.writeln('### Dev Dependencies:\n');
      final devDeps = yaml['dev_dependencies'] as YamlMap;
      devDeps.forEach((key, value) {
        if (key != 'flutter_test') {
          final version = value is YamlMap ? value['version'] ?? value : value;
          buffer.writeln('- `$key`: $version');
        }
      });
      buffer.writeln();
    }
  }
  
  buffer.writeln('---\n');
}

Future<void> _collectProjectStats(Directory dir, ProjectStats stats) async {
  await for (var entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final relativePath = entity.path.replaceFirst(dir.path + Platform.pathSeparator, '');
      
      // Skip excluded directories
      if (excludedDirs.any((excluded) => relativePath.contains(excluded))) {
        continue;
      }
      
      stats.totalDartFiles++;
      stats.allDartFiles.add(relativePath);
      
      // Count lines
      final lines = await entity.readAsLines();
      stats.totalLines += lines.where((line) => line.trim().isNotEmpty).length;
      
      // Categorize files
      final lowerPath = relativePath.toLowerCase();
      if (lowerPath.contains('/models/') || lowerPath.endsWith('_model.dart')) {
        stats.categoryCount['models'] = (stats.categoryCount['models'] ?? 0) + 1;
      }
      if (lowerPath.contains('/screens/') || lowerPath.endsWith('_screen.dart')) {
        stats.categoryCount['screens'] = (stats.categoryCount['screens'] ?? 0) + 1;
      }
      if (lowerPath.contains('/pages/') || lowerPath.endsWith('_page.dart')) {
        stats.categoryCount['pages'] = (stats.categoryCount['pages'] ?? 0) + 1;
      }
      if (lowerPath.contains('/services/') || lowerPath.endsWith('_service.dart')) {
        stats.categoryCount['services'] = (stats.categoryCount['services'] ?? 0) + 1;
      }
      if (lowerPath.contains('/widgets/') || lowerPath.endsWith('_widget.dart')) {
        stats.categoryCount['widgets'] = (stats.categoryCount['widgets'] ?? 0) + 1;
      }
      if (lowerPath.contains('/controllers/') || lowerPath.endsWith('_controller.dart')) {
        stats.categoryCount['controllers'] = (stats.categoryCount['controllers'] ?? 0) + 1;
      }
      if (lowerPath.contains('/utils/') || lowerPath.endsWith('_util.dart')) {
        stats.categoryCount['utils'] = (stats.categoryCount['utils'] ?? 0) + 1;
      }
      if (lowerPath.contains('/providers/') || lowerPath.endsWith('_provider.dart')) {
        stats.categoryCount['providers'] = (stats.categoryCount['providers'] ?? 0) + 1;
      }
    }
  }
}

void _writeCodeStatistics(StringBuffer buffer, ProjectStats stats) {
  buffer.writeln('## 📊 Code Statistics\n');
  buffer.writeln('- **Total Dart files:** ${stats.totalDartFiles}');
  buffer.writeln('- **Total lines of code:** ${stats.totalLines}');
  buffer.writeln();
  
  final hasContent = stats.categoryCount.values.any((count) => count > 0);
  if (hasContent) {
    buffer.writeln('### Components Breakdown:\n');
    stats.categoryCount.forEach((category, count) {
      if (count > 0) {
        buffer.writeln('- **${_capitalize(category)}:** $count files');
      }
    });
  }
  
  buffer.writeln('\n---\n');
}

void _writeKeyComponents(StringBuffer buffer, ProjectStats stats) {
  buffer.writeln('## 🎯 Key Components\n');
  
  stats.categoryCount.forEach((category, count) {
    if (count > 0) {
      buffer.writeln('### ${_capitalize(category)} ($count files)\n');
      
      final categoryFiles = stats.allDartFiles.where((path) {
        final lowerPath = path.toLowerCase();
        return lowerPath.contains('/$category/') || 
               lowerPath.endsWith('_$category.dart') ||
               lowerPath.endsWith('_${category.substring(0, category.length - 1)}.dart');
      }).take(10);
      
      for (var file in categoryFiles) {
        buffer.writeln('- `$file`');
      }
      buffer.writeln();
    }
  });
  
  buffer.writeln('---\n');
}

Future<void> _writeAppRoutes(StringBuffer buffer) async {
  buffer.writeln('## 🛣️ App Navigation\n');
  
  // Coba cari file routing
  final routeFiles = ['lib/routes.dart', 'lib/app_routes.dart', 'lib/router.dart', 'lib/config/routes.dart'];
  
  bool foundRoutes = false;
  for (var routeFile in routeFiles) {
    final file = File(routeFile);
    if (await file.exists()) {
      buffer.writeln('*Routes defined in: `$routeFile`*\n');
      foundRoutes = true;
      
      // Coba extract route names
      final content = await file.readAsString();
      final routePattern = RegExp(r"""(['"])/([\w/:-]*)\1""");
      final matches = routePattern.allMatches(content);
      
      if (matches.isNotEmpty) {
        buffer.writeln('### Detected Routes:\n');
        final routes = matches.map((m) => m.group(0)).toSet();
        for (var route in routes.take(20)) {
          buffer.writeln('- $route');
        }
        buffer.writeln();
      }
      break;
    }
  }
  
  if (!foundRoutes) {
    buffer.writeln('*No dedicated routes file found. Routes may be defined in main.dart*\n');
  }
  
  buffer.writeln('---\n');
}

Future<void> _detectStateManagement(StringBuffer buffer) async {
  buffer.writeln('## 🔧 State Management\n');
  
  final pubspecFile = File('pubspec.yaml');
  if (await pubspecFile.exists()) {
    final content = await pubspecFile.readAsString();
    
    final stateManagers = {
      'provider': 'Provider',
      'riverpod': 'Riverpod',
      'flutter_riverpod': 'Riverpod',
      'bloc': 'BLoC',
      'flutter_bloc': 'BLoC',
      'get': 'GetX',
      'mobx': 'MobX',
      'redux': 'Redux',
    };
    
    final detected = <String>[];
    stateManagers.forEach((package, name) {
      if (content.contains('$package:')) {
        detected.add(name);
      }
    });
    
    if (detected.isNotEmpty) {
      buffer.writeln('**Detected:** ${detected.join(', ')}\n');
    } else {
      buffer.writeln('**Detected:** StatefulWidget / setState (default)\n');
    }
  }
  
  buffer.writeln('---\n');
}

Future<void> _appendCategoryFiles(
  StringBuffer buffer,
  String categoryName,
  List<String> allFiles,
  List<String> patterns,
  int maxFiles,
) async {
  final matchedFiles = allFiles.where((path) {
    final lowerPath = path.toLowerCase();
    return patterns.any((pattern) => 
      lowerPath.contains('/$pattern') || 
      lowerPath.endsWith('_$pattern.dart')
    );
  }).take(maxFiles);
  
  if (matchedFiles.isNotEmpty) {
    buffer.writeln('## 📄 $categoryName Files\n');
    for (var filePath in matchedFiles) {
      await _appendFileContent(filePath, buffer);
    }
  }
}

Future<void> _listDirectory(
  Directory dir,
  StringBuffer buffer, {
  String prefix = '',
}) async {
  final List<FileSystemEntity> entities =
      dir.listSync()..sort((a, b) => a.path.compareTo(b.path));
  
  for (var i = 0; i < entities.length; i++) {
    final entity = entities[i];
    final isLast = i == entities.length - 1;
    final name = entity.uri.pathSegments.where((e) => e.isNotEmpty).last;
    
    if (name.startsWith('.') || excludedDirs.contains(name)) continue;
    
    buffer.writeln('$prefix${isLast ? '└── ' : '├── '}$name');
    
    if (entity is Directory) {
      await _listDirectory(
        entity,
        buffer,
        prefix: prefix + (isLast ? '    ' : '│   '),
      );
    }
  }
}

Future<void> _appendFileContent(String path, StringBuffer buffer) async {
  final file = File(path);
  if (await file.exists()) {
    final extension = path.split('.').last;
    final lines = await file.readAsLines();
    final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).length;
    
    buffer.writeln('### 📄 File: `$path` ($nonEmptyLines lines)\n');
    buffer.writeln('```$extension');
    buffer.writeln(await file.readAsString());
    buffer.writeln('```\n');
  }
}

String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}