import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/local_storage_service.dart';
import '../services/exam_service.dart';
import '../services/supabase_exam_service.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final supabaseExamServiceProvider = Provider<SupabaseExamService>((ref) {
  return SupabaseExamService();
});

final examServiceProvider = ChangeNotifierProvider<ExamService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final supabase = ref.watch(supabaseExamServiceProvider);
  return ExamService(storage, supabase: supabase);
});

