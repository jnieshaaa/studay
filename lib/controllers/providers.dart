import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/local_storage_service.dart';
import '../services/exam_service.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final examServiceProvider = ChangeNotifierProvider<ExamService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return ExamService(storage);
});
