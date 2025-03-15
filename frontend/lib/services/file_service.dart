import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class FileService {
  // 支持的音频格式
  static const List<String> supportedAudioFormats = [
    'mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a'
  ];
  
  // 导入单个音乐文件
  static Future<List<String>> importMusicFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedAudioFormats,
        allowMultiple: true,
      );
      
      if (result != null) {
        List<String> filePaths = result.paths
            .where((path) => path != null)
            .map((path) => path!)
            .toList();
        
        return filePaths;
      }
    } catch (e) {
      print('导入音乐文件失败: $e');
    }
    
    return [];
  }
  
  // 导入文件夹
  static Future<List<String>> importMusicFolder() async {
    try {
      String? folderPath = await FilePicker.platform.getDirectoryPath();
      
      if (folderPath != null) {
        List<String> musicFiles = await _scanFolderForMusicFiles(folderPath);
        return musicFiles;
      }
    } catch (e) {
      print('导入音乐文件夹失败: $e');
    }
    
    return [];
  }
  
  // 扫描文件夹中的音乐文件
  static Future<List<String>> _scanFolderForMusicFiles(String folderPath) async {
    List<String> musicFiles = [];
    
    try {
      Directory directory = Directory(folderPath);
      List<FileSystemEntity> entities = await directory.list(recursive: true).toList();
      
      for (var entity in entities) {
        if (entity is File) {
          String extension = path.extension(entity.path).toLowerCase();
          if (extension.isNotEmpty && supportedAudioFormats.contains(extension.substring(1))) {
            musicFiles.add(entity.path);
          }
        }
      }
    } catch (e) {
      print('扫描文件夹失败: $e');
    }
    
    return musicFiles;
  }
} 