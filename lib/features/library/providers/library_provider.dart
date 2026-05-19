import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BookStatus { available, borrowed, reserved }

class BookData {
  final String id;
  final String title;
  final String author;
  final String category;
  final String isbn;
  final BookStatus status;
  final String? coverUrl;
  final String synopsis;
  final int totalCopies;
  final int availableCopies;

  const BookData({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.isbn,
    required this.status,
    this.coverUrl,
    required this.synopsis,
    required this.totalCopies,
    required this.availableCopies,
  });
}

class BookLoan {
  final String id;
  final String bookId;
  final String bookTitle;
  final DateTime borrowDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final bool isReturned;

  const BookLoan({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.borrowDate,
    required this.dueDate,
    this.returnDate,
    required this.isReturned,
  });

  bool get isOverdue => !isReturned && DateTime.now().isAfter(dueDate);
  int get daysLeft => dueDate.difference(DateTime.now()).inDays;
}

/// TODO: Wire ke Supabase — tabel `library_books` (atau nama sebenarnya).
final libraryBooksProvider = FutureProvider<List<BookData>>((ref) async {
  return const <BookData>[];
});

/// TODO: Wire ke Supabase — tabel `book_loans` (atau nama sebenarnya).
/// Filter by id_siswa = user yang login.
final myLoansProvider = FutureProvider<List<BookLoan>>((ref) async {
  return const <BookLoan>[];
});

final activeLoanCountProvider = Provider<int>((ref) {
  final l = ref.watch(myLoansProvider);
  return l.when(
    data: (x) => x.where((b) => !b.isReturned).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
