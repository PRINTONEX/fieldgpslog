import 'package:get/get.dart';
import '../models/expense_log.dart';
import 'database_service.dart';

class ExpenseService extends GetxService {
  final DatabaseService _db = Get.find<DatabaseService>();

  Future<void> addExpense(ExpenseLog expense) async {
    await _db.expenseBox.add(expense);
  }

  Future<void> deleteExpense(int index) async {
    await _db.expenseBox.deleteAt(index);
  }

  List<ExpenseLog> getExpensesForDate(DateTime date) {
    return _db.expenseBox.values.where((e) {
      return e.date.year == date.year &&
             e.date.month == date.month &&
             e.date.day == date.day;
    }).toList();
  }

  double getTotalExpenseForDate(DateTime date) {
    final expenses = getExpensesForDate(date);
    return expenses.fold(0.0, (sum, e) => sum + e.amount);
  }
  
  List<ExpenseLog> getAllExpenses() => _db.expenseBox.values.toList();
}
