import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

class FaqModel {
  const FaqModel({
    required this.id,
    required this.question,
    required this.answer,
    this.category,
  });

  final String id;
  final String question;
  final String answer;
  final String? category;

  factory FaqModel.fromJson(Map<String, dynamic> json) => FaqModel(
        id: json['id'] as String,
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        category: json['category'] as String?,
      );
}

class SupportTicketModel {
  const SupportTicketModel({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) =>
      SupportTicketModel(
        id: json['id'] as String,
        subject: json['subject'] as String? ?? '',
        message: json['message'] as String? ?? '',
        status: json['status'] as String? ?? 'OPEN',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String get readableStatus => switch (status) {
        'OPEN' => 'Open',
        'IN_PROGRESS' => 'In Progress',
        'RESOLVED' => 'Resolved',
        'CLOSED' => 'Closed',
        _ => status,
      };
}

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<List<FaqModel>> faqs() async {
    final data = await _api.get<List<dynamic>>(
      ApiRoutes.faqs,
      skipAuth: true,
    );

    return data.map((e) => FaqModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SupportTicketModel>> myTickets() async {
    final data = await _api.get<List<dynamic>>('${ApiRoutes.tickets}/mine');

    return data
        .map((e) => SupportTicketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createTicket({
    required String subject,
    required String message,
  }) {
    return _api.post(
      ApiRoutes.tickets,
      body: {'subject': subject, 'message': message},
    );
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(apiClientProvider));
});

final faqsProvider = FutureProvider.autoDispose<List<FaqModel>>((ref) {
  return ref.watch(supportRepositoryProvider).faqs();
});

final myTicketsProvider = FutureProvider.autoDispose<List<SupportTicketModel>>((ref) {
  return ref.watch(supportRepositoryProvider).myTickets();
});
